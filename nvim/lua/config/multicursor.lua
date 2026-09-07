local M = {}

function M.setup()
  -- Multicursor requires NVIM 0.13+
  if vim.fn.has('nvim-0.13') == 0 then
    return
  end

  -- Clears all the multicursors with `q<Esc>`1 or :MulticursorClear
  -- See :help mcursor-clear
  local multicursor_clear = function()
    local mc_ns = vim.api.nvim_create_namespace('nvim.multicursor')
    local buf = 0
    vim.api.nvim_buf_clear_namespace(buf, mc_ns, 0, -1)
  end

  vim.keymap.set('n', 'q<Esc>', multicursor_clear)

  vim.api.nvim_create_user_command('MulticursorClear', function()
    multicursor_clear()
  end, {
    nargs = 0,
    desc = 'Clear multicursor for the current buffer.',
  })
end

return M
