-- 终端内 Mermaid 预览。
--
-- 使用 mermaid-ascii 单文件二进制，把 Markdown 里的 ```mermaid 代码块
-- 渲染成 Unicode/ASCII 文本图，通过 extmark 的 virt_lines 显示在代码块下方。
-- 不依赖 Node、浏览器或 Kitty Graphics。
local M = {}

local ns = vim.api.nvim_create_namespace('dev_env_mermaid')
local state = {}

local SUPPORTED = {
  graph = true,
  flowchart = true,
  sequenceDiagram = true,
  erDiagram = true,
}

local UNSUPPORTED_HINT = {
  stateDiagram = 'stateDiagram',
  classDiagram = 'classDiagram',
  gantt = 'gantt',
  pie = 'pie',
  timeline = 'timeline',
  journey = 'journey',
  mindmap = 'mindmap',
  quadrantChart = 'quadrantChart',
  requirementDiagram = 'requirementDiagram',
  gitGraph = 'gitGraph',
}

local notified_missing_bin = false

local function notify(msg, level)
  vim.schedule(function()
    vim.notify('dev_env: ' .. msg, level or vim.log.levels.INFO)
  end)
end

local function is_markdown(buf)
  return vim.api.nvim_buf_is_valid(buf) and vim.bo[buf].filetype == 'markdown'
end

local function get_state(buf)
  state[buf] = state[buf] or { generation = 0, cache = {}, pending = {} }
  return state[buf]
end

local function cancel_timer(st)
  if st and st.timer then
    pcall(function()
      st.timer:stop()
    end)
    pcall(function()
      st.timer:close()
    end)
    st.timer = nil
  end
end

local function get_width(buf)
  local wins = vim.fn.win_findbuf(buf)
  local win = wins[1]
  if not win or win == 0 then
    win = vim.api.nvim_get_current_win()
  end
  local ok, width = pcall(vim.api.nvim_win_get_width, win)
  if not ok then
    return 80
  end
  local info = vim.fn.getwininfo(win)[1]
  local textoff = info and info.textoff or 0
  return math.max(20, width - textoff - 2)
end

local function trim_info(info)
  if not info then
    return nil
  end
  -- 去掉可能的属性，例如 "mermaid title=..."。
  return info:match('^%s*([^%s]+)')
end

local function get_text(node, buf)
  local ok, text = pcall(vim.treesitter.get_node_text, node, buf)
  if ok and text then
    return text
  end
  return nil
end

local function blocks_from_treesitter(buf)
  local ok, parser = pcall(vim.treesitter.get_parser, buf, 'markdown')
  if not ok or not parser then
    return nil
  end

  local ok_tree, tree = pcall(function()
    return parser:parse()[1]
  end)
  if not ok_tree or not tree then
    return nil
  end

  local ok_query, query = pcall(vim.treesitter.query.parse, 'markdown', '((fenced_code_block) @block)')
  if not ok_query or not query then
    return nil
  end

  local blocks = {}
  for _, node in query:iter_captures(tree:root(), buf, 0, -1) do
    local info, content
    for child in node:iter_children() do
      local kind = child:type()
      if kind == 'info_string' then
        info = trim_info(get_text(child, buf))
      elseif kind == 'code_fence_content' then
        content = child
      end
    end

    if info == 'mermaid' and content then
      local text = get_text(content, buf)
      if text and text:match('%S') then
        local _, _, end_row = node:range()
        blocks[#blocks + 1] = {
          text = text,
          end_row = end_row,
          first = text:match('^%s*([%w_]+)') or '',
        }
      end
    end
  end

  return blocks
end

local function blocks_from_regex(buf)
  local lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
  local blocks = {}
  local i = 1
  while i <= #lines do
    if lines[i]:match('^%s*```%s*mermaid%s*$') then
      local start_line = i + 1
      local j = start_line
      while j <= #lines and not lines[j]:match('^%s*```%s*$') do
        j = j + 1
      end
      if j <= #lines then
        local body = {}
        for k = start_line, j - 1 do
          body[#body + 1] = lines[k]
        end
        local text = table.concat(body, '\n')
        if text:match('%S') then
          blocks[#blocks + 1] = {
            text = text,
            end_row = j - 1,
            first = text:match('^%s*([%w_]+)') or '',
          }
        end
      end
      i = j + 1
    else
      i = i + 1
    end
  end
  return blocks
end

local function get_blocks(buf)
  local blocks = blocks_from_treesitter(buf)
  if blocks and #blocks > 0 then
    return blocks
  end
  return blocks_from_regex(buf)
end

local function to_chunks(lines)
  local chunks = {}
  for _, line in ipairs(lines) do
    chunks[#chunks + 1] = { { line, 'Comment' } }
  end
  return chunks
end

local function place(buf, block, lines)
  if not vim.api.nvim_buf_is_valid(buf) or not is_markdown(buf) then
    return
  end
  local max_row = math.max(0, vim.api.nvim_buf_line_count(buf) - 1)
  local row = math.max(0, math.min(block.end_row, max_row))
  pcall(vim.api.nvim_buf_set_extmark, buf, ns, row, 0, {
    virt_lines = to_chunks(lines),
    virt_lines_leftcol = true,
    priority = 120,
  })
end

local function split_output(out)
  local lines = vim.split(out or '', '\n', { plain = true })
  for i = #lines, 1, -1 do
    if lines[i] == '' or lines[i] == '\r' then
      table.remove(lines, i)
    else
      break
    end
  end
  return lines
end

local function clear(buf)
  if vim.api.nvim_buf_is_valid(buf) then
    vim.api.nvim_buf_clear_namespace(buf, ns, 0, -1)
  end
  local st = state[buf]
  if st then
    st.generation = st.generation + 1
  end
end

local function request(buf, block, key, width, generation)
  local st = get_state(buf)
  if st.pending[key] then
    return
  end
  st.pending[key] = true

  if vim.fn.executable('mermaid-ascii') ~= 1 then
    st.pending[key] = nil
    if not notified_missing_bin then
      notified_missing_bin = true
      notify('找不到 mermaid-ascii，Mermaid 代码块会显示源码', vim.log.levels.WARN)
    end
    return
  end

  local ok, err = pcall(vim.system, {
    'mermaid-ascii',
    '--max-width',
    tostring(width),
  }, {
    stdin = block.text .. '\n',
    text = true,
  }, function(obj)
    vim.schedule(function()
      st.pending[key] = nil
      if not vim.api.nvim_buf_is_valid(buf) or st.generation ~= generation or not is_markdown(buf) then
        return
      end

      local lines
      if obj.code ~= 0 then
        lines = { '（mermaid-ascii 渲染失败，保留源码）' }
      else
        lines = split_output(obj.stdout)
        if #lines == 0 then
          lines = { '（mermaid-ascii 没有输出）' }
        end
      end
      st.cache[key] = lines
      place(buf, block, lines)
    end)
  end)

  if not ok then
    st.pending[key] = nil
    notify('启动 mermaid-ascii 失败：' .. tostring(err), vim.log.levels.WARN)
  end
end

local function render(buf)
  if not is_markdown(buf) then
    return
  end

  local st = get_state(buf)
  clear(buf)
  st.generation = st.generation + 1
  local generation = st.generation
  local blocks = get_blocks(buf)
  if #blocks == 0 then
    return
  end

  local width = get_width(buf)
  for _, block in ipairs(blocks) do
    local key = vim.fn.sha256(block.text) .. ':' .. tostring(width)
    if st.cache[key] then
      place(buf, block, st.cache[key])
    elseif not SUPPORTED[block.first] then
      local name = UNSUPPORTED_HINT[block.first] or (block.first ~= '' and block.first or '该图类型')
      local lines = { ('（mermaid-ascii 暂不支持 %s，保留源码）'):format(name) }
      st.cache[key] = lines
      place(buf, block, lines)
    else
      request(buf, block, key, width, generation)
    end
  end
end

local function schedule_render(buf)
  if not is_markdown(buf) then
    return
  end
  local st = get_state(buf)
  cancel_timer(st)
  st.timer = vim.defer_fn(function()
    st.timer = nil
    render(buf)
  end, 400)
end

local function setup_commands()
  vim.api.nvim_create_user_command('MermaidRender', function()
    render(vim.api.nvim_get_current_buf())
  end, { desc = '渲染当前 Markdown 中的 Mermaid 代码块' })

  vim.api.nvim_create_user_command('MermaidClear', function()
    clear(vim.api.nvim_get_current_buf())
  end, { desc = '清除 Mermaid 文本图' })
end

local function setup_autocmds()
  local group = vim.api.nvim_create_augroup('dev_env_mermaid', { clear = true })

  vim.api.nvim_create_autocmd({ 'BufEnter', 'FileType' }, {
    group = group,
    callback = function(ev)
      if is_markdown(ev.buf) then
        schedule_render(ev.buf)
      end
    end,
  })

  vim.api.nvim_create_autocmd('TextChanged', {
    group = group,
    callback = function(ev)
      if is_markdown(ev.buf) then
        schedule_render(ev.buf)
      end
    end,
  })

  vim.api.nvim_create_autocmd('InsertEnter', {
    group = group,
    callback = function(ev)
      if is_markdown(ev.buf) then
        clear(ev.buf)
      end
    end,
  })

  vim.api.nvim_create_autocmd('InsertLeave', {
    group = group,
    callback = function(ev)
      if is_markdown(ev.buf) then
        schedule_render(ev.buf)
      end
    end,
  })

  vim.api.nvim_create_autocmd({ 'BufDelete', 'BufWipeout' }, {
    group = group,
    callback = function(ev)
      local st = state[ev.buf]
      cancel_timer(st)
      state[ev.buf] = nil
    end,
  })
end

setup_commands()
setup_autocmds()

vim.keymap.set('n', '<leader>mm', function()
  render(vim.api.nvim_get_current_buf())
end, { desc = '渲染 Mermaid 代码块' })

M.render = render
M.clear = clear

return M
