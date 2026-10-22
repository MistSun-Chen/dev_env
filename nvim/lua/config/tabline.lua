-- 内置 tabline：显示当前打开（buflisted）的文件。
--
-- 不依赖 bufferline.nvim；用 Neovim 的 'tabline' 选项和 v:lua 表达式实现。
local M = {}

local MAX_NAME_WIDTH = 24

local function short_name(buf)
  local name = buf.name ~= '' and vim.fn.fnamemodify(buf.name, ':t') or '[No Name]'
  if vim.fn.strdisplaywidth(name) > MAX_NAME_WIDTH then
    name = vim.fn.strcharpart(name, 0, MAX_NAME_WIDTH - 1) .. '…'
  end
  -- '%' 在 tabline 表达式里有特殊含义，需要转义。
  return name:gsub('%%', '%%%%')
end

function M.click(bufnr)
  if bufnr and bufnr > 0 and vim.api.nvim_buf_is_valid(bufnr) then
    vim.api.nvim_set_current_buf(bufnr)
  end
end

-- tabline 的 %N@func@ 语法调用的是 Vimscript 函数，不能直接写 Lua 全局函数。
-- 这里用一层薄包装，把 buffer 编号转给 Lua。
vim.cmd([[
  function! DevEnvTablineClick(bufnr, clicks, button, modifiers) abort
    call luaeval('require("config.tabline").click(_A)', a:bufnr)
  endfunction
]])

function M.render()
  local current = vim.api.nvim_get_current_buf()
  local parts = { '%#TabLineFill#' }

  for _, buf in ipairs(vim.fn.getbufinfo({ buflisted = 1 })) do
    -- grug-far 是临时操作 buffer，不当作“打开的文件”显示；用 <leader>sr 重新打开即可。
    if vim.bo[buf.bufnr].filetype ~= 'grug-far' then
      local hl = buf.bufnr == current and 'TabLineSel' or 'TabLine'
      local modified = buf.changed == 1 and ' +' or ''
      -- %N@func@text%X：左键点击标签切换到对应 buffer。
      parts[#parts + 1] = ('%%#%s#%%%d@DevEnvTablineClick@ %d %s%s %%X'):format(
        hl,
        buf.bufnr,
        buf.bufnr,
        short_name(buf),
        modified
      )
    end
  end

  parts[#parts + 1] = '%#TabLineFill#'
  return table.concat(parts)
end

function M.setup()
  vim.o.showtabline = 2
  vim.o.tabline = '%!v:lua.require("config.tabline").render()'
  vim.keymap.set('n', '<leader>bn', '<Cmd>bnext<CR>', { desc = '下一个 buffer' })
  vim.keymap.set('n', '<leader>bp', '<Cmd>bprevious<CR>', { desc = '上一个 buffer' })
  vim.keymap.set('n', '<leader>bd', '<Cmd>bdelete<CR>', { desc = '关闭当前 buffer' })
end

M.setup()

return M
