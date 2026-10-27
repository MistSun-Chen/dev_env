-- Git 行内状态与 hunk 操作：gitsigns.nvim。
--
-- 键位命名：
--   g = git
--   s = stage（暂存）  r = reset（丢弃）  p = preview（预览）
--   b = blame（追溯）  d = diff（对比）   t = toggle（开关）
--   q = quickfix      S/R = stage/reset 整个 buffer
--
-- ]c / [c 是 gitsigns 建议的 hunk 跳转键位，在其他 buffer 中仍保持默认行为。
local M = {}

local ok, gitsigns = pcall(require, 'gitsigns')
if not ok then
  vim.schedule(function()
    vim.notify('dev_env: gitsigns 未安装，请运行 nvim/scripts/install-plugins.sh', vim.log.levels.WARN)
  end)
  return M
end

gitsigns.setup({
  -- 新文件也可以直接 stage；默认只在已跟踪文件上显示 signs。
  attach_to_untracked = true,
  -- 打开文件时不自动显示整行 blame，避免遮挡编辑区域。
  current_line_blame = false,
  current_line_blame_opts = {
    virt_text = true,
    virt_text_pos = 'eol',
    delay = 300,
  },
  on_attach = function(bufnr)
    local function map(mode, lhs, rhs, desc)
      vim.keymap.set(mode, lhs, rhs, { buffer = bufnr, desc = desc })
    end

    -- hunk 跳转；diff 模式下沿用 Vim 自带的 ]c / [c。
    map('n', ']c', function()
      if vim.wo.diff then
        vim.cmd.normal({ ']c', bang = true })
      else
        gitsigns.nav_hunk('next')
      end
    end, '下一个 Git hunk')

    map('n', '[c', function()
      if vim.wo.diff then
        vim.cmd.normal({ '[c', bang = true })
      else
        gitsigns.nav_hunk('prev')
      end
    end, '上一个 Git hunk')

    -- 暂存与丢弃；visual 模式作用于选中的行范围。
    map('n', '<leader>gs', gitsigns.stage_hunk, '暂存当前 hunk')
    map('v', '<leader>gs', function()
      gitsigns.stage_hunk({ vim.fn.line('.'), vim.fn.line('v') })
    end, '暂存选中 hunk')

    map('n', '<leader>gr', gitsigns.reset_hunk, '丢弃当前 hunk')
    map('v', '<leader>gr', function()
      gitsigns.reset_hunk({ vim.fn.line('.'), vim.fn.line('v') })
    end, '丢弃选中 hunk')

    map('n', '<leader>gS', gitsigns.stage_buffer, '暂存整个 buffer')
    map('n', '<leader>gR', gitsigns.reset_buffer, '丢弃整个 buffer 的改动')

    -- 预览与对比。
    map('n', '<leader>gp', gitsigns.preview_hunk, '预览当前 hunk')
    map('n', '<leader>gP', gitsigns.preview_hunk_inline, '行内预览当前 hunk')
    map('n', '<leader>gd', gitsigns.diffthis, '对比当前文件与索引')
    map('n', '<leader>gD', function()
      gitsigns.diffthis('~')
    end, '对比当前文件与 HEAD')

    -- 追溯。
    map('n', '<leader>gb', function()
      gitsigns.blame_line({ full = true })
    end, '查看当前行 blame')
    map('n', '<leader>gB', gitsigns.blame, '打开整文件 blame')

    -- 开关。
    map('n', '<leader>gt', gitsigns.toggle_current_line_blame, '开关当前行 blame')
    map('n', '<leader>gw', gitsigns.toggle_word_diff, '开关 word diff')

    -- 把 hunk 放进 quickfix；q = 当前 buffer，Q = 所有已 attach 的 buffer。
    map('n', '<leader>gq', gitsigns.setqflist, '当前文件 hunk 放入 quickfix')
    map('n', '<leader>gQ', function()
      gitsigns.setqflist('attached')
    end, '已打开文件的 hunk 放入 quickfix')

    -- 把 hunk 当作文本对象：dih / cih / yih。
    map({ 'o', 'x' }, 'ih', gitsigns.select_hunk, '选择 Git hunk')
  end,
})

return M
