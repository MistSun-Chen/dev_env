# Neovim 配置

这是 `dev_env` 仓库中跨平台共用的 Neovim 配置。目标不是“装很多插件”，而是先提供一套稳定、可迁移的基础编辑体验。

## 当前包含的功能

- 混合行号：当前行显示绝对行号，其他行显示相对行号
- 智能大小写搜索：全小写忽略大小写，含大写字母时区分大小写
- 启动时关闭 intro 信息
- 鼠标在所有模式可用
- normal / insert 模式禁用方向键，提示改用 `hjkl`
- `Q` 保留 Neovim 默认行为（重复上一次录制的寄存器），没有禁用

当前**不包含**插件、LSP、文件树、picker。这些会在后续按需加入，避免一开始把配置堆复杂。

## 安装方式

Neovim 读取配置的位置可以用下面的命令确认：

```vim
:echo stdpath('config')
```

### macOS / Linux（推荐软链接）

把仓库里的 `nvim/` 目录链接到 Neovim 配置目录：

```sh
mkdir -p "${XDG_CONFIG_HOME:-$HOME/.config}"
ln -sfn /path/to/dev_env/nvim "${XDG_CONFIG_HOME:-$HOME/.config}/nvim"
```

这样修改仓库里的 `init.lua` 后，下次启动 Neovim 就会生效。如果已经有旧配置，先备份或移走原目录。

Ubuntu 24.04 可以直接使用安装脚本，脚本会自动处理配置链接：

```sh
bash platforms/linux/ubuntu/24.04/install.sh
```

### Windows（推荐复制或目录联接）

Neovim 在 Windows 上通常读取 `stdpath('config')` 返回的目录（常见为 `~/AppData/Local/nvim`）。可以把本目录复制过去：

```powershell
$dst = "$env:LOCALAPPDATA\nvim"
New-Item -ItemType Directory -Force -Path $dst | Out-Null
Copy-Item -Recurse -Force .\nvim\* $dst
```

如果希望仓库修改自动同步，可以在有权限的情况下使用目录联接（junction）：

```powershell
New-Item -ItemType Junction -Path "$env:LOCALAPPDATA\nvim" -Target "C:\path\to\dev_env\nvim"
```

Windows 安装脚本尚未实现；当前以复制方式为准，后续会在 `platforms/windows/` 中补充。

## 验证

启动 Neovim 后检查：

```vim
:set number? relativenumber? ignorecase? smartcase? mouse? shortmess?
```

- `number`、`relativenumber`、`ignorecase`、`smartcase` 应为开启
- `mouse` 应为 `a`
- `shortmess` 应包含 `I`
- normal / insert 模式按方向键，应出现 `Use h/l/k/j` 提示
- 按 `Q` 不应当被禁用；它保留 Neovim 默认行为

## 修改约定

- 所有解释性注释使用中文。
- 不写死 `/Users/...`、`/home/...`、`C:\...` 等平台路径。
- 平台相关逻辑放到 `platforms/<os>/`，配置本身尽量保持跨平台。
- 修改后提交到 `dev_env`；使用软链接的机器不需要重新安装。
- 如果新增插件，记得把 `nvim-pack-lock.json` 一并提交，保证不同机器版本一致。
