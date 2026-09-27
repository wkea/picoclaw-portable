<div align="center">

# 🦞 PicoClaw 便携版

**一条命令，装完就能聊。**

不用 root，不碰系统目录，不装服务 —— 全部塞进一个文件夹，拷哪跑哪。

[![Platform](https://img.shields.io/badge/platform-Linux%20%7C%20macOS-2f81f7)](#-环境要求)
[![Shell](https://img.shields.io/badge/shell-bash-89e051?logo=gnubash&logoColor=white)](#-快速开始)
[![Arch](https://img.shields.io/badge/arch-x86__64%20%7C%20arm64%20%7C%20armv7%20%7C%20riscv64-8b949e)](#-环境要求)
[![Powered by PicoClaw](https://img.shields.io/badge/powered%20by-PicoClaw%20v0.3.1-e06c8a)](https://github.com/sipeed/picoclaw)
[![No Root](https://img.shields.io/badge/root-not%20required-3fb950)](#-为什么用它)

[快速开始](#-快速开始) · [使用](#-使用) · [便携](#-便携) · [配置项](#-配置项) · [目录结构](#-目录结构) · [常见问题](#-常见问题)

</div>

---

## ✨ 为什么用它

这个仓库只做一件事：把 [PicoClaw](https://github.com/sipeed/picoclaw) 的官方二进制，装配成**开箱即用**的样子。

| | |
|---|---|
| 🚀 **一条命令** | `curl \| bash`，问你 Key、选个模型，就完事 |
| 📦 **自包含** | 全部装进一个目录，没有系统依赖、没有全局污染 |
| 🧳 **真便携** | 整个目录拷到另一台机器，`./niko` 直接跑 |
| 🔓 **不要 root** | 普通用户即可安装和使用 |
| 🧹 **卸载干净** | 删掉那个目录，就当没装过 |
| 🐧 **跨平台** | Linux / macOS，x86_64 / arm64 / armv7 / riscv64 |

---

## 🚀 快速开始

```bash
curl -fsSL https://raw.githubusercontent.com/wkea/picoclaw-portable/main/install.sh | bash
```

安装过程会依次问你三件事：

1. **下载** picoclaw 官方二进制（自动识别系统架构 + sha256 校验）
2. **输入** DeepSeek API Key（输入不回显）
3. **选择** 模型 —— 直接回车用默认即可

装好后长这样：

```console
$ ~/picoclaw/niko
```

> **仓库还是私有的时候**，`raw.githubusercontent.com` 需要带 token：
>
> ```bash
> GH_TOKEN=ghp_xxx bash -c 'curl -fsSL -H "Authorization: token $GH_TOKEN" \
>   https://raw.githubusercontent.com/wkea/picoclaw-portable/main/install.sh | bash'
> ```
>
> 或者直接把仓库转成 **public** —— 现在仓库里没有任何密钥，转公开是安全的。

---

## 💬 使用

```bash
~/picoclaw/niko              # 进入聊天
~/picoclaw/niko -m '你好'     # 单次提问
~/picoclaw/pc status         # 查看配置与模型
~/picoclaw/pc model          # 切换模型
```

`niko` 是聊天入口，`pc` 是其它子命令的入口，两者都自动定位自己所在的目录 —— 所以整个文件夹可以随便搬。

> 💡 想让 `niko` 全局可用，安装时加 `LINK=1`，它会软链到 `~/.local/bin`。

---

## 🧳 便携

整个 `~/picoclaw` 目录是**自包含**的，配置里的路径都是相对的：

```bash
# 打包
tar czf pc.tgz -C ~ picoclaw

# 拷到另一台「同系统同架构」的机器，解压后
./picoclaw/niko
```

搬目录、搬机器都不用改任何配置。

---

## ⚙️ 配置项

安装时可用以下环境变量，全部可选：

| 变量 | 说明 | 默认值 |
|---|---|---|
| `INSTALL_DIR` | 安装目录 | `$HOME/picoclaw` |
| `DEEPSEEK_API_KEY` | 免交互，直接使用该 Key | *（会交互询问）* |
| `MODEL_CHOICE` | 免交互选模型：`1` = flash，`2` = pro | *（会交互询问）* |
| `PICOCLAW_VERSION` | 指定 picoclaw 版本 | `0.3.1` |
| `GH_PROXY` | 国内下载加速前缀 | *（直连）* |
| `LINK` | 把 `niko` / `pc` 软链到 `~/.local/bin` | `0` |

**全自动安装：**

```bash
DEEPSEEK_API_KEY=sk-xxx MODEL_CHOICE=1 bash install.sh
```

**国内加速 + 装到指定位置 + 加进 PATH：**

```bash
GH_PROXY=https://ghproxy.net/ INSTALL_DIR=/data/pc LINK=1 bash install.sh
```

> [!NOTE]
> 若 `$HOME/picoclaw` 已存在且**是个文件**（常见于手动下载过 picoclaw 二进制），
> 安装脚本不会改动它，会自动改装到 `$HOME/picoclaw-portable` 并提示；
> 若你**显式指定**的 `INSTALL_DIR` 是个文件，则会明确报错并告诉你换个路径。

---

## 📁 目录结构

安装完成后：

```
~/picoclaw/
├── bin/picoclaw      # 官方二进制
├── niko              # 聊天入口（自动定位所在目录）
├── pc                # 其它子命令入口
├── config.json       # 主配置（默认模型已设好）
├── .security.yml     # API Key（权限 600）
├── workspace/        # agent 工作区：skills / memory / sessions
└── logs/
```

---

## 📋 环境要求

- **系统**：Linux 或 macOS
- **架构**：`x86_64`、`arm64`、`armv7`、`riscv64` 等常见架构
- **依赖**：`curl` + `bash`（一般是系统自带）
- **网络**：能访问 `github.com`（下二进制）和 `api.deepseek.com`（跑模型）

---

## ❓ 常见问题

<details>
<summary><b>安装脚本安全吗？我能先看看再跑吗？</b></summary>

当然，脚本很短，建议先读一遍：

```bash
curl -fsSL https://raw.githubusercontent.com/wkea/picoclaw-portable/main/install.sh -o install.sh
less install.sh
bash install.sh
```
</details>

<details>
<summary><b>装完提示「模型没测通」怎么办？</b></summary>

多半是 Key 或网络问题：

- **换个 Key**：编辑 `~/picoclaw/.security.yml` 后重跑安装脚本
- **网络不通**：确认这台机器能访问 `api.deepseek.com`
</details>

<details>
<summary><b>怎么换模型 / 加模型？</b></summary>

- 换默认模型：`~/picoclaw/pc model`
- 重跑安装脚本并选另一个模型，会自动把新模型加进 `model_list`
</details>

<details>
<summary><b>怎么卸载？</b></summary>

删掉安装目录即可，别的什么都没动：

```bash
rm -rf ~/picoclaw
```
</details>

---

## 🔒 安全须知

- `.security.yml` 里存的是**明文 API Key**，脚本已把权限设为 `600`。
- **不要**把整个 `~/picoclaw` 目录公开分享或提交到仓库。
- 建议使用**专用 Key**，并在 DeepSeek 后台设置**消费上限**。

---

<div align="center">

**PicoClaw** 由 [sipeed](https://github.com/sipeed/picoclaw) 开发（MIT）。
本仓库只是一个一键安装脚本。

</div>
