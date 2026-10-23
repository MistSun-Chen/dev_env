-- 文件树：neo-tree.nvim。
--
-- 键位命名：
--   e = explorer，t = toggle
--   <leader>et 打开/关闭文件树，并定位当前文件
local M = {}

local ok, neotree = pcall(require, 'neo-tree')
if not ok then
  vim.schedule(function()
    vim.notify('dev_env: neo-tree 未安装，请运行 nvim/scripts/install-plugins.sh', vim.log.levels.WARN)
  end)
  return M
end

neotree.setup({
  -- 关闭最后一个普通窗口时一并退出，避免留下空的文件树窗口。
  close_if_last_window = true,
  -- 与 Catppuccin 的圆角风格保持一致。
  popup_border_style = 'rounded',
  enable_git_status = true,
  enable_diagnostics = true,
  filesystem = {
    -- 当前 buffer 切换时，文件树自动跟随并定位当前文件；
    -- <leader>et 打开时也会因此直接定位。
    follow_current_file = { enabled = true },
    -- 用 libuv 监听文件系统变化，外部改动后不需要手动刷新。
    use_libuv_file_watcher = true,
    filtered_items = {
      hide_dotfiles = false,
      hide_gitignored = true,
    },
    window = {
      -- 在 / 打开的模糊过滤弹窗里，支持与 fzf 一致的 <C-j>/<C-k>。
      fuzzy_finder_mappings = {
        ['<C-j>'] = 'move_cursor_down',
        ['<C-k>'] = 'move_cursor_up',
      },
    },
  },
  window = {
    width = 32,
    -- 路径层级变深时自动加宽；只增不减。
    auto_expand_width = true,
  },
})

vim.keymap.set('n', '<leader>et', '<Cmd>Neotree toggle<CR>', {
  desc = '文件树开关（定位当前文件）',
})

return M
