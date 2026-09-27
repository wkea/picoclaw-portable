#!/usr/bin/env bash
# ============================================================================
#  PicoClaw 便携版 · 一条命令装完就能用
#
#  它做什么
#    1) 自动下载 picoclaw 官方二进制（不需要 root）
#    2) 问你 DeepSeek API Key（输入不回显）
#    3) 让你选一个模型（直接回车 = 默认）
#    4) 全部装进一个目录，生成 ./niko，直接开聊
#
#  一条命令
#    curl -fsSL https://raw.githubusercontent.com/wkea/picoclaw-portable/main/install.sh | bash
#
#  装到哪     默认 $HOME/picoclaw     （INSTALL_DIR=/data/pc 可改）
#  便携       整个目录拷到另一台同架构机器，./niko 直接可用，零依赖
#  免交互     DEEPSEEK_API_KEY=sk-xxx MODEL_CHOICE=1 bash install.sh
#  国内加速   GH_PROXY=https://ghproxy.net/ bash install.sh
#  加进 PATH  LINK=1 bash install.sh   （把 niko / pc 软链到 ~/.local/bin）
# ============================================================================
set -euo pipefail

PICOCLAW_VERSION="${PICOCLAW_VERSION:-0.3.1}"
INSTALL_DIR="${INSTALL_DIR:-$HOME/picoclaw}"
GH_PROXY="${GH_PROXY:-}"
LINK="${LINK:-0}"

# ---- 模型菜单（改这里即可增删选项） ----------------------------------------
PROVIDER="deepseek"
API_BASE="https://api.deepseek.com/v1"
# 显示名 | config 里的 model_name | 发给 API 的 model id
MODEL_1_LABEL="deepseek-flash";  MODEL_1_ALIAS="deepseek-v4-flash"; MODEL_1_ID="deepseek-v4-flash"
MODEL_2_LABEL="deepseek-v4-pro"; MODEL_2_ALIAS="deepseek-v4-pro";   MODEL_2_ID="deepseek-v4-pro"

C_OK=$'\033[32m'; C_WARN=$'\033[33m'; C_ERR=$'\033[31m'; C_DIM=$'\033[2m'; C_0=$'\033[0m'
log()  { printf '%s[+]%s %s\n' "$C_OK" "$C_0" "$*" >&2; }
warn() { printf '%s[!]%s %s\n' "$C_WARN" "$C_0" "$*" >&2; }
die()  { printf '%s[x]%s %s\n' "$C_ERR" "$C_0" "$*" >&2; exit 1; }

# 交互输入走 /dev/tty，这样 curl | bash 也能正常提问
if [ -r /dev/tty ]; then TTY=/dev/tty; else TTY=""; fi
ask() {  # ask <提示> → $REPLY
  if [ -n "$TTY" ]; then IFS= read -r -p "$1" REPLY <"$TTY" || true
  else                    IFS= read -r -p "$1" REPLY || true; fi
}
ask_secret() {  # 不回显
  if [ -n "$TTY" ]; then IFS= read -r -s -p "$1" REPLY <"$TTY" || true; echo >&2
  else                    IFS= read -r -s -p "$1" REPLY || true; echo >&2; fi
}

# ============================================================ 0. 交互收集
printf '\n%s────────────────────────────────────────────────────────────%s\n' "$C_DIM" "$C_0" >&2
printf '  %sPicoClaw 便携版安装%s\n' "$C_OK" "$C_0" >&2
printf '%s────────────────────────────────────────────────────────────%s\n\n' "$C_DIM" "$C_0" >&2

# ---- (1) API Key ------------------------------------------------------------
API_KEY="${DEEPSEEK_API_KEY:-}"
if [ -z "$API_KEY" ]; then
  echo >&2 "  ${C_DIM}在 platform.deepseek.com → API Keys 创建，形如 sk-xxxxxxxx${C_0}"
  while [ -z "$API_KEY" ]; do
    ask_secret "  [1/2] 请输入 DeepSeek API Key: "
    API_KEY="$(printf '%s' "$REPLY" | tr -d '[:space:]')"
    [ -z "$API_KEY" ] && warn "不能为空，请重新输入"
  done
fi
echo >&2

# ---- (2) 模型选择 -----------------------------------------------------------
CHOICE="${MODEL_CHOICE:-}"
if [ -z "$CHOICE" ]; then
  echo >&2 "  [2/2] 请选择模型："
  printf '        %s1)%s %-16s 快速省钱  %s← 默认%s\n' "$C_OK" "$C_0" "$MODEL_1_LABEL" "$C_DIM" "$C_0" >&2
  printf '        %s2)%s %-16s 推理更强\n' "$C_OK" "$C_0" "$MODEL_2_LABEL" >&2
  ask "        输入 1 或 2（直接回车 = 1）: "
  CHOICE="${REPLY:-1}"
fi
case "$CHOICE" in
  2|"$MODEL_2_LABEL"|"$MODEL_2_ALIAS") ALIAS="$MODEL_2_ALIAS"; MODEL_ID="$MODEL_2_ID"; NICE="$MODEL_2_LABEL" ;;
  *)                                   ALIAS="$MODEL_1_ALIAS"; MODEL_ID="$MODEL_1_ID"; NICE="$MODEL_1_LABEL" ;;
esac
log "Key 已接收（${#API_KEY} 字符），模型：$NICE"

# ============================================================ 1. 平台识别
case "$(uname -s)" in
  Linux)  OS=Linux  ;;
  Darwin) OS=Darwin ;;
  *) die "暂不支持的系统: $(uname -s)（Linux / macOS）" ;;
esac
case "$(uname -m)" in
  x86_64|amd64)  ARCH=x86_64  ;;
  aarch64|arm64) ARCH=arm64   ;;
  armv7l|armv7)  ARCH=armv7   ;;
  armv6l|armv6)  ARCH=armv6   ;;
  riscv64)       ARCH=riscv64 ;;
  loongarch64)   ARCH=loong64 ;;
  mips*)         ARCH=mipsle  ;;
  *) die "未知架构: $(uname -m)" ;;
esac
log "平台 ${OS}_${ARCH}   安装目录 ${INSTALL_DIR}"

# ============================================================ 2. 目录
mkdir -p "$INSTALL_DIR/bin" "$INSTALL_DIR/logs"
CFG="$INSTALL_DIR/config.json"
SEC="$INSTALL_DIR/.security.yml"
BIN="$INSTALL_DIR/bin/picoclaw"

# ============================================================ 3. 获取二进制
if [ -x "$BIN" ]; then
  log "二进制已存在，跳过下载（重装只更新配置）"
else
  PKG="picoclaw_${OS}_${ARCH}.tar.gz"
  BASE="https://github.com/sipeed/picoclaw/releases/download/v${PICOCLAW_VERSION}"
  URL="${GH_PROXY}${BASE}/${PKG}"
  TMP="$(mktemp -d)"; trap 'rm -rf "$TMP"' EXIT
  log "下载 $URL"
  curl -fL --retry 3 --connect-timeout 15 -o "$TMP/p.tar.gz" "$URL" \
    || die "下载失败。国内可试：GH_PROXY=https://ghproxy.net/ bash install.sh"
  if curl -fsL --connect-timeout 10 -o "$TMP/sums.txt" "${GH_PROXY}${BASE}/picoclaw_${PICOCLAW_VERSION}_checksums.txt" 2>/dev/null; then
    ( cd "$TMP" && EXPECT="$(awk -v f="$PKG" '$2==f{print $1}' sums.txt)" \
      && [ -n "$EXPECT" ] && echo "$EXPECT  p.tar.gz" | sha256sum -c - >/dev/null ) \
      || die "sha256 校验失败，已中止"
    log "sha256 校验通过"
  else
    warn "未取到 checksums，跳过 sha256 校验"
  fi
  tar xzf "$TMP/p.tar.gz" -C "$TMP"
  SRC="$(find "$TMP" -maxdepth 2 -type f -name picoclaw | head -1)"
  [ -n "$SRC" ] || die "压缩包内未找到 picoclaw"
  install -m 0755 "$SRC" "$BIN"
fi
"$BIN" version 2>/dev/null | head -1 >&2 || true

# ============================================================ 4. 生成 workspace / 默认配置
if [ ! -f "$CFG" ]; then
  log "初始化 workspace 与默认配置"
  PICOCLAW_HOME="$INSTALL_DIR" "$BIN" onboard >/dev/null 2>&1 || true
fi
[ -f "$CFG" ] || die "配置生成失败（$CFG）"
mkdir -p "$INSTALL_DIR/workspace/skills" "$INSTALL_DIR/workspace/memory"

# 4a. 默认 provider / model_name / workspace（只改第一处 = agents.defaults）
#     workspace 留空 → 自动解析为 $PICOCLAW_HOME/workspace，整个目录可搬迁
awk -v prov="$PROVIDER" -v alias="$ALIAS" '
  {
    if (!w && $0 ~ /"workspace"[[:space:]]*:/)   { sub(/"workspace"[[:space:]]*:[[:space:]]*"[^"]*"/,   "\"workspace\": \"\""); w=1 }
    if (!p && $0 ~ /"provider"[[:space:]]*:/)     { sub(/"provider"[[:space:]]*:[[:space:]]*"[^"]*"/,     "\"provider\": \""     prov  "\""); p=1 }
    if (!m && $0 ~ /"model_name"[[:space:]]*:/)   { sub(/"model_name"[[:space:]]*:[[:space:]]*"[^"]*"/,   "\"model_name\": \""   alias "\""); m=1 }
    print
  }' "$CFG" > "$CFG.tmp" && mv "$CFG.tmp" "$CFG"

# 4b. model_list 里若没有该模型，插到数组开头（首元素，天然合法 JSON）
#     注意：必须在 model_list 数组范围内判断，否则会误命中 agents.defaults 里的同名项
if ! awk -v a="\"${ALIAS}\"" '
      /"model_list"[[:space:]]*:[[:space:]]*\[/ { inml=1 }
      inml && $0 ~ /"model_name"/ && index($0,a) { found=1 }
      END { exit(found?0:1) }' "$CFG"; then
  ENTRY="    { \"model_name\": \"${ALIAS}\", \"provider\": \"${PROVIDER}\", \"model\": \"${MODEL_ID}\", \"api_base\": \"${API_BASE}\" },"
  awk -v e="$ENTRY" '{ print; if (!d && /"model_list"[[:space:]]*:[[:space:]]*\[/) { print e; d=1 } }' "$CFG" > "$CFG.tmp" && mv "$CFG.tmp" "$CFG"
  log "model_list 新增模型 $ALIAS"
fi
log "配置就位（默认模型 = $ALIAS）"

# ============================================================ 5. 写密钥
umask 077
KEY_ESC="$(printf '%s' "$API_KEY" | sed 's/\\/\\\\/g; s/"/\\"/g')"
cat > "$SEC.new" <<EOF
# PicoClaw 密钥 —— 由 install.sh 生成（$(date '+%Y-%m-%d %H:%M:%S')）
# 换 Key：改这里即可，无需重启任何服务
model_list:
  ${ALIAS}:
    api_keys:
      - "${KEY_ESC}"
EOF
chmod 600 "$SEC.new" 2>/dev/null || true
mv "$SEC.new" "$SEC"
umask 022
log "密钥已写入 .security.yml（权限 600）"

# ============================================================ 6. 生成便携启动命令
# niko：进入聊天；pc：其它子命令。都自己定位所在目录 → 整个目录可任意搬迁
cat > "$INSTALL_DIR/niko" <<'EOF'
#!/usr/bin/env bash
SELF="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" && pwd)"
export PICOCLAW_HOME="$SELF"
exec "$SELF/bin/picoclaw" agent "$@"
EOF
cat > "$INSTALL_DIR/pc" <<'EOF'
#!/usr/bin/env bash
SELF="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" && pwd)"
export PICOCLAW_HOME="$SELF"
exec "$SELF/bin/picoclaw" "$@"
EOF
chmod 0755 "$INSTALL_DIR/niko" "$INSTALL_DIR/pc" 2>/dev/null || true

# 可选：软链到 ~/.local/bin
if [ "$LINK" = "1" ]; then
  L="$HOME/.local/bin"; mkdir -p "$L"
  ln -sf "$INSTALL_DIR/niko" "$L/niko"
  ln -sf "$INSTALL_DIR/pc"   "$L/pc"
  log "已软链到 $L（确保该目录在 PATH 里）"
fi

# ============================================================ 7. 冒烟测试
echo >&2
if PICOCLAW_HOME="$INSTALL_DIR" timeout 90 "$BIN" agent -m "ping, reply with OK only" >/dev/null 2>&1; then OK=1; else OK=0; fi
echo >&2

# ============================================================ 8. 完成
printf '%s────────────────────────────────────────────────────────────%s\n' "$C_DIM" "$C_0" >&2
if [ "$OK" = "1" ]; then
  printf '  %s安装完成 ✅%s   模型：%s\n' "$C_OK" "$C_0" "$NICE" >&2
else
  printf '  %s安装完成%s（模型没测通，多半是 Key 或网络）\n' "$C_WARN" "$C_0" >&2
  printf '   · 换个 Key：编辑 %s 后重跑\n' "$SEC" >&2
  printf '   · 网络不通：确认能访问 api.deepseek.com\n' >&2
fi
printf '%s────────────────────────────────────────────────────────────%s\n' "$C_DIM" "$C_0" >&2
echo >&2
if [ "$LINK" = "1" ]; then
  NIKO="niko"; PC="pc"
else
  NIKO="$INSTALL_DIR/niko"; PC="$INSTALL_DIR/pc"
fi
printf '  现在输入：  %s%s%s   → 进入聊天\n\n' "$C_OK" "$NIKO" "$C_0" >&2
{
  echo "  常用："
  echo "    $NIKO                # 进入聊天"
  echo "    $NIKO -m '你好'       # 单次提问"
  echo "    $PC status           # 查看配置与模型"
  echo "    $PC model            # 切换模型"
  echo
  echo "  便携：整个目录（${INSTALL_DIR}）拷到另一台同架构机器，运行里面的 niko 即可。"
} >&2
