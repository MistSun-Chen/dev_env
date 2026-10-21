-- 插件清单与安装入口。
--
-- 版本策略：
--   - markview.nvim 使用精确 tag，便于复现；
--   - fzf-lua 没有可用的 semver release tag，因此固定完整 commit SHA；
--   - 不使用 vim.version.range()，否则 lockfile 可能每次启动都被重写。
--
-- 实际安装由 nvim/scripts/install-plugins.sh 触发；Neovim 启动时这里只负责
-- 让 vim.pack 检查/加载已经安装的插件。
local M = {}

M.specs = {
  {
    src = 'https://github.com/ibhagwan/fzf-lua',
    version = '348df165f1773dd08c5d710add3fd0db6d421e6a',
  },
  {
    src = 'https://github.com/OXY2DEV/markview.nvim',
    version = 'v29.0.0',
  },
}

if type(vim.pack) ~= 'table' then
  vim.schedule(function()
    vim.notify('dev_env: 当前 Neovim 不支持 vim.pack，插件不会安装', vim.log.levels.WARN)
  end)
  return M
end

-- confirm = false 很关键：headless/首次启动时不能弹出确认提示。
-- 即使安装失败也继续加载基础配置，避免 Neovim 完全不可用。
local ok, err = pcall(vim.pack.add, M.specs, { confirm = false })
if not ok then
  vim.schedule(function()
    vim.notify('dev_env: 插件安装/加载失败：' .. tostring(err), vim.log.levels.WARN)
  end)
end

return M
