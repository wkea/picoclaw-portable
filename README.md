# PicoClaw 便携版 · 一键部署

目标服务器上解压 + 跑一条 `install.sh`，**交互式**问你要 API Key、让你选模型，然后全自动装完。
装完输入 `niko` 直接开始聊天。

---

## 一、安装流程（使用者视角）

```bash
tar xzf picoclaw-portable.tar.gz && cd picoclaw-portable && bash install.sh
```

然后会看到：

```
════════════════════════════════════════════════════════
  PicoClaw 安装向导
════════════════════════════════════════════════════════

  提示：在 platform.deepseek.com → API Keys 里创建，形如 sk-xxxxxxxx
  [1/2] 请输入 DeepSeek API Key: ********            ← 输入不回显

  [2/2] 请选择模型：
        1) deepseek-flash   快速省钱  ← 默认
        2) deepseek-v4-pro  推理更强
        输入 1 或 2（直接回车 = 1）: 2

[+] API Key 已接收（35 字符），模型: deepseek-v4-pro
[+] 平台: Linux_x86_64   安装目录: /opt/picoclaw
[+] 下载/校验二进制…
[+] 配置文件就位: /opt/picoclaw/config.json  (默认模型 = deepseek-v4-pro)
[+] 密钥已写入 .security.yml（权限 600）
[+] 已安装命令: niko
…

════════════════════════════════════════════════════════
  安装完成 ✅   默认模型: deepseek-v4-pro
════════════════════════════════════════════════════════

  现在输入：  niko   → 进入聊天
```

## 二、装完之后

```bash
niko                    # ← 进入聊天（交互式）
niko -m "你好"          # 单次提问
niko --help             # 透传给 picoclaw agent 的所有参数（-d/-s/--model …）

picoclaw status         # 查看配置与模型 / Key 是否生效
picoclaw model          # 切换模型
picoclaw gateway        # 启动网关（接 Telegram/企微 等渠道）
systemctl status picoclaw
```

`niko` 就是一层包装：`PICOCLAW_HOME=/opt/picoclaw picoclaw agent "$@"`，参数原样透传。

## 三、制作安装包（在你自己的机器上做一次）

```bash
cd picoclaw-portable
bash build-portable.sh                 # 推荐：包里不含 Key，装的时候再输
```

产物：`dist/picoclaw-portable.tar.gz`（约 40KB，不含二进制）

可选参数：

```bash
bash build-portable.sh --key sk-xxx    # 预置 Key（安装时直接回车沿用）
BUNDLE_BIN=1 bash build-portable.sh    # 内嵌二进制，完全离线安装（~23MB）
```

`BUNDLE_BIN=1` 内嵌的是**构建机同架构**的二进制（x86_64 / arm64 自动判断）；
其他架构让安装脚本在线下载（会自动识别）。

## 四、安装脚本可选参数

```bash
INSTALL_DIR=/data/picoclaw bash install.sh               # 自定义安装目录（默认 /opt/picoclaw）
GH_PROXY=https://ghproxy.net/ bash install.sh            # 国内加速下载
NO_SERVICE=1 bash install.sh                             # 不装 systemd 服务
DEEPSEEK_API_KEY=sk-xxx MODEL_CHOICE=1 bash install.sh   # 全自动免交互（做批量部署用）
```

`MODEL_CHOICE`：`1` = deepseek-flash（默认），`2` = deepseek-v4-pro。

安装脚本还会：

- 自动识别 CPU 架构（x86_64 / arm64 / armv7 / armv6 / riscv64 / loong64 / mipsle）
- 下载官方二进制并校验 sha256（或使用包内离线二进制）
- 生成 `config.json` + `.security.yml`（权限 600）
- 初始化 `workspace/`（AGENT.md / SOUL.md / USER.md + 技能）
- 注册 systemd 服务 `picoclaw` 并开机自启
- **冒烟测试**：真实调用一次模型，验证 Key 是否有效

## 五、换 Key / 换模型

```bash
vi /opt/picoclaw/.security.yml    # 改 api_keys
systemctl restart picoclaw
```

或换模型：`picoclaw model`（`model_list` 里两个 DeepSeek 模型都已预置好，随时可切）。

---

## ⚠️ 安全须知

**默认包里不含明文 Key**（推荐用法），Key 由使用者在安装时输入，风险最低。

如果用了 `--key` 预置，则：**谁拿到这个包，谁就能花你的钱**。务必：

1. 只发自己可控的服务器，别发给第三方；
2. 别提交到公开仓库 / 公开网盘（GitHub 上有机器人专门扫泄漏 Key）；
3. 用**单独的 Key + 消费上限**，出事能一键吊销；
4. 传输走 `scp` 或私有存储，别走明文 HTTP 公开链接；
5. `.security.yml` 权限已设 `600`，别放宽。

多机分发的更安全做法：把安装脚本改成从**私有接口带一次性令牌临时拉取 Key**，
包里彻底不含明文（可随时吊销 / 限 IP / 留审计）。需要的话我可以加。

---

## 目录结构

```
picoclaw-portable/
├── build-portable.sh      # 打包脚本（构建机跑）
├── install.sh             # 安装脚本（目标服务器跑）
├── README.md
├── payload/               # 被打包进去的预置数据
│   ├── config.json        # 预置配置（workspace 用 __INSTALL_DIR__ 占位）
│   ├── security.yml       # 可选：预置 Key（用 --key 时才有）
│   └── workspace/         # 人格文件 + 技能
└── dist/                  # 产物
    └── picoclaw-portable.tar.gz
```
