# Windows 平台（待实现）

当前尚未提供自动化安装脚本。下面是计划中的方案，方便后续补 `install.ps1`。

## 原生 Windows 与 WSL

先明确目标环境：

- **原生 Windows**：Neovim、`rg`、`fd`、`fzf` 都是 Windows 二进制；配置文件路径由 `stdpath('config')` 决定，常见为 `%LOCALAPPDATA%\nvim`。
- **WSL**：按 Linux 处理，使用 Linux 二进制和 `~/.config/nvim`；不要混用 Windows 侧的路径或可执行文件。

下面的方案针对**原生 Windows**。WSL 可以复用 Ubuntu 安装脚本。

## 计划安装内容

### 方式一：winget

```powershell
winget install Neovim.Neovim
winget install BurntSushi.ripgrep.MSVC
winget install sharkdp.fd
winget install junegunn.fzf
winget install Git.Git
```

### 方式二：scoop

```powershell
scoop install neovim ripgrep fd fzf git
```

安装后重新打开终端，确认：

```powershell
nvim --version
rg --version
fd --version
fzf --version
git --version
```

## 配置部署

Neovim 配置目录：

```powershell
nvim --headless "+lua print(vim.fn.stdpath('config'))" +qa
```

推荐复制：

```powershell
$dst = "$env:LOCALAPPDATA\nvim"
New-Item -ItemType Directory -Force -Path $dst | Out-Null
Copy-Item -Recurse -Force C:\path\to\dev_env\nvim\* $dst
```

如果希望仓库修改自动同步，可以在有权限时使用目录联接：

```powershell
New-Item -ItemType Junction -Path "$env:LOCALAPPDATA\nvim" -Target "C:\path\to\dev_env\nvim"
```

普通符号链接（symlink）通常需要开发者模式或管理员权限；目录联接（junction）对目录更友好。

## 已知注意点

- `vim.pack` 需要 `git` 在 PATH 中。
- `fzf-lua` 在 Windows 上有单独的兼容性说明（引号、转义等）；如果不想处理这些差异，可以优先考虑 `mini.pick`、`telescope.nvim` 或 `snacks.picker`。
- 路径中可能有空格、中文、盘符；测试时至少覆盖一个带空格的目录。
- Windows 的换行符可能是 CRLF；当前 Neovim 配置没有强制 `fileformat`，不要随意加 `set fileformat=unix`。
- 剪贴板、终端 shell（PowerShell/cmd）与 Linux/macOS 不同，后续配置要按平台探测。

## 待办

- [ ] 写 `platforms/windows/install.ps1`
- [ ] 检测 winget/scoop 是否可用
- [ ] 固定或校验 Neovim 版本
- [ ] 复制或 junction 部署 Neovim 配置
- [ ] 备份已有 `%LOCALAPPDATA%\nvim`
- [ ] 验证 `nvim`、`rg`、`fd`、`fzf`、`git`
- [ ] 更新根 README 的状态表
