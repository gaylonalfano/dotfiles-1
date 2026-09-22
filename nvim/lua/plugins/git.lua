-- Git-related plugins.
---@diagnostic disable: missing-fields

local Plug = require('utils.plug_utils').Plug

return {
  Plug 'tpope/vim-fugitive' {
    ft = { 'fugitiveblame', 'gitcommit', 'gitrebase' },
    event = {'CmdlineEnter'},   -- so many :G.. commands
    func = {'Fugitive*', 'fugitive#*'},
    config = require('config.git').setup_fugitive,
  };

  Plug 'rbong/vim-flog' {
    version = '>=3.0',
    init = require('config.git').setup_flog,
  };
  Plug 'junegunn/gv.vim' {
    cmd = 'GV',
    dependencies = 'tpope/vim-fugitive',
  };

  Plug 'lewis6991/gitsigns.nvim' {
    event = 'VeryLazy',
    config = require('config.git').setup_gitsigns,
    commit = '39b5b6f', -- v0.10.0-dev, not compatible with v0.9.0
  };

  Plug 'sindrets/diffview.nvim' {
    event = 'VeryLazy',
    config = require('config.git').setup_diffview,
  };
  -- fork from https://forge.barrettruth.com/barrettruth/diffs.nvim
  Plug 'wookayin/diffs.nvim' {
    init = require('config.git').init_diffs,
  };

  Plug 'rhysd/git-messenger.vim' {
    keys = '<leader>gm',
    config = require('config.git').setup_gitmessenger,
  };
}
