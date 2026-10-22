# 平台安装脚本

`platforms/` 按操作系统组织安装脚本，跨平台共用的配置放在仓库根目录的 `nvim/`。

## 目录约定

```text
platforms/
├── README.md
├── linux/
│   └── ubuntu/
│       └── 24.04/
│           ├── install.sh
│           ├── versions.env
│           └── offline/
│               ├── download.sh
│               ├── install.sh
│               └── README.md
├── macos/
│   ├── install.sh
│   ├── versions.env
│   ├── README.md
│   └── offline/
│       ├── download.sh
│       ├── install.sh
│       └── README.md
└── windows/
    └── README.md       # 待实现
```

- `linux/<发行版>/<版本>/install.sh`：Linux 按发行版和版本区分。
- `macos/install.sh`：macOS 不按版本区分。
- `windows/`：后续放 `install.ps1`，使用 PowerShell。
- `offline/`：每个平台自己的离线下载和离线安装脚本。
- 所有平台共用根目录的 `nvim/`，不要在平台目录里复制一份配置。

## 当前状态

| 平台 | 版本 | 联网安装 | 离线安装 |
|---|---|---|---|
| Ubuntu | 24.04 | 已实现 | 已实现 |
| macOS | 当前版本 | 已实现 | 已实现 |
| Windows | — | 待实现 | 待实现 |

## 新增平台时要遵守的约定

1. **安装脚本必须可重复执行**：已安装且版本正确的工具跳过；需要覆盖时先备份。
2. **不要用 root 运行整个脚本**：需要提权时在脚本内部调用 `sudo`（Linux）或提示用户（Windows）。
3. **固定版本**：Neovim、fzf 等从官方 release 安装时，把版本写进脚本变量，便于复现。
4. **配置只维护一份**：平台脚本负责把根目录的 `nvim/` 链接或复制到该平台的 `stdpath('config')`。
5. **已有配置先备份**：不能静默覆盖用户的 `~/.config/nvim` 或 `%LOCALAPPDATA%\nvim`。
6. **验证版本和路径**：安装完成后打印 `nvim --version`、`rg --version`、`fd --version`、`fzf --version`，并检查 PATH。
7. **离线脚本成对出现**：`offline/download.sh` 负责下载，`offline/install.sh` 负责无网络安装；离线包不提交到 git。
8. **插件安装统一入口**：Neovim 插件用 `nvim/scripts/install-plugins.sh`；公式 parser 用 `nvim/scripts/build-latex-parser.sh`。平台脚本不要各自复制插件安装逻辑。
9. **文档写清楚**：在平台 README 中写明安装内容、依赖、已知限制和回滚方式。
10. **测试可重复**：Docker/本地测试脚本放在仓库根目录的 `tests/`，见 [`tests/README.md`](../tests/README.md)。

## 共享工具清单

无论哪个平台，最终都应提供：

- Neovim 0.12+
- `rg`（ripgrep）
- `fd`
- `fzf`
- `git`（`lazy.nvim` 引导和插件安装需要）
- `tree-sitter` CLI（编译 latex parser）
- Node.js（仅编译 latex parser 时需要，不是 Neovim 运行时依赖）

平台差异主要体现在安装方式和可执行文件命名：

- Debian/Ubuntu 的 `fd` 包可能只提供 `fdfind`；
- 旧 Debian/Ubuntu 的 `bat` 可能叫 `batcat`；
- Windows 需要确认工具在 PATH 中，且原生 Windows 与 WSL 要分开处理。
