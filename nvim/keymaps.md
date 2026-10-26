# Neovim 键位速查

> 配置事实源：`dev_env/nvim/`。`<leader>` = 空格（Space）。
> 本文件列本配置新增的映射，以及需要记住的 LSP/插件默认键位；纯 Vim 默认键位见 `:help`。

## 自定义映射

命名规则：`f` = find、`b` = buffer、`e` = explorer、`l` = lsp、`s` = search/replace、`m` = markdown、`t` = theme；第二个字母表示对象或动作。

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
| 编辑习惯 | n / i | `←` `↓` `↑` `→` | 无 | 禁用方向键，提示改用 hjkl |

## LSP 默认键位

这些是 Neovim 0.12 自带的 LSP 映射，不是本配置新增的；列在这里是为了查起来方便。

| 键位 | 功能 |
|---|---|
| `grn` | 重命名（rename） |
| `grr` | 查看引用（references） |
| `gri` | 查看实现（implementation） |
| `gra` | code action |
| `[d` / `]d` | 上一个 / 下一个诊断 |
| `<C-n>` / `<C-p>` | 原生补全中下一个 / 上一个候选 |
| `<C-y>` | 接受原生补全候选 |
| `<C-x><C-o>` | 手动触发 LSP 补全 |

说明：

- `grn` 只对 LuaLS 判断为可重命名的符号生效；局部变量只改当前作用域，模块字段/导出函数可能跨文件修改引用，建议先用 `grr` 看范围。
- `gra` 只在当前位置确实有 code action 时才有内容；LuaLS 提供的 action 较少，提示 `No code actions available` 属于正常现象。
- LuaLS 首次索引项目时，`K` 可能暂时没有结果，稍等几秒再试。

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
