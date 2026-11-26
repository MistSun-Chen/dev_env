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

-- Markdown 默认软换行：长段落不会因为横向滚动（leftcol 变大）丢掉行首。
--
-- 取舍：
--   - wrap=true 时 markview 会放弃渲染"原始宽度 >= 窗口 90%"的宽表格，这类表格
--     回退成原始 Markdown 文本（仍可读）；普通表格不受影响。
--   - wrap=false 时表格总能渲染，但长行要横向滚动；而且只要窗口滚动过，
--     markview 就会跳过表格渲染（插件内部 leftcol 保护），表格反而会消失。
--
-- 所以默认选 wrap=true，宽表格需要看渲染效果时用 <leader>mw 临时关掉换行。
-- 注意：markview 在 wrap 模式下会自行模拟换行缩进并临时关闭 breakindent，
-- 这里不再设置 breakindent，避免两边冲突。
local md_win_saved = {} -- winid -> 原始 wrap/linebreak

local function apply_markdown_window(win)
  if not md_win_saved[win] then
    md_win_saved[win] = {
      wrap = vim.wo[win].wrap,
      linebreak = vim.wo[win].linebreak,
    }
  end
  vim.wo[win].wrap = true
  vim.wo[win].linebreak = true
end

local function restore_markdown_window(win)
  local saved = md_win_saved[win]
  if saved and vim.api.nvim_win_is_valid(win) then
    vim.wo[win].wrap = saved.wrap
    vim.wo[win].linebreak = saved.linebreak
  end
  md_win_saved[win] = nil
end

vim.api.nvim_create_autocmd({ 'FileType', 'BufWinEnter' }, {
  callback = function(args)
    if vim.bo[args.buf].filetype ~= 'markdown' then
      restore_markdown_window(vim.api.nvim_get_current_win())
      return
    end
    for _, win in ipairs(vim.fn.win_findbuf(args.buf)) do
      apply_markdown_window(win)
    end
  end,
})

-- 同一窗口切换到非 Markdown buffer 时，恢复原来的 wrap/linebreak。
vim.api.nvim_create_autocmd('BufWinLeave', {
  callback = function(args)
    if vim.bo[args.buf].filetype == 'markdown' then
      restore_markdown_window(vim.api.nvim_get_current_win())
    end
  end,
})

vim.keymap.set('n', '<leader>mp', '<Cmd>Markview Toggle<CR>', { desc = 'Markdown 预览开关' })
vim.keymap.set('n', '<leader>ms', '<Cmd>Markview splitToggle<CR>', { desc = 'Markdown 分屏预览' })
vim.keymap.set('n', '<leader>mw', function()
  if vim.bo.filetype ~= 'markdown' then
    vim.notify('当前 buffer 不是 Markdown；换行开关只在 Markdown 下使用', vim.log.levels.WARN)
    return
  end
  vim.wo.wrap = not vim.wo.wrap
  vim.notify('Markdown wrap: ' .. (vim.wo.wrap and 'on' or 'off'))
end, { desc = 'Markdown 换行开关（关掉可渲染宽表格）' })

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
