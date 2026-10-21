-- Markdown 标题目录选择器。
--
-- 使用内置 markdown Tree-sitter parser 找 ATX 标题（# / ## / ...），
-- 再用 fzf-lua 选择并跳转；不需要额外插件。
local M = {}

function M.get_headings(buf)
  local ok, parser = pcall(vim.treesitter.get_parser, buf, 'markdown')
  if not ok then
    return {}
  end

  local parsed = parser:parse(true)
  local root = parsed and parsed[1] and parsed[1]:root()
  if not root then
    return {}
  end

  local ok_query, query = pcall(
    vim.treesitter.query.parse,
    'markdown',
    '((atx_heading) @heading)'
  )
  if not ok_query then
    return {}
  end

  local items = {}
  for _, node in query:iter_captures(root, buf, 0, -1) do
    local text = vim.treesitter.get_node_text(node, buf)
    local stripped = text:gsub('^%s*', '')
    local level = #(stripped:match('^(#+)') or '')
    local title = stripped:gsub('^#+%s*', ''):gsub('%s*#*%s*$', '')

    if level > 0 then
      items[#items + 1] = {
        lnum = node:start() + 1,
        level = level,
        title = title,
        label = string.rep('  ', level - 1) .. title,
      }
    end
  end

  return items
end

local function jump(item)
  if item and item.lnum then
    vim.api.nvim_win_set_cursor(0, { item.lnum, 0 })
  end
end

function M.pick()
  local items = M.get_headings(0)
  if #items == 0 then
    vim.notify('当前文件没有 Markdown ATX 标题', vim.log.levels.INFO)
    return
  end

  local ok_fzf, fzf = pcall(require, 'fzf-lua')
  if not ok_fzf then
    vim.ui.select(items, {
      prompt = 'Markdown headings: ',
      format_item = function(item)
        return item.label
      end,
    }, jump)
    return
  end

  local lines = vim.tbl_map(function(item)
    return string.format('%d: %s', item.lnum, item.label)
  end, items)

  fzf.fzf_exec(lines, {
    prompt = 'Markdown headings> ',
    actions = {
      default = function(selected)
        if not selected or not selected[1] then
          return
        end
        local lnum = tonumber(selected[1]:match('^(%d+):'))
        if lnum then
          vim.api.nvim_win_set_cursor(0, { lnum, 0 })
        end
      end,
    },
  })
end

return M
