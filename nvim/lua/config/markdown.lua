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

-- 表格边框统一用 Comment，避免 Catppuccin 的蓝色表头线过于抢眼。
local table_hl = {
  top = { 'Comment', 'Comment', 'Comment', 'Comment' },
  header = { 'Comment', 'Comment', 'Comment' },
  separator = { 'Comment', 'Comment', 'Comment', 'Comment' },
  row = { 'Comment', 'Comment', 'Comment' },
  bottom = { 'Comment', 'Comment', 'Comment', 'Comment' },
  overlap = { 'Comment', 'Comment', 'Comment', 'Comment' },
  align_left = 'Comment',
  align_right = 'Comment',
  align_center = { 'Comment', 'Comment' },
}

-- 表格样式：markview 自带 none/single/double/rounded/solid。
-- 当前选用 rounded（2026-10-22 确认）；切换时只改这一行，然后重启 Neovim。
local default_table_style = 'rounded'

local presets_ok, presets = pcall(require, 'markview.presets')
local table_parts = nil
if presets_ok and presets.tables and presets.tables[default_table_style] then
  table_parts = presets.tables[default_table_style].parts
end

local function table_config()
  return {
    use_virt_lines = true,
    parts = table_parts,
    hl = table_hl,
  }
end

-- max_buf_lines 在不同版本可能改名；失败时退回默认配置。
local configured = pcall(markview.setup, {
  preview = {
    icon_provider = 'internal',
    max_buf_lines = 10000,
  },
  markdown = {
    tables = table_config(),
  },
})
if not configured then
  pcall(markview.setup, {})
end

-- markview 的表格渲染在 wrap=true 时会跳过宽表（插件已知限制），官方也推荐 Markdown 使用 nowrap。
-- 只关闭 Markdown 窗口的自动换行；长行用横向滚动查看，表格才能正常渲染。
vim.api.nvim_create_autocmd({ 'FileType', 'BufWinEnter' }, {
  callback = function(args)
    if vim.bo[args.buf].filetype == 'markdown' then
      vim.wo.wrap = false
    end
  end,
})

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
