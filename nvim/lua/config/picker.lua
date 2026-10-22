-- fzf-lua picker：找文件、全局搜索、buffer、最近文件。
--
-- 外部依赖：
--   fzf  交互式模糊查找 UI（必须）
--   rg   全局搜索（强烈建议）
--   fd   文件列举（可选；fzf-lua 会自行 fallback）
local M = {}

if vim.fn.executable('fzf') ~= 1 then
  vim.schedule(function()
    vim.notify('dev_env: 找不到 fzf，picker 键位未启用', vim.log.levels.WARN)
  end)
  return M
end

local ok, fzf = pcall(require, 'fzf-lua')
if not ok then
  vim.schedule(function()
    vim.notify('dev_env: fzf-lua 未安装，请运行 nvim/scripts/install-plugins.sh', vim.log.levels.WARN)
  end)
  return M
end

fzf.setup({
  grep = {
    -- 在 live_grep 提示符里可以输入：query -- glob1 glob2
    -- 例如：foo -- *.lua '!vendor/*'
    rg_glob = true,
  },
  keymap = {
    fzf = {
      ['ctrl-j'] = 'down',
      ['ctrl-k'] = 'up',
      ['ctrl-n'] = 'down',
      ['ctrl-p'] = 'up',
      ['up'] = 'up',
      ['down'] = 'down',
    },
  },
})

local function buffers()
  fzf.buffers({
    fzf_opts = {
      ['--header'] = 'C-j/C-k or Up/Down: move   Enter: open   Esc: cancel',
    },
  })
end

vim.keymap.set('n', '<leader>ff', fzf.files, { desc = '查找文件' })
vim.keymap.set('n', '<leader>fg', fzf.live_grep, { desc = '全局搜索' })
vim.keymap.set('n', '<leader>fc', fzf.lgrep_curbuf, { desc = '当前 buffer 搜索' })
vim.keymap.set('n', '<leader>fw', fzf.grep_cword, { desc = '搜索光标下单词' })
vim.keymap.set('v', '<leader>fv', fzf.grep_visual, { desc = '搜索选中文本' })
vim.keymap.set('n', '<leader>bs', buffers, { desc = '切换 buffer' })
vim.keymap.set('n', '<leader>fr', fzf.oldfiles, { desc = '最近文件' })

-- 指定路径 + 文件 glob 的搜索；glob 以 ! 开头表示排除。
local function scoped_grep()
  vim.ui.input({
    prompt = '搜索路径（目录或文件）: ',
    default = vim.fn.getcwd(),
  }, function(path)
    if not path or path == '' then
      return
    end

    vim.ui.input({
      prompt = '文件 glob（空格分隔；! 开头排除，可留空）: ',
    }, function(glob_input)
      if glob_input == nil then
        return
      end

      local opts = {
        search_paths = { vim.fn.expand(path) },
      }

      local globs = vim.split(glob_input, '%s+', { trimempty = true })
      if #globs > 0 then
        local rg_opts = {
          '--column',
          '--line-number',
          '--no-heading',
          '--color=always',
          '--smart-case',
          '--max-columns=4096',
        }
        for _, glob in ipairs(globs) do
          rg_opts[#rg_opts + 1] = '--glob'
          rg_opts[#rg_opts + 1] = vim.fn.shellescape(glob)
        end
        rg_opts[#rg_opts + 1] = '-e'
        opts.rg_opts = table.concat(rg_opts, ' ')
      end

      fzf.live_grep(opts)
    end)
  end)
end

vim.keymap.set('n', '<leader>fs', scoped_grep, { desc = '按路径和 glob 搜索' })

M.scoped_grep = scoped_grep

return M
