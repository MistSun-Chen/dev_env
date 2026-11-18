-- Neovim 基础配置（跨平台）
-- 适用：Neovim 0.12+；macOS / Linux / Windows
-- 来源：从 vim_config/vimrc 迁移，只保留 Neovim 默认没有的设置
-- 安装：由 dev_env 对应平台脚本链接或复制到 stdpath('config')
-- 维护：修改后提交到 dev_env；使用软链接的机器下次启动 Neovim 即生效

-- leader 使用空格；必须在插件键位注册前设置
vim.g.mapleader = ' '
vim.g.maplocalleader = ' '

-- 系统剪贴板映射：只有这里显式使用 + 寄存器，普通 y/d/c/p 不碰系统剪贴板。
vim.keymap.set({ 'n', 'v' }, '<leader>y', '"+y', { desc = '复制到系统剪贴板' })
vim.keymap.set({ 'n', 'v' }, '<leader>p', '"+p', { desc = '从系统剪贴板粘贴' })

-- 显示绝对行号；配合 relativenumber 形成“当前行绝对、其他行相对”的混合行号
vim.opt.number = true

-- 相对行号，方便用 {count}j / {count}k 跳转
vim.opt.relativenumber = true

-- 搜索默认忽略大小写
vim.opt.ignorecase = true

-- 但搜索词包含大写字母时转为区分大小写
vim.opt.smartcase = true

-- 关闭启动时的 intro 信息
vim.opt.shortmess:append('I')

-- 持久化撤销历史：关闭文件后仍可撤销，撤销文件默认存放在 stdpath('state')/undo
vim.opt.undofile = true

-- 关闭 Neovim 的鼠标处理，让终端原生拖选和 Cmd+C 生效；tmux 同样 mouse off。
-- 代价：Neovim 内不能用鼠标点击/滚轮；需要时用键盘，或临时在终端用绕过修饰键。
vim.opt.mouse = ''

-- 开启 24-bit 颜色；绝大多数现代终端支持。若颜色异常，检查终端 true color 设置。
vim.opt.termguicolors = true

-- 说明：Q 保留 Neovim 默认行为（重复上一次录制的寄存器）。
-- 旧 vimrc 中的 `nmap Q <Nop>` 没有迁移；如果以后想禁用 Q，再显式添加映射。

-- 禁用方向键，提示改用 hjkl；normal 与 insert 模式都拦截
-- 提示信息沿用 vimrc 的 "Use h"；如果想让提示也中文化，可改成 "请使用 h"
local arrow_hints = {
  ['<Left>'] = 'h',
  ['<Right>'] = 'l',
  ['<Up>'] = 'k',
  ['<Down>'] = 'j',
}

for key, hint in pairs(arrow_hints) do
  vim.keymap.set('n', key, ':echoe "Use ' .. hint .. '"<CR>', {
    desc = '禁用方向键：请用 ' .. hint,
  })
  vim.keymap.set('i', key, '<Esc>:echoe "Use ' .. hint .. '"<CR>', {
    desc = '禁用方向键：请用 ' .. hint,
  })
end

-- 先启动 lazy.nvim；picker/markdown 的配置由 lazy 的 config 回调加载。
local lazy_ok, lazy_err = pcall(require, 'config.lazy')
if not lazy_ok then
  vim.schedule(function()
    vim.notify(('dev_env: lazy.nvim 初始化失败：%s'):format(tostring(lazy_err)), vim.log.levels.WARN)
  end)
end

-- 配色在 lazy.nvim 加载完配色插件后应用。
local colors_ok, colors_err = pcall(require, 'config.colorscheme')
if not colors_ok then
  vim.schedule(function()
    vim.notify(('dev_env: config.colorscheme 加载失败：%s'):format(tostring(colors_err)), vim.log.levels.WARN)
  end)
end

-- 顶部 tabline：显示已打开的文件。
local tabline_ok, tabline_err = pcall(require, 'config.tabline')
if not tabline_ok then
  vim.schedule(function()
    vim.notify(('dev_env: config.tabline 加载失败：%s'):format(tostring(tabline_err)), vim.log.levels.WARN)
  end)
end

-- 底部终端开关（原生 :terminal）。
local terminal_ok, terminal_err = pcall(require, 'config.terminal')
if not terminal_ok then
  vim.schedule(function()
    vim.notify(('dev_env: config.terminal 加载失败：%s'):format(tostring(terminal_err)), vim.log.levels.WARN)
  end)
end
