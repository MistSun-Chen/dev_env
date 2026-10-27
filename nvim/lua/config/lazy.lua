-- lazy.nvim 引导与插件管理入口。
--
-- 这里只负责安装 lazy.nvim 自身；which-key.nvim、gitsigns.nvim、fzf-lua、
-- markview.nvim、grug-far.nvim、neo-tree.nvim 等插件由 lazy.nvim 根据
-- lua/config/plugins.lua 和 lazy-lock.json 管理。
--
-- lazy.nvim 固定在 stable 分支的 commit，避免每次启动拉取最新代码。
-- 升级时同时修改下面的 lazy_commit 和 nvim/README.md 中的版本说明。
local M = {}

local lazy_commit = '306a05526ada86a7b30af95c5cc81ffba93fef97' -- lazy.nvim 11.17.5
local lazypath = vim.fs.joinpath(vim.fn.stdpath('data'), 'lazy', 'lazy.nvim')

local function clone_lazy()
  local repo = 'https://github.com/folke/lazy.nvim.git'
  vim.fn.mkdir(vim.fs.dirname(lazypath), 'p')

  local out = vim.fn.system({
    'git',
    'clone',
    '--filter=blob:none',
    '--branch=stable',
    repo,
    lazypath,
  })
  if vim.v.shell_error ~= 0 then
    error(('无法克隆 lazy.nvim：%s'):format(out))
  end

  out = vim.fn.system({ 'git', '-C', lazypath, 'checkout', '--quiet', lazy_commit })
  if vim.v.shell_error ~= 0 then
    error(('无法切换到 lazy.nvim %s：%s'):format(lazy_commit, out))
  end
end

if not vim.uv.fs_stat(lazypath) then
  clone_lazy()
end

vim.opt.rtp:prepend(lazypath)

require('lazy').setup({
  spec = require('config.plugins'),
  install = { missing = true },
  -- 离线环境不要做后台更新检查或配置变更监听。
  checker = { enabled = false },
  change_detection = { enabled = false },
})

return M
