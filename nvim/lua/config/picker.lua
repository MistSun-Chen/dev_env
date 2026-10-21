-- fzf-lua picker：找文件、全局搜索、buffer、最近文件。
--
-- 外部依赖：
--   fzf  交互式模糊查找 UI（必须）
--   rg   全局搜索（强烈建议）
--   fd   文件列举（可选；fzf-lua 会自行 fallback）
local M = {}

if vim.fn.executable('fzf') ~= 1 then
  vim.schedule(function()
    vim.notify('dev_env: 找不到 fzf，picker 键位未启用', vim.log.levels.WARN)
  end)
  return M
end

local ok, fzf = pcall(require, 'fzf-lua')
if not ok then
  vim.schedule(function()
    vim.notify('dev_env: fzf-lua 未安装，请运行 nvim/scripts/install-plugins.sh', vim.log.levels.WARN)
  end)
  return M
end

fzf.setup({})

vim.keymap.set('n', '<leader>ff', fzf.files, { desc = '查找文件' })
vim.keymap.set('n', '<leader>fg', fzf.live_grep, { desc = '全局搜索' })
vim.keymap.set('n', '<leader>fb', fzf.buffers, { desc = '切换 buffer' })
vim.keymap.set('n', '<leader>fr', fzf.oldfiles, { desc = '最近文件' })

return M
