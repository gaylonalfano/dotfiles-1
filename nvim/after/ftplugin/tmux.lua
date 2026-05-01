require("config.treesitter").ensure_parsers_installed("tmux")
require("config.treesitter").setup_highlight("tmux")

vim.opt_local.ts = 2
vim.opt_local.sts = 2
vim.opt_local.sw = 2

vim.opt_local.foldmethod = 'marker'
