#!/usr/bin/env bash
# ============================================================================
#  PicoClaw 便携包 · 构建脚本
#
#  在你自己机器上跑一次，产出分发包。目标服务器上解压后 `bash install.sh`，
#  安装向导会问 API Key、让你选模型，然后自动装好。
#
#  用法:
#    bash build-portable.sh                       # 推荐：不预置 Key，装的时候再输
#    bash build-portable.sh --key sk-xxxx         # 可选：预置 Key（装时回车沿用）
#    BUNDLE_BIN=1 bash build-portable.sh          # 内嵌二进制，完全离线安装
#
#  产物: dist/picoclaw-portable.tar.gz
# ============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SRC_HOME="${PICOCLAW_HOME:-$HOME/.picoclaw}"
OUT="$SCRIPT_DIR/dist"

PROVIDER="deepseek"
API_BASE="https://api.deepseek.com/v1"
MODEL_1_ALIAS="deepseek-v4-flash"; MODEL_1_ID="deepseek-v4-flash"
MODEL_2_ALIAS="deepseek-v4-pro";   MODEL_2_ID="deepseek-v4-pro"
KEY=""

while [ $# -gt 0 ]; do
  case "$1" in
    --key)       KEY="$2"; shift 2 ;;
    --provider)  PROVIDER="$2"; shift 2 ;;
    --api-base)  API_BASE="$2"; shift 2 ;;
    --src-home)  SRC_HOME="$2"; shift 2 ;;
    -h|--help)   sed -n '3,15p' "$0"; exit 0 ;;
    *) echo "未知参数: $1"; exit 1 ;;
  esac
done

echo "[+] 源配置: $SRC_HOME/config.json"
[ -f "$SRC_HOME/config.json" ] || { echo "[x] 找不到源 config.json，请先在此机器上 picoclaw onboard"; exit 1; }

PAY="$SCRIPT_DIR/payload"
mkdir -p "$PAY/workspace"
rm -f "$PAY/security.yml"

# ---- 1. 生成 config.json（workspace 用占位符，两个候选模型都预置好）
python3 - "$SRC_HOME/config.json" "$PAY/config.json" "$PROVIDER" "$API_BASE" "$MODEL_1_ALIAS" "$MODEL_1_ID" "$MODEL_2_ALIAS" "$MODEL_2_ID" <<'PY'
import json, sys
src, dst, provider, api_base, a1, i1, a2, i2 = sys.argv[1:9]
cfg = json.load(open(src))
cfg.setdefault("agents", {}).setdefault("defaults", {})
cfg["agents"]["defaults"]["workspace"] = "__INSTALL_DIR__/workspace"
cfg["agents"]["defaults"]["provider"] = provider
cfg["agents"]["defaults"]["model_name"] = a1        # 默认 flash，安装时可改

ml = cfg.setdefault("model_list", [])
# 两个候选模型都确保存在（放在最前，优先级高）
for alias, mid in ((a2, i2), (a1, i1)):
    if not any(m.get("model_name") == alias for m in ml):
        ml.insert(0, {"model_name": alias, "provider": provider, "model": mid, "api_base": api_base})
        print(f"[+] model_list 预置: {alias}")
# 清掉可能残留在 config 里的敏感字段（正规安装不会有）
for m in ml:
    m.pop("api_key", None); m.pop("api_keys", None)
json.dump(cfg, open(dst, "w"), indent=2, ensure_ascii=False)
print(f"[+] config.json 已生成（默认 {a1}，可选 {a2}）")
PY

# ---- 2. 可选：预置密钥（给了 --key 才写）
if [ -n "$KEY" ]; then
  umask 077
  cat > "$PAY/security.yml" <<EOF
# PicoClaw 预置密钥（安装时直接回车沿用）
model_list:
  ${MODEL_1_ALIAS}:
    api_keys:
      - "${KEY}"
EOF
  chmod 600 "$PAY/security.yml"
  echo "[+] .security.yml 已生成（已预置 Key）"
  echo "    ⚠️  该包内含明文 Key，只能走私密渠道分发！"
else
  echo "[+] 未预置 Key —— 安装时由使用者在向导里输入（更安全，推荐）"
fi

# ---- 3. workspace 身份文件
for f in AGENT.md SOUL.md USER.md; do
  [ -f "$SRC_HOME/workspace/$f" ] && cp "$SRC_HOME/workspace/$f" "$PAY/workspace/$f"
done
echo "[+] workspace 身份文件已带入"

# ---- 4. 技能（可选）
if [ -d "$SRC_HOME/workspace/skills" ] && [ -n "$(ls -A "$SRC_HOME/workspace/skills" 2>/dev/null)" ]; then
  mkdir -p "$PAY/workspace/skills"
  cp -r "$SRC_HOME/workspace/skills/." "$PAY/workspace/skills/"
  echo "[+] 技能已带入: $(ls "$PAY/workspace/skills" | tr '\n' ' ')"
fi

# ---- 5. 打包
NAME="picoclaw-portable"
mkdir -p "$OUT"
rm -f "$OUT/$NAME.tar.gz"
TMPPACK="$(mktemp -d)"; mkdir -p "$TMPPACK/$NAME"
cp -r "$PAY" "$TMPPACK/$NAME/payload"
install -m 0755 "$SCRIPT_DIR/install.sh" "$TMPPACK/$NAME/install.sh"
[ -f "$SCRIPT_DIR/README.md" ] && install -m 0644 "$SCRIPT_DIR/README.md" "$TMPPACK/$NAME/README.md"

# 可选：内嵌当前架构二进制，实现完全离线安装
if [ "${BUNDLE_BIN:-0}" = "1" ]; then
  case "$(uname -m)" in
    x86_64|amd64) BA=x86_64 ;; aarch64|arm64) BA=arm64 ;; *) BA="" ;;
  esac
  if [ -n "$BA" ]; then
    curl -fsL -o "$TMPPACK/p.tar.gz" \
      "https://github.com/sipeed/picoclaw/releases/download/v${PICOCLAW_VERSION:-0.3.1}/picoclaw_Linux_${BA}.tar.gz"
    tar xzf "$TMPPACK/p.tar.gz" -C "$TMPPACK" picoclaw
    install -m 0755 "$TMPPACK/picoclaw" "$TMPPACK/$NAME/picoclaw"
    echo "[+] 已内嵌 linux-${BA} 二进制（离线可用）"
  fi
fi

tar czf "$OUT/$NAME.tar.gz" -C "$TMPPACK" "$NAME"
rm -rf "$TMPPACK"

echo
echo "[✓] 打包完成: $OUT/$NAME.tar.gz   $(du -h "$OUT/$NAME.tar.gz" | cut -f1)"
echo
echo "    分发后在目标服务器执行:"
echo "      tar xzf $NAME.tar.gz && cd $NAME && bash install.sh"
echo "    安装向导会依次询问：API Key → 选模型(默认 deepseek-flash) → 自动安装"
echo "    装完输入  niko  即进入聊天。"
