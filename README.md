# dev_env

个人开发环境仓库：按平台安装 Neovim、ripgrep、fd、fzf、git、tree-sitter，并部署统一的 Neovim 配置与插件。

当前支持 Ubuntu 24.04 和 macOS（Apple Silicon / Intel），均提供联网安装与离线安装；Windows 待实现。

## 支持平台

| 平台 | 联网安装 | 离线安装 |
|---|---|---|
| Ubuntu 24.04 | 支持 | 支持 |
| macOS | 支持 | 支持 |
| Windows | 待实现 | 待实现 |

## 文档

- [使用与安装](./docs/USAGE.md)：联网/离线安装、验证、PATH、版本修改、回滚、常见问题
- [测试与验证](./docs/TESTING.md)：Ubuntu Docker 测试、macOS 本机测试、实测记录
- [LSP 练习样例](./samples/lsp/README.md)：C/C++/Bash/Python 的跳转、诊断、补全练习
- [文档索引](./docs/README.md)

### 平台与配置

- [Neovim 配置](./nvim/README.md)
- [平台脚本约定](./platforms/README.md)
- [Ubuntu 24.04](./platforms/linux/ubuntu/24.04/install.sh)
- [Ubuntu 24.04 离线包](./platforms/linux/ubuntu/24.04/offline/README.md)
- [macOS](./platforms/macos/README.md)
- [macOS 离线包](./platforms/macos/offline/README.md)
- [Windows（待实现）](./platforms/windows/README.md)

## 仓库结构

```text
dev_env/
├── README.md
├── docs/              # 使用、测试、文档索引
├── nvim/              # 跨平台共用的 Neovim 配置
├── platforms/         # 各平台联网/离线安装脚本
├── samples/           # LSP 练习样例（C/C++/Bash/Python）
└── tests/             # Docker/本地测试脚本
```

## 设计原则

- 平台安装逻辑放在 `platforms/<os>/`，共用配置只保留在 `nvim/`。
- 版本和 SHA256 固定在 `versions.env`，便于复现。
- 已有 `~/.config/nvim` 先备份，再链接或复制。
- 离线包不提交到 git，只保留生成和安装脚本。
- 所有测试方法见 [`docs/TESTING.md`](./docs/TESTING.md)。
