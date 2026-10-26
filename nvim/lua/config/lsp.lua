-- LSP：原生 vim.lsp、nvim-lspconfig 和 lazydev.nvim。
--
-- 当前只启用 Lua；Python/Bash 等 server 稳定后再按同样方式追加。
local M = {}

-- 原生补全菜单：不自动选中第一项，<C-y> 接受，<C-n>/<C-p> 选择。
vim.opt.completeopt = { 'menuone', 'noselect', 'popup' }

vim.diagnostic.config({
  virtual_text = {
    spacing = 2,
    prefix = '●',
  },
  severity_sort = true,
  signs = true,
  underline = true,
  update_in_insert = false,
  float = {
    border = 'rounded',
    source = true,
  },
})

-- LuaLS 的设置；nvim-lspconfig 提供 cmd/filetypes/root_markers 默认值。
vim.lsp.config('lua_ls', {
  settings = {
    Lua = {
      runtime = {
        version = 'LuaJIT',
      },
      diagnostics = {
        globals = { 'vim' },
      },
      workspace = {
        checkThirdParty = false,
      },
    },
  },
})

if vim.fn.executable('lua-language-server') == 1 then
  vim.lsp.enable('lua_ls')
else
  vim.schedule(function()
    vim.notify(
      'dev_env: 未找到 lua-language-server；请先安装并确保它在 PATH 中',
      vim.log.levels.WARN
    )
  end)
end

-- LSP 附加到 buffer 后，只在该 buffer 内覆盖需要的默认键位。
vim.api.nvim_create_autocmd('LspAttach', {
  group = vim.api.nvim_create_augroup('dev_env_lsp', { clear = true }),
  callback = function(ev)
    local client = vim.lsp.get_client_by_id(ev.data.client_id)
    if not client then
      return
    end

    if client:supports_method('textDocument/completion') then
      vim.lsp.completion.enable(true, client.id, ev.buf, { autotrigger = true })
    end

    local map = function(lhs, rhs, desc)
      vim.keymap.set('n', lhs, rhs, { buffer = ev.buf, desc = desc })
    end

    -- grn/grr/gri/gra 是 Neovim 0.12 的默认 LSP 键位，不需要重复映射。
    map('gd', vim.lsp.buf.definition, '跳转定义')
    map('K', function()
      vim.lsp.buf.hover({ border = 'rounded' })
    end, '悬停文档')
  end,
})

-- 诊断和符号用 fzf-lua 展示；没有 LSP 时给出提示，不报错。
local function with_fzf(fn, fallback, name)
  local has_client = #vim.lsp.get_clients({ bufnr = 0 }) > 0
  if not has_client then
    vim.notify(('当前 buffer 没有 LSP（%s）'):format(name), vim.log.levels.INFO)
    return
  end

  local ok, fzf = pcall(require, 'fzf-lua')
  if ok then
    fn(fzf)
  else
    fallback()
  end
end

vim.keymap.set('n', '<leader>ld', function()
  with_fzf(
    function(fzf) fzf.diagnostics_document() end,
    function() vim.diagnostic.setloclist() end,
    'diagnostics'
  )
end, { desc = 'LSP 诊断' })

vim.keymap.set('n', '<leader>ls', function()
  with_fzf(
    function(fzf) fzf.lsp_document_symbols() end,
    function() vim.lsp.buf.document_symbol() end,
    'symbols'
  )
end, { desc = 'LSP 符号' })

return M
