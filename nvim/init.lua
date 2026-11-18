-- Neovim 基础配置（跨平台）
-- 适用：Neovim 0.12+；macOS / Linux / Windows
-- 来源：从 vim_config/vimrc 迁移，只保留 Neovim 默认没有的设置
-- 安装：由 dev_env 对应平台脚本链接或复制到 stdpath('config')
-- 维护：修改后提交到 dev_env；使用软链接的机器下次启动 Neovim 即生效

-- leader 使用空格；必须在插件键位注册前设置
vim.g.mapleader = ' '
vim.g.maplocalleader = ' '

-- 系统剪贴板映射：只有这里显式使用 + 寄存器，普通 y/d/c/p 不碰系统剪贴板。
-- 策略：
--   - SSH/远程 Linux 统一使用 OSC 52，不依赖 xclip/X11；
--   - 本地 macOS 继续用 pbcopy/pbpaste；
--   - 本地 Linux GUI 在 X11 有 xclip/xsel、Wayland 有 wl-copy+wl-paste 时优先原生，否则 OSC 52。
-- tmux 配置负责把 OSC 52 转发给外层终端；终端支持列表见 docs/CLIPBOARD.md。
--
-- 注意：必须在设置 vim.g.clipboard 之前避免调用 has('clipboard')，否则 Neovim
-- 会把“没有 provider”的状态缓存下来，之后再设置 osc52 也不会生效。
local is_linux = vim.fn.has('linux') == 1
local is_ssh = (vim.env.SSH_TTY or '') ~= '' or (vim.env.SSH_CONNECTION or '') ~= ''
local has_x11 = (vim.env.DISPLAY or '') ~= ''
local has_wayland = (vim.env.WAYLAND_DISPLAY or '') ~= ''
local has_x11_tool = vim.fn.executable('xclip') == 1 or vim.fn.executable('xsel') == 1
local has_wayland_tool = vim.fn.executable('wl-copy') == 1 and vim.fn.executable('wl-paste') == 1
local has_native_tool = (has_x11 and has_x11_tool) or (has_wayland and has_wayland_tool)
-- 只有显示服务器和对应工具都匹配时才使用原生 provider；否则回退 OSC 52。
if is_linux and (is_ssh or not (has_x11 or has_wayland) or not has_native_tool) then
  vim.g.clipboard = 'osc52'
end

-- 显式关闭 unnamedplus：普通 y/d/c/p 只使用 Neovim 内部寄存器。
vim.opt.clipboard = ''

local clipboard_ok = vim.fn.has('clipboard') == 1
local uses_osc52 = vim.g.clipboard == 'osc52'
local in_tmux = (vim.env.TMUX or '') ~= ''
local function clipboard_unavailable()
  vim.notify('系统剪贴板不可用：请安装 xclip/wl-clipboard，或使用支持 OSC 52 的终端', vim.log.levels.WARN)
end
local function clipboard_paste()
  if not clipboard_ok then
    clipboard_unavailable()
    return ''
  end
  -- tmux 3.7+ 的 get-clipboard 默认会把读请求答成 tmux 最新 buffer；
  -- 旧 server 则可能不回答并让 Neovim 等待。两者都不是本地系统剪贴板。
  if uses_osc52 and in_tmux then
    vim.notify('tmux 内无法可靠读取本地剪贴板：请使用终端粘贴快捷键（如 Ctrl+Shift+V）', vim.log.levels.WARN)
    return ''
  end
  return '"+p'
end
local paste_desc = '从系统剪贴板粘贴'
if not clipboard_ok then
  paste_desc = '从系统剪贴板粘贴（不可用）'
elseif uses_osc52 and in_tmux then
  paste_desc = '从系统剪贴板粘贴（tmux 内用终端粘贴）'
end
vim.keymap.set({ 'n', 'v' }, '<leader>y', clipboard_ok and '"+y' or clipboard_unavailable, {
  desc = clipboard_ok and '复制到系统剪贴板' or '复制到系统剪贴板（不可用）',
})
vim.keymap.set({ 'n', 'v' }, '<leader>p', clipboard_paste, {
  expr = true,
  desc = paste_desc,
})

-- VTE（GNOME Terminal 等）不实现 OSC 52；本地无原生工具时给出一次提示。
if uses_osc52 and (vim.env.VTE_VERSION or '') ~= '' then
  vim.schedule(function()
    vim.notify('当前 VTE 终端不支持 OSC 52：请换用支持的终端，或在本地安装 xclip/wl-clipboard', vim.log.levels.WARN)
  end)
end

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
