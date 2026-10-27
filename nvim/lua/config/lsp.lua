-- LSP：原生 vim.lsp、nvim-lspconfig 和 lazydev.nvim。
--
-- 已启用 Lua、Python、Bash、C/C++；server 可执行文件在 PATH 中时才会启动。
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

-- Pyright 的设置。项目里的 pyrightconfig.json / pyproject.toml 仍然优先。
vim.lsp.config('pyright', {
  settings = {
    python = {
      analysis = {
        autoSearchPaths = true,
        useLibraryCodeForTypes = true,
        diagnosticMode = 'openFilesOnly',
        typeCheckingMode = 'basic',
      },
    },
  },
})

-- BashLS 的设置；安装 shellcheck 后会自动使用它做额外诊断。
vim.lsp.config('bashls', {
  settings = {
    bashIde = {
      globPattern = '*@(.sh|.inc|.bash|.command)',
    },
  },
})

-- clangd 的设置。macOS 的 Xcode Command Line Tools 自带 clangd；
-- Linux 可安装 clangd 或 LLVM。--background-index 用于跨文件索引。
vim.lsp.config('clangd', {
  cmd = { 'clangd', '--background-index' },
})

local servers = {
  {
    name = 'lua_ls',
    executable = 'lua-language-server',
    filetypes = { 'lua' },
    hint = '按 nvim/README.md 的 LSP 一节安装',
  },
  {
    name = 'pyright',
    executable = 'pyright-langserver',
    filetypes = { 'python' },
    hint = '先安装 Node.js，再按 nvim/README.md 安装 pyright',
  },
  {
    name = 'bashls',
    executable = 'bash-language-server',
    filetypes = { 'bash', 'sh' },
    hint = '先安装 Node.js，再按 nvim/README.md 安装 bash-language-server',
  },
  {
    name = 'clangd',
    executable = 'clangd',
    filetypes = { 'c', 'cpp', 'objc', 'objcpp', 'cuda' },
    hint = 'macOS: xcode-select --install；Ubuntu: sudo apt install clangd',
  },
}

for _, server in ipairs(servers) do
  if vim.fn.executable(server.executable) == 1 then
    vim.lsp.enable(server.name)
  else
    -- 等到真正打开对应类型文件时再提示，避免没装某个 server 时每次启动都警告。
    local name, executable, hint = server.name, server.executable, server.hint
    local group = vim.api.nvim_create_augroup('dev_env_lsp_missing_' .. name, { clear = true })
    vim.api.nvim_create_autocmd('FileType', {
      group = group,
      pattern = server.filetypes,
      once = true,
      callback = function()
        vim.notify(
          ('dev_env: 未找到 %s（%s）；%s'):format(name, executable, hint),
          vim.log.levels.WARN
        )
      end,
    })
  end
end

local has_c_compiler = function()
  return vim.fn.executable('cc') == 1
    or vim.fn.executable('gcc') == 1
    or vim.fn.executable('clang') == 1
end

local has_cpp_compiler = function()
  return vim.fn.executable('c++') == 1
    or vim.fn.executable('g++') == 1
    or vim.fn.executable('clang++') == 1
end

local warned_clangd_compiler = false

-- LSP 附加到 buffer 后，只在该 buffer 内覆盖需要的默认键位。
vim.api.nvim_create_autocmd('LspAttach', {
  group = vim.api.nvim_create_augroup('dev_env_lsp', { clear = true }),
  callback = function(ev)
    local client = vim.lsp.get_client_by_id(ev.data.client_id)
    if not client then
      return
    end

    if client.name == 'clangd' and not warned_clangd_compiler then
      local ft = vim.bo[ev.buf].filetype
      local is_cpp = ft == 'cpp' or ft == 'cpp.doxygen' or ft == 'objcpp' or ft == 'cuda'
      local compiler_ok
      if is_cpp then
        compiler_ok = has_cpp_compiler()
      else
        compiler_ok = has_c_compiler()
      end
      if not compiler_ok then
        warned_clangd_compiler = true
        vim.schedule(function()
          vim.notify(
            ('dev_env: clangd 已启动，但未找到 %s 编译器；系统头文件和标准库可能无法解析。'
              .. 'Ubuntu 可安装 gcc g++ libc6-dev（或 build-essential），'
              .. 'macOS 可运行 xcode-select --install。'):format(is_cpp and 'C++' or 'C'),
            vim.log.levels.WARN
          )
        end)
      end
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
