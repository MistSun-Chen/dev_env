-- 搜索与替换：grug-far.nvim。
--
-- grug-far 的 buffer 里有 Search、Replace、Files filter、Paths、Flags 输入框，
-- 因此可以在项目、当前文件或指定路径/glob 范围内替换。
local M = {}

local ok, grug = pcall(require, 'grug-far')
if not ok then
  vim.schedule(function()
    vim.notify('dev_env: grug-far 未安装，请运行 nvim/scripts/install-plugins.sh', vim.log.levels.WARN)
  end)
  return M
end

grug.setup({
  -- 用底部横向 split，避免默认 vsplit 改变左右布局。
  windowCreationCommand = 'botright split',
  -- 导航匹配时不要自动把光标居中，减少窗口跳动。
  centerOnNavigation = false,
})

-- 项目范围搜索/替换；预填光标下的单词。
vim.keymap.set('n', '<leader>sr', function()
  grug.open({
    prefills = {
      search = vim.fn.expand('<cword>'),
    },
  })
end, { desc = '搜索并替换' })

-- 当前文件范围搜索/替换。
vim.keymap.set('n', '<leader>sR', function()
  grug.open({
    prefills = {
      paths = vim.fn.expand('%'),
    },
  })
end, { desc = '当前文件搜索并替换' })

-- 视觉选区：把选区作为搜索内容，并限制在选区内替换。
vim.keymap.set('v', '<leader>sr', function()
  grug.open({
    visualSelectionUsage = 'operate-within-range',
  })
end, { desc = '在选区中搜索并替换' })

return M
