#!/usr/bin/env bash
# ============================================================================
#  PicoClaw 一键安装（交互式）
#
#  安装流程：
#    1) 输入 DeepSeek API Key
#    2) 选择模型  1) deepseek-flash（默认）  2) deepseek-v4-pro
#    3) 自动安装（二进制 / 配置 / 密钥 / 服务）
#    4) 装完输入  niko  即进入聊天
#
#  用法:
#    bash install.sh                                            # 交互式（推荐）
#    DEEPSEEK_API_KEY=sk-xxx MODEL_CHOICE=1 bash install.sh     # 全自动免交互
#    INSTALL_DIR=/data/picoclaw bash install.sh                 # 自定义目录
#    GH_PROXY=https://ghproxy.net/ bash install.sh              # 国内下载加速
#    NO_SERVICE=1 bash install.sh                               # 不装 systemd 服务
#
#  离线安装: 把 picoclaw 二进制放到本脚本同目录，脚本会优先使用它
# ============================================================================
set -euo pipefail

PICOCLAW_VERSION="${PICOCLAW_VERSION:-0.3.1}"
INSTALL_DIR="${INSTALL_DIR:-/opt/picoclaw}"
GH_PROXY="${GH_PROXY:-}"
NO_SERVICE="${NO_SERVICE:-0}"
SERVICE_NAME="picoclaw"

# ---- 模型菜单（改这里即可增删选项） ----------------------------------------
PROVIDER="deepseek"
API_BASE="https://api.deepseek.com/v1"
# 显示名 | config 里的 model_name | 真正发给 API 的 model id
MODEL_1_LABEL="deepseek-flash";  MODEL_1_ALIAS="deepseek-v4-flash"; MODEL_1_ID="deepseek-v4-flash"
MODEL_2_LABEL="deepseek-v4-pro"; MODEL_2_ALIAS="deepseek-v4-pro";   MODEL_2_ID="deepseek-v4-pro"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PAYLOAD="$SCRIPT_DIR/payload"

C_OK=$'\033[32m'; C_WARN=$'\033[33m'; C_ERR=$'\033[31m'; C_DIM=$'\033[2m'; C_0=$'\033[0m'
log()  { printf '%s[+]%s %s\n' "$C_OK" "$C_0" "$*"; }
warn() { printf '%s[!]%s %s\n' "$C_WARN" "$C_0" "$*"; }
die()  { printf '%s[x]%s %s\n' "$C_ERR" "$C_0" "$*" >&2; exit 1; }

# 交互输入：优先走 /dev/tty，这样  curl | bash  也能正常提问
if [ -r /dev/tty ]; then TTY=/dev/tty; else TTY=""; fi
p() { printf '%s' "$*" >&2; }
ask() {  # ask <提示>  → 结果放 $REPLY
  if [ -n "$TTY" ]; then IFS= read -r -p "$1" REPLY <"$TTY" || true
  else                    IFS= read -r -p "$1" REPLY || true; fi
}
ask_secret() {  # ask_secret <提示>  → 回显关闭，结果放 $REPLY
  if [ -n "$TTY" ]; then IFS= read -r -s -p "$1" REPLY <"$TTY" || true; echo >&2
  else                    IFS= read -r -s -p "$1" REPLY || true; echo >&2; fi
}

[ "$(id -u)" -eq 0 ] || die "请用 root 运行（sudo bash install.sh）"

# ============================================================ 0. 交互收集
echo >&2
printf '%s════════════════════════════════════════════════════════════%s\n' "$C_DIM" "$C_0" >&2
printf '  %sPicoClaw 安装向导%s\n' "$C_OK" "$C_0" >&2
printf '%s════════════════════════════════════════════════════════════%s\n' "$C_DIM" "$C_0" >&2
echo >&2

PRESET_KEY=""
[ -f "$PAYLOAD/security.yml" ] && PRESET_KEY="yes"

# ---- (1) API Key ------------------------------------------------------------
API_KEY="${DEEPSEEK_API_KEY:-}"
if [ -z "$API_KEY" ]; then
  if [ -n "$PRESET_KEY" ]; then
    echo >&2 "  ${C_DIM}本安装包内已预置了一个 Key。${C_0}"
    ask "  [1/2] DeepSeek API Key（直接回车沿用包内预置）: "
    case "$REPLY" in
      "") API_KEY="__USE_PRESET__" ;;
      *)  API_KEY="$REPLY" ;;
    esac
    echo >&2
  else
    while [ -z "$API_KEY" ]; do
      echo >&2 "  ${C_DIM}提示：在 platform.deepseek.com → API Keys 里创建，形如 sk-xxxxxxxx${C_0}"
      ask_secret "  [1/2] 请输入 DeepSeek API Key: "
      API_KEY="$(printf '%s' "$REPLY" | tr -d '[:space:]')"
      [ -z "$API_KEY" ] && warn "不能为空，请重新输入"
    done
    echo >&2
  fi
fi
[ -n "$API_KEY" ] || die "API Key 不能为空"

# ---- (2) 模型选择 -----------------------------------------------------------
ALIAS=""; MODEL_ID=""
if [ "$API_KEY" = "__USE_PRESET__" ]; then
  : # 沿用预置包时模型由包决定，稍后从 payload 里读
fi

CHOICE="${MODEL_CHOICE:-}"
if [ -z "$CHOICE" ]; then
  echo >&2 "  [2/2] 请选择模型："
  printf '        %s1)%s %-16s 快速省钱  %s← 默认%s\n' "$C_OK" "$C_0" "$MODEL_1_LABEL" "$C_DIM" "$C_0" >&2
  printf '        %s2)%s %-16s 推理更强\n' "$C_OK" "$C_0" "$MODEL_2_LABEL" >&2
  ask "        输入 1 或 2（直接回车 = 1）: "
  CHOICE="${REPLY:-1}"
  echo >&2
fi

case "$CHOICE" in
  1|"$MODEL_1_LABEL"|"$MODEL_1_ALIAS") ALIAS="$MODEL_1_ALIAS"; MODEL_ID="$MODEL_1_ID"; NICE="$MODEL_1_LABEL" ;;
  2|"$MODEL_2_LABEL"|"$MODEL_2_ALIAS") ALIAS="$MODEL_2_ALIAS"; MODEL_ID="$MODEL_2_ID"; NICE="$MODEL_2_LABEL" ;;
  *) warn "无法识别的选项 '$CHOICE'，回退到默认 $MODEL_1_LABEL"; ALIAS="$MODEL_1_ALIAS"; MODEL_ID="$MODEL_1_ID"; NICE="$MODEL_1_LABEL" ;;
esac

if [ "$API_KEY" = "__USE_PRESET__" ]; then
  log "沿用包内预置 Key，模型: $NICE"
else
  log "API Key 已接收（${#API_KEY} 字符），模型: $NICE"
fi

# ============================================================ 1. 识别平台
case "$(uname -s)" in
  Linux)  OS=Linux  ;;
  Darwin) OS=Darwin ;;
  *) die "暂不支持的系统: $(uname -s)" ;;
esac
case "$(uname -m)" in
  x86_64|amd64)   ARCH=x86_64   ;;
  aarch64|arm64)  ARCH=arm64    ;;
  armv7l|armv7)   ARCH=armv7    ;;
  armv6l|armv6)   ARCH=armv6    ;;
  riscv64)        ARCH=riscv64  ;;
  loongarch64)    ARCH=loong64  ;;
  mips*)          ARCH=mipsle   ;;
  *) die "未知架构: $(uname -m)" ;;
esac
log "平台: ${OS}_${ARCH}   安装目录: ${INSTALL_DIR}"

# ============================================================ 2. 目录结构
mkdir -p "$INSTALL_DIR/bin" "$INSTALL_DIR/workspace"

# ============================================================ 3. 获取二进制
TARGET_BIN="$INSTALL_DIR/bin/picoclaw"
if [ -x "$SCRIPT_DIR/picoclaw" ]; then
  log "使用随包二进制（离线模式）"
  install -m 0755 "$SCRIPT_DIR/picoclaw" "$TARGET_BIN"
else
  PKG="picoclaw_${OS}_${ARCH}.tar.gz"
  BASE="https://github.com/sipeed/picoclaw/releases/download/v${PICOCLAW_VERSION}"
  URL="${GH_PROXY}${BASE}/${PKG}"
  TMP="$(mktemp -d)"
  trap 'rm -rf "$TMP"' EXIT
  log "下载: $URL"
  curl -fL --retry 3 --connect-timeout 15 -o "$TMP/p.tar.gz" "$URL" \
    || die "下载失败。国内可试: GH_PROXY=https://ghproxy.net/ bash install.sh"

  if curl -fsL --connect-timeout 10 -o "$TMP/sums.txt" "${GH_PROXY}${BASE}/picoclaw_${PICOCLAW_VERSION}_checksums.txt" 2>/dev/null; then
    ( cd "$TMP" && EXPECT="$(awk -v f="$PKG" '$2==f{print $1}' sums.txt)" \
      && [ -n "$EXPECT" ] \
      && echo "$EXPECT  p.tar.gz" | sha256sum -c - >/dev/null \
      && log "sha256 校验通过" ) || die "sha256 校验失败，已中止"
  else
    warn "跳过 sha256 校验（checksums 未取到）"
  fi

  tar xzf "$TMP/p.tar.gz" -C "$TMP"
  BIN_SRC="$(find "$TMP" -maxdepth 2 -type f -name picoclaw | head -1)"
  [ -n "$BIN_SRC" ] || die "压缩包内未找到 picoclaw 可执行文件"
  install -m 0755 "$BIN_SRC" "$TARGET_BIN"
fi
log "二进制就位: $TARGET_BIN"
"$TARGET_BIN" version 2>/dev/null || true

# ============================================================ 4. 写 config.json
CFG="$INSTALL_DIR/config.json"
if [ -f "$PAYLOAD/config.json" ]; then
  sed "s|__INSTALL_DIR__|${INSTALL_DIR}|g" "$PAYLOAD/config.json" > "$CFG"
else
  warn "payload/config.json 缺失，生成最小配置"
  cat > "$CFG" <<EOF
{
  "version": 3,
  "agents": { "defaults": {
    "workspace": "${INSTALL_DIR}/workspace",
    "provider": "${PROVIDER}",
    "model_name": "${ALIAS}",
    "max_tokens": 32768,
    "max_tool_iterations": 50
  } },
  "model_list": [
    { "model_name": "${MODEL_1_ALIAS}", "provider": "${PROVIDER}", "model": "${MODEL_1_ID}", "api_base": "${API_BASE}" },
    { "model_name": "${MODEL_2_ALIAS}", "provider": "${PROVIDER}", "model": "${MODEL_2_ID}", "api_base": "${API_BASE}" }
  ]
}
EOF
fi

# 4a. 把默认 provider / model_name 改成用户选的（只改第一处 = agents.defaults）
awk -v prov="$PROVIDER" -v alias="$ALIAS" '
  {
    if (!p && $0 ~ /"provider"[[:space:]]*:/)   { sub(/"provider"[[:space:]]*:[[:space:]]*"[^"]*"/,   "\"provider\": \""   prov  "\""); p=1 }
    else if (!m && $0 ~ /"model_name"[[:space:]]*:/) { sub(/"model_name"[[:space:]]*:[[:space:]]*"[^"]*"/, "\"model_name\": \"" alias "\""); m=1 }
    print
  }' "$CFG" > "$CFG.tmp" && mv "$CFG.tmp" "$CFG"

# 4b. 如果 model_list 里没有这个模型，插到数组开头（作为第一个元素，天然合法）
if ! grep -q "\"model_name\"[[:space:]]*:[[:space:]]*\"${ALIAS}\"" "$CFG"; then
  ENTRY="    { \"model_name\": \"${ALIAS}\", \"provider\": \"${PROVIDER}\", \"model\": \"${MODEL_ID}\", \"api_base\": \"${API_BASE}\" },"
  awk -v e="$ENTRY" '{ print; if (!d && /"model_list"[[:space:]]*:[[:space:]]*\[/) { print e; d=1 } }' "$CFG" > "$CFG.tmp" && mv "$CFG.tmp" "$CFG"
  log "model_list 新增模型: $ALIAS"
fi

chmod 600 "$CFG"
log "配置文件就位: $CFG  (默认模型 = $ALIAS)"

# ============================================================ 5. 写 .security.yml
SEC="$INSTALL_DIR/.security.yml"
umask 077
if [ "$API_KEY" = "__USE_PRESET__" ]; then
  install -m 600 "$PAYLOAD/security.yml" "$SEC"
  log "已沿用包内预置 .security.yml"
else
  KEY_ESC="$(printf '%s' "$API_KEY" | sed 's/\\/\\\\/g; s/"/\\"/g')"
  cat > "$SEC" <<EOF
# PicoClaw 密钥 —— 由 install.sh 自动生成（$(date '+%Y-%m-%d %H:%M:%S')）
# 换 Key：改这里，然后  systemctl restart ${SERVICE_NAME}
model_list:
  ${ALIAS}:
    api_keys:
      - "${KEY_ESC}"
EOF
  log "密钥已写入 .security.yml（权限 600）"
fi
chmod 600 "$SEC" 2>/dev/null || true
umask 022

# ============================================================ 6. 播种 workspace
if [ -d "$PAYLOAD/workspace" ]; then
  log "初始化 workspace"
  cp -rn "$PAYLOAD/workspace/." "$INSTALL_DIR/workspace/" 2>/dev/null || true
fi
mkdir -p "$INSTALL_DIR/workspace/skills" "$INSTALL_DIR/workspace/memory" "$INSTALL_DIR/logs"

# ============================================================ 7. 命令 & 环境变量
ln -sf "$TARGET_BIN" /usr/local/bin/picoclaw
cat > /etc/profile.d/picoclaw.sh <<EOF
export PICOCLAW_HOME="${INSTALL_DIR}"
export PATH="\$PATH:${INSTALL_DIR}/bin"
EOF
log "已生成 /etc/profile.d/picoclaw.sh  (PICOCLAW_HOME=${INSTALL_DIR})"

# 7a. niko —— 一键进入聊天
cat > /usr/local/bin/niko <<EOF
#!/usr/bin/env bash
# niko —— 进入 PicoClaw 聊天（由 install.sh 生成）
export PICOCLAW_HOME="${INSTALL_DIR}"
exec "${TARGET_BIN}" agent "\$@"
EOF
chmod 0755 /usr/local/bin/niko
log "已安装命令: niko  (输入 niko 即进入聊天，niko -m '你好' 单次提问)"

# ============================================================ 8. systemd 服务
if [ "$NO_SERVICE" != "1" ] && command -v systemctl >/dev/null 2>&1 && [ -d /run/systemd/system ]; then
  log "安装 systemd 服务: ${SERVICE_NAME}"
  cat > "/etc/systemd/system/${SERVICE_NAME}.service" <<EOF
[Unit]
Description=PicoClaw Gateway (portable)
After=network-online.target
Wants=network-online.target

[Service]
Type=simple
Environment=PICOCLAW_HOME=${INSTALL_DIR}
ExecStart=${TARGET_BIN} gateway
Restart=always
RestartSec=5
WorkingDirectory=${INSTALL_DIR}

[Install]
WantedBy=multi-user.target
EOF
  systemctl daemon-reload
  systemctl enable --now "${SERVICE_NAME}" >/dev/null 2>&1 || warn "服务启动失败，稍后手动检查"
  log "服务状态: $(systemctl is-active ${SERVICE_NAME} 2>/dev/null || echo unknown)"
else
  warn "未检测到 systemd，跳过服务安装（可手动运行: PICOCLAW_HOME=${INSTALL_DIR} picoclaw gateway）"
fi

# ============================================================ 9. 冒烟测试
echo >&2
log "===== 冒烟测试（真实调用一次 ${NICE}）====="
export PICOCLAW_HOME="$INSTALL_DIR"
SMOKE_OK=0
if timeout 90 "$TARGET_BIN" agent -m "ping, reply with OK only" 2>&1 | tail -5; then
  SMOKE_OK=1
fi
echo >&2

if [ "$SMOKE_OK" = "1" ]; then
  log "模型调用成功 ✅"
else
  warn "模型调用未成功。常见原因："
  echo "      · Key 无效或余额不足 → 改 ${SEC} 后 systemctl restart ${SERVICE_NAME}" >&2
  echo "      · 网络不通/deepseek 不可达 → 检查出网" >&2
fi

echo >&2
printf '%s════════════════════════════════════════════════════════════%s\n' "$C_DIM" "$C_0" >&2
printf '  %s安装完成 ✅%s   默认模型: %s\n' "$C_OK" "$C_0" "$NICE" >&2
printf '%s════════════════════════════════════════════════════════════%s\n' "$C_DIM" "$C_0" >&2
echo >&2
printf '  现在输入：  %sniko%s   → 进入聊天\n' "$C_OK" "$C_0" >&2
echo >&2
echo "  其他命令:" >&2
echo "    niko -m '你好'            # 单次提问" >&2
echo "    picoclaw status           # 查看配置与模型" >&2
echo "    picoclaw model            # 切换模型" >&2
echo "    systemctl status ${SERVICE_NAME}   # 后台服务" >&2
echo >&2
