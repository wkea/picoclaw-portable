# PicoClaw 便携版

**一条命令装完就能用** —— 自动下载官方二进制，问你 API Key、选个模型，然后就能聊。

## 一键安装

```bash
curl -fsSL https://raw.githubusercontent.com/wkea/picoclaw-portable/main/install.sh | bash
```

装的时候会：

1. 自动下载 picoclaw 官方二进制（不用 root）
2. 让你输入 DeepSeek API Key（输入不回显）
3. 让你选模型（直接回车 = 默认 deepseek-flash）
4. 全部装进一个目录，并生成 `niko` 启动命令

> 仓库是私有的时，`raw.githubusercontent.com` 需要带 token：
> ```bash
> GH_TOKEN=ghp_xxx bash -c 'curl -fsSL -H "Authorization: token $GH_TOKEN" \
>   https://raw.githubusercontent.com/wkea/picoclaw-portable/main/install.sh | bash'
> ```
> 或者直接把仓库转成 public，就没这回事了。

## 装完怎么用

```bash
~/picoclaw/niko              # 进入聊天
~/picoclaw/niko -m '你好'     # 单次提问
~/picoclaw/pc status         # 查看配置与模型
~/picoclaw/pc model          # 切换模型
```

## 便携

整个 `~/picoclaw` 目录是自包含的：拷到另一台**同系统同架构**的机器上，直接运行里面的 `niko` 就能用。配置里的路径都是相对的，换目录、换机器都不用改。

```bash
tar czf pc.tgz -C ~ picoclaw     # 打包
# 拷到新机器解压后
./picoclaw/niko
```

## 可选参数

| 变量 | 作用 | 例子 |
|---|---|---|
| `INSTALL_DIR` | 安装目录（默认 `$HOME/picoclaw`） | `INSTALL_DIR=/data/pc` |
| `DEEPSEEK_API_KEY` | 免交互，直接用这个 Key | `DEEPSEEK_API_KEY=sk-xxx` |
| `MODEL_CHOICE` | 免交互，直接选模型 `1`/`2` | `MODEL_CHOICE=2` |
| `GH_PROXY` | 国内下载加速前缀 | `GH_PROXY=https://ghproxy.net/` |
| `LINK` | 把 `niko`/`pc` 软链到 `~/.local/bin` | `LINK=1` |

全自动示例：

```bash
DEEPSEEK_API_KEY=sk-xxx MODEL_CHOICE=1 bash install.sh
```

## 目录结构（装完后）

```
~/picoclaw/
├── bin/picoclaw      # 官方二进制
├── niko              # 进入聊天的启动脚本（自己定位所在目录）
├── pc                # 其它子命令的启动脚本
├── config.json       # 主配置（默认模型已设好）
├── .security.yml     # API Key（权限 600）
├── workspace/        # agent 的工作区（skills / memory / sessions）
└── logs/
```

## 要求

- Linux 或 macOS，x86_64 / arm64 / armv7 / riscv64 等常见架构
- `curl` 和 `bash`
- 能访问 `github.com`（下二进制）和 `api.deepseek.com`（跑模型）

## 安全

- `.security.yml` 里是**明文 API Key**，权限已设为 `600`。
- 别把整个 `~/picoclaw` 目录公开分享或提交到仓库。
- 建议用专用 Key，并在 DeepSeek 后台设置消费上限。
