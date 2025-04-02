-- Compatibility layer for vim lua APIs
-- Backport core lua APIs that does not exist in neovim 0.8.0 (from dev version)
-- see also
--   :HelpfulVersion
---@diagnostic disable: deprecated

local has = function(feature) return vim.fn.has(feature) > 0 end


-- for nvim < 0.10
if not has('nvim-0.10') and vim.lsp.get_clients == nil then
  vim.lsp.get_clients = vim.lsp.get_active_clients
end

-- for nvim >= 0.11, against deprecated warnings (until plugins catch up)
if has('nvim-0.11') then
  vim.tbl_islist = vim.islist
end
