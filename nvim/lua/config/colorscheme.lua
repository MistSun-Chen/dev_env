-- 配色方案与运行时切换。
--
-- 默认使用 Catppuccin Mocha；<leader>uc 可以切换 Catppuccin 的四种变体。
-- 选择只在当前 Neovim 会话生效，重启后回到下面的 default。
local M = {}

M.default = 'catppuccin-mocha'

M.flavours = {
  'catppuccin-mocha',
  'catppuccin-macchiato',
  'catppuccin-frappe',
  'catppuccin-latte',
}

local fallback = 'habamax'

function M.apply(name)
  local ok, err = pcall(vim.cmd.colorscheme, name)
  if ok then
    return true
  end

  vim.schedule(function()
    vim.notify(
      ('dev_env: 配色 %s 加载失败：%s'):format(name, tostring(err)),
      vim.log.levels.WARN
    )
  end)

  if name ~= fallback then
    pcall(vim.cmd.colorscheme, fallback)
  end
  return false
end

function M.pick()
  local ok, fzf = pcall(require, 'fzf-lua')
  if ok then
    fzf.colorschemes({
      prompt = 'Catppuccin> ',
      colors = M.flavours,
      live_preview = true,
    })
    return
  end

  vim.ui.select(M.flavours, {
    prompt = 'Catppuccin: ',
    format_item = function(item)
      return item
    end,
  }, function(choice)
    if choice then
      M.apply(choice)
    end
  end)
end

function M.setup()
  M.apply(M.default)
  vim.keymap.set('n', '<leader>uc', M.pick, { desc = '切换 Catppuccin 配色' })
end

M.setup()

return M
