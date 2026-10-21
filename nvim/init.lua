-- Neovim 基础配置（跨平台）
-- 适用：Neovim 0.12+；macOS / Linux / Windows
-- 来源：从 vim_config/vimrc 迁移，只保留 Neovim 默认没有的设置
-- 安装：由 dev_env 对应平台脚本链接或复制到 stdpath('config')
-- 维护：修改后提交到 dev_env；使用软链接的机器下次启动 Neovim 即生效

-- leader 使用空格；必须在插件键位注册前设置
vim.g.mapleader = ' '
vim.g.maplocalleader = ' '

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

-- 鼠标在所有模式可用（Neovim 默认是 nvi；a = 所有模式）
vim.opt.mouse = 'a'

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

-- Mermaid 集成不依赖第三方插件，单独加载。
local mermaid_ok, mermaid_err = pcall(require, 'config.mermaid')
if not mermaid_ok then
  vim.schedule(function()
    vim.notify(('dev_env: config.mermaid 加载失败：%s'):format(tostring(mermaid_err)), vim.log.levels.WARN)
  end)
end
