# Neovim 键位速查

> 配置事实源：`dev_env/nvim/`。`<leader>` = 空格（Space）。
> 本文件列本配置新增的映射，以及需要记住的 LSP/插件默认键位；纯 Vim 默认键位见 `:help`。

## which-key 提示

按 `<leader>` 后停顿约 250ms，会弹出当前可用的分组；继续按 `f`、`b`、`e`、`g`、`l`、`s`、`m`、`t` 等前缀查看下一级。键位说明来自各映射的 `desc`，不需要先把整张表背下来。

非 `<leader>` 开头的键位也可以查看：

- 按 `g`、`]`、`[` 后停顿，which-key 会显示这些前缀下的按键；
- 按 `<leader>?` 显示当前 buffer 的全部键位，包括 LSP 的 `gd`、`grr`、`K` 和 gitsigns 的 `]c`、`<leader>gs` 等；
- `:WhichKey` 命令可以手动打开键位列表，`:WhichKey g` 查看 `g` 前缀。

## 自定义映射

命名规则：`f` = find、`b` = buffer、`e` = explorer、`g` = git、`l` = lsp、`s` = search/replace、`m` = markdown、`t` = terminal/theme；第二个字母表示对象或动作。

| 分类 | 模式 | 键位 | 缩写详写 | 功能 |
|---|---|---|---|---|
| 文件 | n | `<leader>ff` | find file | 查找文件 |
| 文件 | n | `<leader>fr` | find recent | 最近文件 |
| 文本搜索 | n | `<leader>fg` | find grep | 全局搜索；可输入 `query -- glob` 限定文件 |
| 文本搜索 | n | `<leader>fc` | find current | 当前 buffer 搜索 |
| 文本搜索 | n | `<leader>fw` | find word | 搜索光标下单词 |
| 文本搜索 | v | `<leader>fv` | find visual | 搜索选中文本 |
| 文本搜索 | n | `<leader>fs` | find scope | 按路径 + glob 搜索，`!` 开头排除 |
| 文件树 | n | `<leader>et` | explorer toggle | 打开/关闭文件树（定位当前文件） |
| 终端 | n | `<leader>tt` | terminal toggle | 打开/隐藏底部终端 |
| Git | n | `]c` / `[c` | next/prev hunk | 下一个 / 上一个 Git hunk |
| Git | n / v | `<leader>gs` | git stage | 暂存当前 hunk 或选中范围 |
| Git | n / v | `<leader>gr` | git reset | 丢弃当前 hunk 或选中范围 |
| Git | n | `<leader>gp` | git preview | 预览当前 hunk |
| Git | n | `<leader>gb` | git blame | 查看当前行 blame |
| Git | n | `<leader>gd` | git diff | 对比当前文件与索引 |
| Git | n | `<leader>gq` | git quickfix | 当前文件 hunk 放入 quickfix |
| buffer | n | `<leader>bs` | buffer switch | 按 buffer 名称/路径过滤并切换（不搜内容） |
| buffer | n | `<leader>bn` | buffer next | 下一个 buffer |
| buffer | n | `<leader>bp` | buffer previous | 上一个 buffer |
| buffer | n | `<leader>bd` | buffer delete | 关闭当前 buffer |
| LSP | n | `gd` | goto definition | 跳转到定义（LSP 附加后生效） |
| LSP | n | `K` | hover | 显示悬停文档（LSP 附加后生效） |
| LSP | n | `<leader>ld` | lsp diagnostics | 当前文件诊断列表 |
| LSP | n | `<leader>ls` | lsp symbols | 当前文件符号列表 |
| 搜索替换 | n / v | `<leader>sr` | search replace | 搜索并替换；visual 模式限制在选区内 |
| 搜索替换 | n | `<leader>sR` | search replace file | 当前文件搜索并替换 |
| Markdown | n | `<leader>mp` | markdown preview | Markdown 预览开关 |
| Markdown | n | `<leader>ms` | markdown split | Markdown 分屏预览 |
| Markdown | n | `<leader>mt` | markdown toc | Markdown 目录 |
| 界面 | n | `<leader>tc` | theme change | 切换 Catppuccin 配色 |
| 界面 | n | `<leader>?` | which-key buffer | 查看当前 buffer 的全部键位 |
| 编辑习惯 | n / i | `←` `↓` `↑` `→` | 无 | 禁用方向键，提示改用 hjkl |

## 终端

`<leader>tt` 打开/隐藏底部 12 行终端；第一次打开会进入插入模式。

| 场景 | 操作 |
|---|---|
| 从普通文件打开终端 | `<leader>tt` |
| 终端插入模式回到 normal | `<C-\><C-n>` |
| 终端 normal 模式隐藏 | `<leader>tt` 或 `q` |
| 隐藏后重新打开 | `<leader>tt`，复用同一个 shell 进程 |
| 终端已显示但不当前 | `<leader>tt` 切到终端 |

隐藏不是结束进程；需要结束 shell 时在终端里输入 `exit`。终端 buffer 不进入 tabline。

## Git hunk（gitsigns）

`gitsigns.nvim` 在 Git 仓库的 buffer 中提供行内标记和 hunk 操作；`g` = git。

| 键位 | 作用 |
|---|---|
| `]c` / `[c` | 下一个 / 上一个 hunk |
| `<leader>gs` | 暂存当前 hunk；visual 模式暂存选中行 |
| `<leader>gr` | 丢弃当前 hunk；visual 模式丢弃选中行 |
| `<leader>gS` / `<leader>gR` | 暂存 / 丢弃整个 buffer |
| `<leader>gp` / `<leader>gP` | 弹窗 / 行内预览当前 hunk |
| `<leader>gb` / `<leader>gB` | 当前行 blame / 整个文件 blame |
| `<leader>gd` / `<leader>gD` | 与索引 / 与 HEAD 对比 |
| `<leader>gt` / `<leader>gw` | 开关当前行 blame / word diff |
| `<leader>gq` / `<leader>gQ` | 当前 buffer / 已打开 buffer 的 hunk 放入 quickfix |

`<leader>gr` 和 `<leader>gR` 会丢弃工作区改动，执行前先看清范围；暂存后的改动仍可从索引恢复。`ih` 是 gitsigns 提供的 hunk 文本对象，可以在 operator 后使用，例如 `dih`。

## LSP 默认键位

这些是 Neovim 0.12 自带的 LSP 映射，不是本配置新增的；Lua、Python、Bash、C/C++ 共用同一套键位，列在这里是为了查起来方便。

助记规则：

- `g` = go（跳转/前往）
- `r` = Neovim 为 LSP 默认映射保留的固定前缀
- 第三个字母 = 动作的首字母

所以 `grr` = `g` + `r` + **r**eferences；`grn` 的 `n` 是 rename，`gri` 的 `i` 是 implementation，`gra` 的 `a` 是 action。

| 键位 | 模式 | 助记 | 功能 |
|---|---|---|---|
| `gra` | n / v | **a**ction | code action；Visual 模式作用于选区 |
| `gri` | n | **i**mplementation | 查看实现 |
| `grn` | n | **n**ame / rename | 重命名 |
| `grr` | n | **r**eferences | 查看引用 |
| `grt` | n | **t**ype | 查看类型定义 |
| `grx` | n | e**x**ecute | 执行 code lens（server 支持时） |
| `gO` | n | **O**utline | 当前文件符号（quickfix） |
| `i_CTRL-S` | i | **S**ignature | 插入模式签名帮助 |
| `K` | n | 无 | 悬停文档 |
| `[d` / `]d` | n | 无 | 上一个 / 下一个诊断 |
| `<C-x><C-o>` | i | 无 | 手动触发 LSP 补全 |
| `<C-n>` / `<C-p>` | i | 无 | 下一个 / 上一个补全候选 |
| `<C-y>` | i | 无 | 接受补全候选 |

说明：

- `grn` 只对 server 判断为可重命名的符号生效；局部变量只改当前作用域，模块字段/导出函数可能跨文件修改引用，建议先用 `grr` 看范围。
- `gra` 只在当前位置确实有 code action 时才有内容；不同 server 提供的 action 数量不同，提示 `No code actions available` 属于正常现象。
- `gO` 和 `<leader>ls` 都能看当前文件符号；`gO` 用 quickfix，`<leader>ls` 用 fzf-lua。
- LuaLS 首次索引项目时，`K` 可能暂时没有结果，稍等几秒再试。

### grr 打开的引用列表

`grr` 默认打开的是 **quickfix** 窗口，不是普通可编辑 buffer。可以用：

```vim
:set buftype? filetype?
" buftype=quickfix
" filetype=qf
```

| 操作 | 作用 |
|---|---|
| `j` / `k` | 在引用列表中移动，不打开文件 |
| `<Enter>` | 跳到当前引用所在位置 |
| `CTRL-W <Enter>` | 在新窗口打开当前引用 |
| `]q` / `[q` | 下一条 / 上一条引用 |
| `]Q` / `[Q` | 最后一条 / 第一条 |
| `:cc` | 跳到当前条目 |
| `:cclose` | 关闭 quickfix 窗口 |
| `:copen` | 重新打开 quickfix 窗口 |
| `:cwindow` | 有结果时打开，没有结果时关闭 |
| `:colder` / `:cnewer` | 切换 quickfix 历史列表 |
| `:cdo {cmd}` | 对每个条目执行 Ex 命令，高级用法，慎用 |

注意：

- quickfix buffer 是只读的；直接编辑它不会修改源码，按 `<Enter>` 跳到真实文件后再改。
- 这里按 `q` 不是关闭窗口（`q` 在普通模式开始录制宏）；用 `:cclose` 或 `:q` 关闭。
- 想用 fzf 过滤引用，可以用 `:FzfLua lsp_references`。

### LSP 补全

- 自动触发：配置中启用了 `autotrigger = true`，由 server 的 `triggerCharacters` 决定（常见是 `.`、`(`、`:` 等）。
- 主动触发：插入模式按 `<C-x><C-o>`，调用 LSP 的 omnifunc。
- 选择：`<C-n>` / `<C-p>`；接受：`<C-y>`；取消补全菜单：`<C-e>`。
- 当前 `completeopt` 是 `menuone,noselect,popup`，所以不会自动选中第一项。

补全排序来自 server 返回的 `sortText` / `label`；Neovim 原生 `vim.lsp.completion` **不会记录你选择过哪些候选并按频率学习排序**。server 自己可能按上下文调整顺序，但不是 Neovim 的历史频率。想要更强排序可以改用 nvim-cmp/blink.cmp 等插件，或自己实现 `cmp` 比较器。

### LSP 诊断与自动修复

当前**没有**“保存时自动修复全部错误”或全局自动修复机制。修复依赖 server 提供的 code action：

```vim
" 光标在诊断上，查看可用修复
gra

" Visual 模式选中范围后
gra
```

如果 server 支持 `source.fixAll`，可以手动请求修复全部：

```vim
:lua vim.lsp.buf.code_action({ context = { only = { 'source.fixAll' } } })
```

server 支持且只返回一个 action 时，可以直接应用：

```vim
:lua vim.lsp.buf.code_action({ apply = true, context = { only = { 'source.fixAll' } } })
```

但这不是所有 server 都支持；语法错误、缺少依赖、未定义符号通常没有可靠的自动修复。Python 还可以单独整理 import：

```vim
:LspPyrightOrganizeImports
```

### 常用 LSP 命令

| 命令 | 作用 |
|---|---|
| `:LspPyrightOrganizeImports` | 整理 Python import |
| `:LspPyrightSetPythonPath /path/to/venv/bin/python` | 指定 Python 虚拟环境 |
| `:LspClangdSwitchSourceHeader` | C/C++ 源文件/头文件切换 |
| `:LspClangdShowSymbolInfo` | 查看 C/C++ 符号信息 |
| `:FzfLua lsp_workspace_symbols` | 全项目符号搜索 |
| `:FzfLua lsp_references` | 用 fzf 查看引用，替代 quickfix |
| `:lua vim.lsp.buf.format({ async = true })` | 用 LSP formatter 格式化 |
| `:checkhealth vim.lsp` | 查看 LSP 环境和当前 attach 状态 |
| `:lsp restart` | 重启 LSP server |
| `:lsp stop` / `:lsp enable` | 停止 / 启用 LSP server |
| `:lua vim.lsp.buf.incoming_calls()` | 查看谁调用当前符号（server 支持时） |
| `:lua vim.lsp.buf.outgoing_calls()` | 查看当前符号调用了谁（server 支持时） |

`gq` 也会使用 LSP 的 `formatexpr` 格式化，但只有 server 支持 formatting 时有效（例如 clangd；Pyright 不提供 formatter）。

## grug-far 内部键位

`<leader>sr` 打开的是 grug-far 的普通 buffer；它使用 `<localleader>`，这里也是空格，所以界面里会显示成 `<SPC>`。

| 键位 | 作用 |
|---|---|
| `<Tab>` / `<Shift-Tab>` | 在 Search → Replace → Files Filter → Flags → Paths 之间切换 |
| `<Space>r` | Replace：按 Search/Replace 规则执行替换 |
| `<Space>q` | 把搜索结果发送到 quickfix |
| `<Space>s` / `<Space>l` | Sync All / Sync Line：只在你手动修改结果列表后，把修改写回文件 |
| `j` / `k` | 在结果列表中移动，不打开文件 |
| `<Up>` / `<Down>` | 跳到上/下一个匹配对应的源文件位置（会打开预览窗口） |
| `<Space>o` | 打开当前结果对应的源文件位置 |
| `<Space>i` | 预览当前结果所在位置，再按一次关闭 |
| `<Space>c` | 关闭 grug-far buffer |
| `<Enter>` | 跳到当前结果对应的文件位置；之后 `<C-o>` 回到原位置 |
| `g?` | 打开 grug-far 帮助 |

`<Esc>` 只退出插入模式，不会关闭 grug-far。关闭后原窗口和光标位置保留。

## neo-tree 内部键位

文件树窗口内按 `?` 查看全部键位，`q` 关闭。常用：

| 键位 | 作用 |
|---|---|
| `?` | 显示帮助 |
| `q` | 关闭文件树窗口 |
| `/` | 递归模糊过滤；`<C-j>` / `<C-k>` 或 `<C-n>` / `<C-p>` 移动，`<Enter>` 打开 |
| `f` | 输入完成后按 Enter 再过滤 |
| `<Enter>` | 打开文件/展开目录 |
| `a` / `d` / `r` | 新建 / 删除 / 重命名 |
| `y` / `x` / `p` | 复制 / 剪切 / 粘贴 |
| `H` | 显示/隐藏隐藏文件 |
| `e` | 开关自动加宽 |

## fzf 内部键位

| 键位 | 作用 |
|---|---|
| `<C-j>` / `<C-k>` | 下一个 / 上一个 |
| `<Up>` / `<Down>` | 下一个 / 上一个（终端支持时） |
| `<Enter>` | 打开 |
| `<Esc>` | 取消 |

## 编辑习惯

- normal / insert 模式的 `←` `↓` `↑` `→` 被禁用，提示改用 `h` `j` `k` `l`。
- `Q` 保留 Neovim 默认行为，没有禁用。
