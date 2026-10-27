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
  { '<leader>l', group = 'LSP' },
  { '<leader>s', group = '搜索替换', mode = { 'n', 'v' } },
  { '<leader>m', group = 'Markdown' },
  { '<leader>t', group = '主题' },
})

return M
