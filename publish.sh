#!/usr/bin/env bash
# ============================================================================
#  publish.sh —— 构建 + 安全检查 + 推送到私有仓库
#
#  用法:
#    GH_TOKEN=ghp_xxx bash publish.sh "提交说明"
#    bash publish.sh                    # 也可从 ~/.config/picoclaw/gh-token 读
#
#  环境变量:
#    GH_TOKEN       GitHub token（必须带 repo 权限）
#    REPO           远端仓库，默认 github.com/wkea/picoclaw-portable
#    BRANCH         分支，默认 main
#    BUILD=0        跳过 build-portable.sh（只推改动）
#    REPACKAGE=1    不做本地重新生成，仅按现有 payload 打包
#
#  推送前会强制扫描暂存区，检测到明文密钥直接中止 —— 防止手滑把 Key 推上去。
# ============================================================================
set -euo pipefail

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$DIR"

BRANCH="${BRANCH:-main}"
REPO="${REPO:-github.com/wkea/picoclaw-portable}"
MSG="${1:-chore: 更新 $(date '+%Y-%m-%d %H:%M')}"
TOKEN="${GH_TOKEN:-}"
[ -n "$TOKEN" ] || TOKEN="$(cat "${GH_TOKEN_FILE:-$HOME/.config/picoclaw/gh-token}" 2>/dev/null || true)"

C_OK=$'\033[32m'; C_ERR=$'\033[31m'; C_0=$'\033[0m'
ok()  { printf '%s[+]%s %s\n' "$C_OK" "$C_0" "$*"; }
die() { printf '%s[x]%s %s\n' "$C_ERR" "$C_0" "$*" >&2; exit 1; }

git rev-parse --git-dir >/dev/null 2>&1 || die "当前目录不是 git 仓库"

# ------------------------------------------------------ 1. 构建产物
if [ "${BUILD:-1}" = "1" ]; then
  ok "构建发行包…"
  REPACKAGE="${REPACKAGE:-0}" bash build-portable.sh
fi

# ------------------------------------------------------ 2. 安全检查（关键！）
ok "扫描暂存区是否含明文密钥…"
git add -A

if git diff --cached --name-only | grep -qiE '(^|/)(security\.yml|\.ghtok|\.netrc|id_rsa|\.npmrc)$'; then
  die "暂存区含疑似密钥文件，已中止。若确属误报，用 git reset 后手动处理。"
fi

# 常见密钥特征：sk- / ghp_ / gho_ / github_pat_ / xoxb- / AKIA / AIza
if git diff --cached -U0 | grep -E '^\+' \
   | grep -qE '(sk-|ghp_|gho_|ghs_|github_pat_|xoxb-|AKIA|AIza)[A-Za-z0-9_\-]{16,}'; then
  match="$(git diff --cached -U0 | grep -E '^\+' \
           | grep -oE '(sk-|ghp_|gho_|ghs_|github_pat_|xoxb-|AKIA|AIza)[A-Za-z0-9_\-]{16,}' \
           | sed 's/\(.\{6\}\).*\(.\{4\}\)$/\1…\2/' | sort -u | head -5)"
  printf '%s[x]%s 暂存区检测到疑似明文密钥，已中止：\n%s\n' "$C_ERR" "$C_0" "$match" >&2
  die "请把密钥移出待提交文件，或加入 .gitignore。"
fi
ok "未发现明文密钥"

# ------------------------------------------------------ 3. 提交
if git diff --cached --quiet; then
  ok "无变更，跳过提交"
else
  git commit -q -m "$MSG"
  ok "已提交: $(git log --oneline -1)"
fi

# ------------------------------------------------------ 4. 推送
if [ -z "$TOKEN" ]; then
  die "缺少 token。请 GH_TOKEN=ghp_xxx bash publish.sh，或写入 ~/.config/picoclaw/gh-token"
fi

ASKPASS="$(mktemp)"; TOKF="$(mktemp)"
trap 'rm -f "$ASKPASS" "$TOKF"' EXIT
umask 077
printf '%s' "$TOKEN" > "$TOKF"
cat > "$ASKPASS" <<EOF
#!/bin/sh
case "\$1" in
  Username*) printf '%s\n' "git" ;;
  Password*) cat "$TOKF" ;;
  *) printf '\n' ;;
esac
EOF
chmod 700 "$ASKPASS"
umask 022

git remote get-url origin >/dev/null 2>&1 || git remote add origin "https://${REPO}.git"
GIT_ASKPASS="$ASKPASS" GIT_TERMINAL_PROMPT=0 \
  git push origin "$BRANCH" 2>&1 | tail -6

ok "推送完成 → https://${REPO}"
echo
echo "    从零安装（目标服务器上）："
echo "      git clone https://<token>@${REPO}.git /tmp/pcp && bash /tmp/pcp/install.sh"
