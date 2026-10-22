-- lazy.nvim 插件清单。
--
-- 版本策略：
--   - 使用 commit 固定 fzf-lua、markview.nvim 和 grug-far.nvim；
--   - 实际安装 revision 记录在 nvim/lazy-lock.json；
--   - lazy.nvim 自身由 config/lazy.lua 引导安装并固定 commit。
return {
  {
    'ibhagwan/fzf-lua',
    commit = '348df165f1773dd08c5d710add3fd0db6d421e6a',
    lazy = false,
    config = function()
      require('config.picker')
    end,
  },
  {
    'OXY2DEV/markview.nvim',
    commit = '49d2cf7ced872db74083a144ded1f94fe224d09a',
    lazy = false,
    config = function()
      require('config.markdown')
    end,
  },
  {
    'MagicDuck/grug-far.nvim',
    commit = '91b7e58b6ffc6ddad5acb7a7c1df21257724449e',
    lazy = false,
    config = function()
      require('config.search_replace')
    end,
  },
  {
    'catppuccin/nvim',
    name = 'catppuccin',
    lazy = false,
    priority = 1000,
    config = function()
      pcall(function()
        require('catppuccin').setup({ flavour = 'mocha' })
      end)
    end,
  },
}
