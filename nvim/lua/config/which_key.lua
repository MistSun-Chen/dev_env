-- which-key：按 <leader> 后显示可用分组和键位说明。
--
-- 现有键位已经通过 vim.keymap.set 的 desc 提供说明；这里只补充
-- <leader> 前缀的分组名称，避免只显示一个没有语义的单字母。
local M = {}

local ok, wk = pcall(require, 'which-key')
if not ok then
  vim.schedule(function()
    vim.notify('dev_env: which-key 未安装，请运行 nvim/scripts/install-plugins.sh', vim.log.levels.WARN)
  end)
  return M
end

wk.setup({
  preset = 'modern',
  delay = 250,
  win = {
    border = 'rounded',
  },
})

wk.add({
  { '<leader>f', group = '查找', mode = { 'n', 'v' } },
  { '<leader>b', group = 'Buffer' },
  { '<leader>e', group = '文件树' },
  { '<leader>g', group = 'Git' },
  { '<leader>l', group = 'LSP' },
  { '<leader>s', group = '搜索替换', mode = { 'n', 'v' } },
  { '<leader>m', group = 'Markdown' },
  { '<leader>t', group = '终端/主题' },

  -- 不以 <leader> 开头的常用前缀；按 g / ] / [ 后显示下一层。
  { 'g', group = '跳转' },
  { ']', group = '下一个' },
  { '[', group = '上一个' },
})

-- 当前 buffer 的全部键位（包括 LSP/gitsigns 的 buffer-local 键位）。
-- 例如打开 Lua 文件后按 <leader>?，可以看到 gd、grr、K 等非 <leader> 键位。
vim.keymap.set('n', '<leader>?', function()
  require('which-key').show({ global = false })
end, { desc = '当前 buffer 键位' })

return M
