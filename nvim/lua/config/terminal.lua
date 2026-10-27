-- 底部终端开关：使用 Neovim 原生 :terminal，不额外引入插件。
--
-- <leader>tt:
--   - 没有终端时：在底部打开 12 行终端并进入插入模式
--   - 终端已显示但不当前：切到终端
--   - 终端当前：隐藏终端，进程继续运行
--
-- 终端 normal 模式下按 q 也可以隐藏；插入模式下先按 <C-\><C-n> 回到 normal。
local M = {}

local term_buf
local term_win

local function term_buf_ok()
  return term_buf ~= nil and vim.api.nvim_buf_is_valid(term_buf)
end

local function term_win_ok()
  return term_win ~= nil
    and vim.api.nvim_win_is_valid(term_win)
    and vim.api.nvim_win_get_buf(term_win) == term_buf
end

local function enter_insert()
  vim.cmd('startinsert')
end

local function open_terminal()
  if term_buf_ok() then
    -- 复用已存在的终端 buffer；即使窗口关掉，shell 进程仍在运行。
    vim.cmd('botright split')
    term_win = vim.api.nvim_get_current_win()
    vim.api.nvim_win_set_buf(term_win, term_buf)
  else
    vim.cmd('botright split')
    vim.cmd('terminal')
    term_buf = vim.api.nvim_get_current_buf()
    term_win = vim.api.nvim_get_current_win()
    vim.bo[term_buf].bufhidden = 'hide'
    vim.bo[term_buf].buflisted = false
    vim.keymap.set('n', 'q', function()
      M.toggle()
    end, { buffer = term_buf, desc = '隐藏终端' })
    vim.api.nvim_create_autocmd('BufWipeout', {
      buffer = term_buf,
      once = true,
      callback = function()
        term_buf = nil
        term_win = nil
      end,
    })
  end

  vim.api.nvim_win_set_height(term_win, 12)
  enter_insert()
end

local function hide_terminal()
  if not term_win_ok() then
    term_win = nil
    return
  end

  if #vim.api.nvim_list_wins() == 1 then
    -- 不能隐藏最后一个窗口；换成一个空 buffer 后，终端仍保留在后台。
    vim.cmd('enew')
  else
    vim.api.nvim_win_hide(term_win)
  end
  term_win = nil
end

function M.toggle()
  if term_win_ok() then
    if vim.api.nvim_get_current_win() == term_win then
      hide_terminal()
    else
      vim.api.nvim_set_current_win(term_win)
      enter_insert()
    end
    return
  end

  term_win = nil
  open_terminal()
end

vim.keymap.set('n', '<leader>tt', M.toggle, { desc = '终端开关' })

return M
