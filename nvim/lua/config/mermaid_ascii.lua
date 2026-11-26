-- Mermaid ASCII 混合预览。
--
-- normal 模式：把 Markdown 的 ```mermaid 代码块折叠，并在折叠行上方显示
-- ASCII 图，因此只看得到渲染结果；insert / visual / command 模式自动展开
-- 代码块、清除 ASCII，回到原始文本编辑。
--
-- 宽图：normal 里会提示按 <leader>mb；<leader>mb 在 split 里用真实行显示
-- ASCII，nowrap，可横向滚动。
--
-- 只依赖 mermaid-ascii；不使用 Kitty 图片、md-render 或浏览器。
local M = { enabled = true }

-- 远端 nvim 可能由非交互 shell 启动；确保 ~/.local/bin 里的 mermaid-ascii
-- 能被找到。
local local_bin = vim.fn.expand('~/.local/bin')
if vim.fn.isdirectory(local_bin) == 1 and not (vim.env.PATH or ''):find(local_bin, 1, true) then
  vim.env.PATH = local_bin .. ':' .. (vim.env.PATH or '')
end

-- 折叠行不要用点填充，避免看起来像源码。
pcall(function()
  vim.opt.fillchars:append({ fold = ' ' })
end)

local ns = vim.api.nvim_create_namespace('dev_env_mermaid_ascii')
local state = {} -- bufnr -> { gen, cache, blocks, ranges }
local win_saved = {} -- winid -> 原始 fold 选项，禁用/切走后恢复
local notified = false
local foldtext_ready = false

local function is_markdown(buf)
  return vim.api.nvim_buf_is_valid(buf)
    and vim.bo[buf].filetype == 'markdown'
    and vim.bo[buf].buftype == ''
end

local function get_state(buf)
  state[buf] = state[buf] or { gen = 0, cache = {}, blocks = {}, ranges = {} }
  return state[buf]
end

local function scan_blocks(buf)
  local lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
  local blocks = {}
  local ranges = {}
  local start

  for i, line in ipairs(lines) do
    if not start and line:match('^%s*```mermaid%s*$') then
      start = i
    elseif start and line:match('^%s*```%s*$') then
      local text = table.concat(vim.list_slice(lines, start + 1, i - 1), '\n')
      blocks[#blocks + 1] = { start_row = start - 1, end_row = i - 1, text = text }
      for l = start, i do
        ranges[l] = 1
      end
      start = nil
    end
  end

  local st = get_state(buf)
  st.blocks = blocks
  st.ranges = ranges
  return blocks
end

--- foldexpr：mermaid 块范围为 level 1，其余为 0。
--- 通过 `v:lua.require'config.mermaid_ascii'.foldexpr(v:lnum)` 调用。
function M.foldexpr(lnum)
  local buf = vim.api.nvim_get_current_buf()
  if not is_markdown(buf) then
    return 0
  end
  local st = get_state(buf)
  if not st.ranges then
    scan_blocks(buf)
  end
  return (st.ranges and st.ranges[lnum]) or 0
end

local function define_foldtext()
  if foldtext_ready then
    return
  end
  foldtext_ready = true
  vim.cmd([[
    function! DevEnvMermaidFoldText()
      if getline(v:foldstart) =~# '^\s*```mermaid'
        return ''
      endif
      return getline(v:foldstart) .. ' ...'
    endfunction
  ]])
end

local function ensure_fold_opts(buf, open)
  define_foldtext()
  for _, win in ipairs(vim.fn.win_findbuf(buf)) do
    if not win_saved[win] then
      win_saved[win] = {
        foldmethod = vim.wo[win].foldmethod,
        foldexpr = vim.wo[win].foldexpr,
        foldtext = vim.wo[win].foldtext,
        foldenable = vim.wo[win].foldenable,
        foldlevel = vim.wo[win].foldlevel,
      }
    end
    vim.wo[win].foldmethod = 'expr'
    vim.wo[win].foldexpr = "v:lua.require'config.mermaid_ascii'.foldexpr(v:lnum)"
    vim.wo[win].foldtext = 'DevEnvMermaidFoldText()'
    vim.wo[win].foldenable = M.enabled
    vim.wo[win].foldlevel = open and 1 or 0
  end
end

local function restore_fold_opts(buf, only_win)
  for _, win in ipairs(vim.fn.win_findbuf(buf)) do
    if not only_win or win == only_win then
      local saved = win_saved[win]
      if saved and vim.api.nvim_win_is_valid(win) then
        vim.wo[win].foldmethod = saved.foldmethod
        vim.wo[win].foldexpr = saved.foldexpr
        vim.wo[win].foldtext = saved.foldtext
        vim.wo[win].foldenable = saved.foldenable
        vim.wo[win].foldlevel = saved.foldlevel
      end
      win_saved[win] = nil
    end
  end
end

local function cleanup(buf)
  if vim.api.nvim_buf_is_valid(buf) then
    vim.api.nvim_buf_clear_namespace(buf, ns, 0, -1)
  end
  restore_fold_opts(buf)
  state[buf] = nil
end

local function clear(buf, open)
  local st = get_state(buf)
  st.gen = st.gen + 1
  st.ranges = nil
  if vim.api.nvim_buf_is_valid(buf) then
    vim.api.nvim_buf_clear_namespace(buf, ns, 0, -1)
    ensure_fold_opts(buf, open)
  end
end

local function render_ascii(st, text, width)
  local key = vim.fn.sha256(text .. '|' .. tostring(width))
  if st.cache[key] then
    return st.cache[key]
  end

  if vim.fn.executable('mermaid-ascii') ~= 1 then
    if not notified then
      notified = true
      vim.schedule(function()
        vim.notify('dev_env: 找不到 mermaid-ascii，Mermaid ASCII 预览不可用', vim.log.levels.WARN)
      end)
    end
    return nil
  end

  local obj = vim.system(
    { 'mermaid-ascii', '-f', '-', '--max-width', tostring(width) },
    { stdin = text .. '\n', text = true }
  ):wait()
  if obj.code ~= 0 then
    return nil
  end

  local lines = vim.split(obj.stdout or '', '\n', { plain = true })
  while #lines > 0 and lines[#lines] == '' do
    table.remove(lines)
  end
  if #lines == 0 then
    return nil
  end

  local chunks = {}
  local maxw = 0
  for i, line in ipairs(lines) do
    -- mermaid-ascii 会用行尾空格对齐，不能把对齐空格算进“过宽”。
    line = line:gsub('%s+$', '')
    lines[i] = line
    maxw = math.max(maxw, vim.fn.strdisplaywidth(line))
    chunks[#chunks + 1] = { { line, 'Comment' } }
  end
  if maxw > width then
    chunks[#chunks + 1] = {
      { ('(图过宽：%d 列，按 <leader>mb 打开可横向滚动)'):format(maxw), 'WarningMsg' },
    }
  end

  local val = { chunks = chunks, maxw = maxw, lines = lines }
  st.cache[key] = val
  return val
end

local function render(buf)
  if not M.enabled or not is_markdown(buf) then
    return
  end
  if vim.api.nvim_get_mode().mode ~= 'n' then
    return
  end

  local st = get_state(buf)
  local gen = st.gen
  st.ranges = nil
  local blocks = scan_blocks(buf)

  ensure_fold_opts(buf, false)
  vim.api.nvim_buf_clear_namespace(buf, ns, 0, -1)

  local width = math.max(40, vim.o.columns - 4)
  for _, block in ipairs(blocks) do
    local out = render_ascii(st, block.text, width)
    if out and gen == st.gen and vim.api.nvim_buf_is_valid(buf) then
      -- 不能在折叠行上放 virt_lines：折叠行会把 extmark 隐藏掉。
      -- 放在折叠块的上一行（可见）下方；块在第一行时才退化为 above。
      local mark_row = block.start_row
      local above = true
      if block.start_row > 0 then
        mark_row = block.start_row - 1
        above = false
      end
      vim.api.nvim_buf_set_extmark(buf, ns, mark_row, 0, {
        virt_lines = out.chunks,
        virt_lines_above = above,
      })
    end
  end

  -- 折叠源码；ASCII 显示在折叠行上方。
  ensure_fold_opts(buf, false)
end

local function schedule_render(buf)
  vim.schedule(function()
    if vim.api.nvim_buf_is_valid(buf) then
      render(buf)
    end
  end)
end

local function current_block(buf)
  local blocks = scan_blocks(buf)
  if #blocks == 0 then
    return nil
  end

  local row = vim.api.nvim_win_get_cursor(0)[1]
  for _, b in ipairs(blocks) do
    if row >= b.start_row + 1 and row <= b.end_row + 1 then
      return b
    end
  end

  -- 光标不在块内：只有一个块时直接用它；多个块时只接受离光标 3 行以内的块。
  if #blocks == 1 then
    return blocks[1]
  end

  local best, bestd
  for _, b in ipairs(blocks) do
    local d
    if row < b.start_row + 1 then
      d = b.start_row + 1 - row
    else
      d = row - (b.end_row + 1)
    end
    if not bestd or d < bestd then
      best, bestd = b, d
    end
  end
  if best and bestd and bestd <= 3 then
    return best
  end
  return nil
end

local function open_block_view()
  local buf = vim.api.nvim_get_current_buf()
  if not is_markdown(buf) then
    vim.notify('当前 buffer 不是 Markdown', vim.log.levels.WARN)
    return
  end

  local block = current_block(buf)
  if not block then
    vim.notify('光标不在 mermaid 代码块内', vim.log.levels.INFO)
    return
  end

  local st = get_state(buf)
  local out = render_ascii(st, block.text, 400)
  if not out then
    vim.notify('mermaid-ascii 渲染失败', vim.log.levels.WARN)
    return
  end

  vim.cmd('botright split')
  local sb = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_win_set_buf(0, sb)
  vim.api.nvim_buf_set_lines(sb, 0, -1, false, out.lines)
  vim.bo[sb].buftype = 'nofile'
  vim.bo[sb].bufhidden = 'wipe'
  vim.bo[sb].swapfile = false
  vim.bo[sb].filetype = 'mermaid-ascii'
  vim.bo[sb].modifiable = false

  vim.wo.wrap = false
  vim.wo.number = false
  vim.wo.relativenumber = false
  vim.wo.signcolumn = 'no'
  vim.wo.foldenable = false
  vim.wo.foldmethod = 'manual'
  pcall(function()
    vim.wo.winbar = ' Mermaid ASCII  |  h/l 或 zh/zl 横向滚动  |  q 关闭 '
  end)

  vim.keymap.set('n', 'q', '<Cmd>close<CR>', { buffer = true, desc = '关闭' })
  vim.keymap.set('n', '<Esc>', '<Cmd>close<CR>', { buffer = true, desc = '关闭' })
end

local group = vim.api.nvim_create_augroup('dev_env_mermaid_ascii', { clear = true })

vim.api.nvim_create_autocmd({ 'FileType', 'BufEnter', 'BufWinEnter' }, {
  group = group,
  callback = function(args)
    if vim.bo[args.buf].filetype == 'markdown' then
      if vim.api.nvim_get_mode().mode == 'n' then
        schedule_render(args.buf)
      else
        clear(args.buf, true)
      end
    else
      cleanup(args.buf)
    end
  end,
})

-- 离开 Markdown 窗口时把 fold 选项还给原窗口，避免影响代码 buffer。
vim.api.nvim_create_autocmd('BufWinLeave', {
  group = group,
  callback = function(args)
    if is_markdown(args.buf) then
      restore_fold_opts(args.buf, vim.api.nvim_get_current_win())
    end
  end,
})

vim.api.nvim_create_autocmd('BufWipeout', {
  group = group,
  callback = function(args)
    cleanup(args.buf)
  end,
})

vim.api.nvim_create_autocmd('ModeChanged', {
  group = group,
  pattern = '*',
  callback = function(args)
    local buf = args.buf
    if not is_markdown(buf) then
      return
    end
    local new = vim.v.event.new_mode or ''
    if new == 'n' then
      schedule_render(buf)
    else
      clear(buf, true)
    end
  end,
})

vim.api.nvim_create_autocmd({ 'TextChanged', 'TextChangedI' }, {
  group = group,
  callback = function(args)
    local buf = args.buf
    if not is_markdown(buf) then
      return
    end
    clear(buf, true)
    if vim.api.nvim_get_mode().mode == 'n' then
      schedule_render(buf)
    end
  end,
})

-- 启动时终端尺寸可能还没确定；窗口变化后按新宽度重新生成 ASCII，
-- 否则宽图提示会按错误的宽度判断。
vim.api.nvim_create_autocmd('VimResized', {
  group = group,
  callback = function(args)
    local buf = args.buf
    if is_markdown(buf) and vim.api.nvim_get_mode().mode == 'n' then
      schedule_render(buf)
    end
  end,
})

vim.keymap.set('n', '<leader>ma', function()
  M.enabled = not M.enabled
  local buf = vim.api.nvim_get_current_buf()
  if M.enabled then
    schedule_render(buf)
  else
    cleanup(buf)
  end
  vim.notify('Mermaid ASCII 预览: ' .. (M.enabled and 'on' or 'off'))
end, { desc = 'Mermaid ASCII 混合预览开关' })

vim.keymap.set('n', '<leader>mb', open_block_view, { desc = 'Mermaid ASCII 宽图查看（可横向滚动）' })

-- 供测试使用。
M._render = render
M._clear = clear
M._open_block_view = open_block_view

return M
