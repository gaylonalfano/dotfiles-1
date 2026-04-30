-- :C, :Config [query]
-- Quickly open NVIM config files that are very commonly accessed

if not pcall(require, "plenary.path") then
  return
end
local Path = require "plenary.path"

local M = {}
local map = nil  -- computed lazily via build_directory_map

function M.build_directory_map()
  -- Static mappings
  ---@diagnostic disable-next-line: redefined-local
  local map = {
    ['vimrc'] = vim.fn.expand('$HOME/.vim/vimrc'),
    ['init.lua'] = vim.fn.expand('$DOTVIM/init.lua'),
  }
  local function _scan(glob_pattern, prefix)
    local files = vim.split(vim.fn.glob(glob_pattern), '\n')
    prefix = prefix or ''
    local basedir = vim.fn.expand(glob_pattern:match('^([^*?{]*/)', 1))
    for _, abspath in ipairs(files) do
      local relpath = abspath:sub(#basedir + 1)  -- path relative to basedir
      map[prefix .. relpath] = vim.fn.resolve(abspath)  -- resolve symlink
    end
  end
  -- Scan and add common config and plugin files
  _scan('~/.config/nvim/lua/config/*.lua')
  _scan('~/.config/nvim/lua/plugins/*.lua', 'plugins/')
  _scan('~/.config/nvim/after/ftplugin/*.lua', 'ftplugin/')
  _scan('~/.config/nvim/after/ftplugin/*.vim', 'ftplugin/')
  _scan('~/.config/nvim/after/queries/**/*.scm', 'queries/')
  _scan('~/.config/nvim/after/lsp/*.lua', 'lsp/')
  _scan('~/.config/nvim/colors/*.vim', 'colors/')
  return map
end

--- Sort by depth (number of '/' separators) and then lexicographically.
local function sort_by_depth_and_name(a, b)
  local d1 = select(2, string.gsub(a, '/', ''))
  local d2 = select(2, string.gsub(b, '/', ''))
  if d1 ~= d2 then return d1 < d2 end
  return a < b
end

---@diagnostic disable-next-line: unused-local
function M.completion(arglead, cmdline, cursorpos)
  map = map or M.build_directory_map()
  local t = vim.tbl_keys(map)
  table.sort(t, sort_by_depth_and_name)
  return t
end

function M.list_fzf()
  -- entries: display only key (--with-nth 1), preview and open value ({2})
  local entries = vim.iter(map):map(function(k, v) return k .. '\t' .. v end):totable()
  table.sort(entries, function(a, b)
    return sort_by_depth_and_name(a:match('^[^\t]*'), b:match('^[^\t]*'))
  end)
  require('fzf-lua').fzf_exec(entries, {
    fzf_opts = {
      ['--delimiter'] = '\t',
      ['--with-nth'] = '1',
      ['--prompt'] = 'NVIM Config> '
    },
    preview = 'bat --color=always {2}',
    actions = {
      ['default'] = function(selected)
        local path = selected[1]:match('\t(.+)$')
        vim.cmd('edit ' .. vim.fn.fnameescape(path))
      end,
    },
  })
end

--- @param arg string argument passed (may contain whitespace), i.e. :Config {argument}
function M.action(arg)
  map = map or M.build_directory_map()

  if arg == '' then
    -- Special case: without any argument, just show the directory map
    return M.list_fzf()
  end

  local aliases = {
    ['plug'] = 'plugins.lua',
    ['lazy'] = 'plugins.lua',
    ['ide'] = 'plugins/ide.lua',
    ['theme'] = 'colors/xoria256-wook.vim',
    ['color'] = 'colors/xoria256-wook.vim',
  }
  local file = map[arg] or map[arg .. '.lua'] or map[arg .. '.vim'] or map[aliases[arg]]
  if arg == 'ftplugin/' or arg == 'ftplugin' then
    file = ('~/.config/nvim/after/ftplugin/%s%s'):format(vim.bo.filetype,
      vim.bo.filetype ~= "" and ".lua" or "")
  end
  if arg == 'queries/' or arg == 'queries' then
    file = ('~/.config/nvim/after/queries/%s'):format(vim.bo.filetype)  -- actually, directory
  end

  if not file then
    return print("Invalid argument: " .. arg)
  end
  -- Open the file, but switch to the window if exists
  local bufpath = Path:new(file):make_relative(vim.fn.getcwd())
  local c
  if vim.api.nvim_buf_get_name(0) == "" then
    c = [[ edit $path ]]
  else
    c = [[
      try
        vertical sbuffer $path
      catch /E94/
        vsplit $path
      endtry
    ]]
  end
  vim.cmd(string.gsub(c, '%$(%w+)', { path = bufpath }))
end

-- Define commands upon sourcing
vim.api.nvim_create_user_command('Config',
  function(opts) M.action(vim.trim(opts.args)) end,
  {
    nargs = '?',
    complete = M.completion,
  })

vim.fn.CommandAlias('C', 'Config', 'register_cmd' and true)
vim.fn.CommandAlias('Ftplugin', 'Config ftplugin/<C-R>=&filetype<CR><C-R>=EatWhitespace()<CR>', { register_cmd = true })
vim.fn.CommandAlias('ftplugin', 'Config ftplugin/<C-R>=&filetype<CR><C-R>=EatWhitespace()<CR>', { register_cmd = false })
vim.fn.CommandAlias('TSQueries', 'Config queries/<C-R>=&filetype<CR>/<C-R>=EatWhitespace()<CR>', { register_cmd = true })

return M
