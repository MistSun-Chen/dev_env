-- Markdown 终端内渲染：markview.nvim。
--
-- 公式依赖 latex Tree-sitter parser：
--   由 nvim/scripts/build-latex-parser.sh 编译并安装到
--   stdpath('data')/site/parser/latex.so。
local M = {}

local ok, markview = pcall(require, 'markview')
if not ok then
  vim.schedule(function()
    vim.notify('dev_env: markview 未安装，请运行 nvim/scripts/install-plugins.sh', vim.log.levels.WARN)
  end)
  return M
end

-- max_buf_lines 在不同版本可能改名；失败时退回默认配置。
local configured = pcall(markview.setup, {
  preview = {
    icon_provider = 'internal',
    max_buf_lines = 10000,
  },
})
if not configured then
  pcall(markview.setup, {})
end

vim.keymap.set('n', '<leader>mp', '<Cmd>Markview Toggle<CR>', { desc = 'Markdown 预览开关' })
vim.keymap.set('n', '<leader>ms', '<Cmd>Markview splitToggle<CR>', { desc = 'Markdown 分屏预览' })

local toc_ok, toc = pcall(require, 'config.markdown_toc')
if toc_ok then
  vim.keymap.set('n', '<leader>mt', toc.pick, { desc = 'Markdown 目录' })
end

if not pcall(vim.treesitter.language.add, 'latex') then
  vim.schedule(function()
    vim.notify(
      'dev_env: 未找到 latex Tree-sitter parser，公式会保持原始文本；请运行 nvim/scripts/build-latex-parser.sh',
      vim.log.levels.WARN
    )
  end)
end

return M
