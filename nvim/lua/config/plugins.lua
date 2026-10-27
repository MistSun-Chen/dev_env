-- lazy.nvim 插件清单。
--
-- 版本策略：
--   - 使用 commit 固定 which-key.nvim、gitsigns.nvim、fzf-lua、markview.nvim、
--     grug-far.nvim、neo-tree.nvim、lazydev.nvim、nvim-lspconfig 及其依赖；
--   - 实际安装 revision 记录在 nvim/lazy-lock.json；
--   - lazy.nvim 自身由 config/lazy.lua 引导安装并固定 commit。
return {
  {
    'folke/which-key.nvim',
    commit = 'fcbf4eea17cb299c02557d576f0d568878e354a4', -- v3.17.0
    lazy = false,
    config = function()
      require('config.which_key')
    end,
  },
  {
    'lewis6991/gitsigns.nvim',
    commit = 'a462f416e2ce4744531c6256252dee99a7d34a83', -- v2.1.0
    lazy = false,
    config = function()
      require('config.gitsigns')
    end,
  },
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
    'nvim-neo-tree/neo-tree.nvim',
    branch = 'v3.x',
    commit = '1a14083046d96e88e361d1da00761c40d45012f3',
    dependencies = {
      { 'nvim-lua/plenary.nvim', commit = '74b06c6c75e4eeb3108ec01852001636d85a932b' },
      { 'MunifTanjim/nui.nvim', commit = '10fc361835c856ba4233ef5ea135b919bf3dce97' },
    },
    lazy = false,
    config = function()
      require('config.explorer')
    end,
  },
  {
    'folke/lazydev.nvim',
    commit = 'ff2cbcba459b637ec3fd165a2be59b7bbaeedf0d',
    lazy = false,
    opts = {
      library = {
        -- 只有在文件里出现 vim.uv 时才加载 luv 类型。
        { path = '${3rd}/luv/library', words = { 'vim%.uv' } },
      },
    },
  },
  {
    'neovim/nvim-lspconfig',
    commit = '77b7432d4770d23b277d37923e5a08a442d8bb07',
    lazy = false,
    config = function()
      require('config.lsp')
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
