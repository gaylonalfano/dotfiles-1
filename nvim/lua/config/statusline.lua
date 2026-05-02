-- Statusline config: lualine.nvim

local M = {}

-- From nvim-lualine/lualine.nvim/wiki/Component-snippets
--- @param trunc_width number|nil trunctates component when screen width is less then trunc_width
--- @param trunc_len number|nil truncates component to trunc_len number of chars
--- @param hide_width number|nil hides component when window width is smaller then hide_width
--- @param trunc_right boolean whether to truncate at right (resulting in prefix) or left (resulting in suffix).
--- return function that can format the component accordingly
local function truncate(trunc_width, trunc_len, hide_width, trunc_right)
  return function(str)
    local win_width = vim.fn.winwidth(0)
    if hide_width and win_width < hide_width then return ''
    elseif trunc_width and trunc_len and win_width < trunc_width and #str > trunc_len then
      if not trunc_right then
        return str:sub(1, trunc_len) .. ('...')
      else
        return '...' .. str:sub(#str - trunc_len + 1, #str)
      end
    end
    return str
  end
end

local function using_global_statusline()
  return vim.opt.laststatus:get() == 3
end

local function min_statusline_width(width)
  return function()
    local statusline_width
    if using_global_statusline() then
      -- global statusline: editor width
      statusline_width = vim.opt.columns:get()
    else
      -- local statusline: window width
      statusline_width = vim.fn.winwidth(0)
    end
    return statusline_width > width
  end
end

local function min_window_with(width)
  return function()
    return vim.fn.winwidth(0) > width
  end
end

-- Customize statusline components
-- https://github.com/shadmansaleh/lualine.nvim#changing-components-in-lualine-sections
M.custom_components = {
  -- Override 'encoding': Don't display if encoding is UTF-8.
  encoding = function()
    local ret, _ = (vim.bo.fenc or vim.go.enc):gsub("^utf%-8$", "")  -- Note: '-' is a magic character
    return ret
  end,
  -- fileformat: Don't display if &ff is unix.
  fileformat = function()
    local ret, _ = vim.bo.fileformat:gsub("^unix$", "")
    return ret
  end,
  -- overseer.run job status
  overseer_status = function()
    return require('config.overseer').statusline()
  end,
  -- asyncrun job status (DEPRECATED in favor of overseer)
  asyncrun_status = function()
    local status = table.concat(vim.tbl_values(vim.tbl_map(function(job)
      return job and ({
        running = '⏳',
        success = '✅',
        failed = '❌',
      })[job.status] or ''
    end, vim.tbl_extend('keep',
      vim.g.asyncrun_job_status or {},
      { ['vimtex'] = _G.vimtex_jobs },
      {}
    ))))
    -- Display whether :AutoBuild is enabled
    if status == '' and require('config.commands.AutoBuild').is_enabled() then
      return require('config.commands.AutoBuild').icon or ''
    end
    return status
  end,

  -- copilot. see :Config lsp
  copilot_indicator = function()
    local has_copilot = #(vim.lsp.get_clients { bufnr = 0, name = 'copilot' }) > 0
    return has_copilot and '🤖' or ''
  end,

  -- git objects (fugitive, diffview) for human
  gitobject_bufname = (function()
    local hlgroup = function(name, val)
      vim.schedule(function() vim.api.nvim_set_hl(0, name, val) end)
      return '%#' .. name .. '#'
    end
    local git_icon = ' '
    local hl = {
      index = hlgroup('lualine_gitobject_index', { bg = '#117711', fg = 'white', bold = false }),
      commit = hlgroup('lualine_gitobject_commit', { bg = '#4dabf7', fg = 'black', bold = true }),
      undefined = hlgroup('lualine_gitobject_undefined', { bg = '#ff8787', fg = 'black', italic = false }),
    }

    return function()
      -- Extract git commit hash, or determine if it's the git index. Cache into b:git_info.
      vim.b.git_sha = vim.b.git_sha or (function(bufname)
        local sha ---@type string|nil
        if vim.startswith(bufname, 'fugitive://') or vim.startswith(bufname, 'diffview://') then
          sha = bufname:match([[.git%/%/?([0-9a-fA-F:]+)%/?]])
        elseif vim.startswith(bufname, 'gitsigns://') then
          sha = bufname:match([[.git%/:?([0-9a-fA-FH~]+):]]) -- .git/:0:<path>, .git/HEAD~:<path>
        end
        return sha
      end)(vim.api.nvim_buf_get_name(0))

      if vim.b.git_sha == '0' or vim.b.git_sha == ':0:' then
        return hl.index .. git_icon .. 'index'
      elseif type(vim.b.git_sha) == 'string' then
        local revname = require("config.git").name_revision(vim.b.git_sha)
        return (hl[revname or ''] or hl.commit) .. git_icon .. vim.b.git_sha:sub(1, 8) ..
          (revname and revname ~= "undefined" and string.format(' (%s)', revname) or '')
      end
      return ''
    end
  end)(),
  -- neotree path
  neotree_path = function()
    if vim.bo.filetype == 'neo-tree' then
      return require("config.neotree").get_path(0)
    end
    return ''
  end,
  -- LSP status, with some trim
  lsp_status = function()
    return _G.LspStatus()
  end,
  -- context (https://github.com/SmiteshP/nvim-navic)
  lsp_context = function()
    local txt = vim.F.npcall(function()
      local navic = require("nvim-navic")
      if navic.is_available() then
        return navic.get_location()
      end
    end) or ''
    return txt
  end
}


--- :help lualine-General-component-options & README.md ()
---@class (partial) lualine.ComponentOpts
---@field [1] string|function
---@field cond? function
---@field draw_empty? boolean
---@field color? string | { fg?: string|integer, bg?: string|integer, gui?: string }
---@field fmt? fun(name: string, context: table):string

---@alias lualine.Component lualine.ComponentOpts|string|function

function M.setup_lualine()
  require('lualine').setup {
    options = {
      globalstatus = true,  -- &laststatus == 3

      -- https://github.com/shadmansaleh/lualine.nvim/blob/master/THEMES.md
      theme = 'onedark'
    },
    -- see $VIMPLUG/lualine.nvim/lua/lualine/config.lua
    -- see $VIMPLUG/lualine.nvim/lua/lualine/components
    ---@type table<string, lualine.Component[]>
    sections = {
      lualine_a = {
        { 'mode', cond = min_statusline_width(40) },
      },
      lualine_b = {
        { 'branch', cond = min_statusline_width(120) },
        { M.custom_components.overseer_status },
        { M.custom_components.asyncrun_status },
      },
      lualine_c = {
        { M.custom_components.neotree_path, color = { fg = '#87afdf' } },
        { M.custom_components.copilot_indicator },
        { 'filename', path = 1, color = { fg = '#eeeeee' } },
        { M.custom_components.lsp_context, fmt = truncate(180, 60, 100, true) },
      },
      lualine_x = {
        --{ M.custom_components.lsp_status, fmt = truncate(120, 20, 60, false) },
        { M.custom_components.encoding,   color = { fg = '#d70000' } },
        { M.custom_components.fileformat, color = { fg = '#d70000' } },
        { 'filetype', cond = min_statusline_width(120) },
      },
      lualine_y = { -- excludes 'progress'
        { 'diff', cond = using_global_statusline },
        { 'diagnostics', cond = min_statusline_width(130) },
      },
      lualine_z = {
        { 'location', cond = min_statusline_width(190) },
      },
    },
    ---@type table<string, lualine.Component[]>
    inactive_sections = {
      lualine_a = {},
      lualine_b = {},
      lualine_c = {
        { 'filename', path = 1 }
      },
      lualine_x = {}, -- excludes 'location'
      lualine_y = {},
      lualine_z = {}
    },
  }
end

-- Now configure winbar, assuming laststatus = 3 (global statusline) is used.
function M.setup_winbar()
  vim.api.nvim_set_hl(0, 'lualine_winbar_filename', { fg = '#c92a2a', bg = '#eeeeee', bold = true })

  -- Define winbar using lualine components (see lualine.config.apply_configuration)
  local winbar_config = {
    ---@type table<string, lualine.Component[]>
    sections = {
      lualine_w = {
        { 'vim.fn.winnr()', color = 'TabLineSel' },
        { M.custom_components.gitobject_bufname },
        { 'filename', path = 1, color = 'lualine_winbar_filename',
          fmt = truncate(80, 20, nil, true) },
        'diagnostics',
        { M.custom_components.lsp_context, fmt = truncate(80, 20, 60, true) },
        function() return ' ' end,
      },
    },
    ---@type table<string, lualine.Component[]>
    inactive_sections = {
      lualine_w = {
        { 'vim.fn.winnr()', color = { fg = '#eeeeee' } },
        { M.custom_components.gitobject_bufname },
        { 'filename', path = 1,
          fmt = truncate(80, 20, nil, true) },
        'diagnostics',
        { M.custom_components.lsp_context, fmt = truncate(80, 20, 60, true) },
        function() return ' ' end,
      },
    },
    options = {
      -- component_separators = { left = '', right = ''},
      -- Component separators are stripped when background color is specified. Weird, so not using it :(
      component_separators = '',
    },
    tabline = {},
    extensions = {},
    -- For backward compatibility (broken due to new fields since 53aa3d82)
    winbar = {},
    inactive_winbar = {},
  }
  require 'lualine.utils.loader'.load_all(winbar_config)

  -- The custom winbar function.
  -- seealso $VIMPLUG/lualine.nvim/lua/lualine.lua, function statusline
  _G.winbarline = function()
    local is_focused = require 'lualine.utils.utils'.is_focused()
    local line = require 'lualine.utils.section'.draw_section(
      winbar_config[is_focused and 'sections' or 'inactive_sections'].lualine_w,
      'c', -- 'w' is undefined, so re-use highlight of lualine_c for lualine_w (winbar)
      is_focused
    )
    return line
  end

  vim.opt.winbar = "%{%v:lua.winbarline()%}"
  return true
end

function M.setup()
  M.setup_lualine()
  M.setup_winbar()

  -- Register colorscheme autocmd to recover statusline after colorscheme change
  vim.api.nvim_create_autocmd('Colorscheme', {
    pattern = '*',
    group = vim.api.nvim_create_augroup('Colorscheme_statusline', { clear = true }),
    callback = function()
      vim.schedule(M.setup)
    end,
  })
end

-- Resourcing support
if ... == nil then
  M.setup()
end

return M
