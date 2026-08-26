" after/syntax/zsh.vim
" There is no treesitter parser for zsh :-(

" Custom zsh commands defined in ~/.dotfiles/zsh/zsh.d/alias.zsh
syn keyword zshCommandsCustom zabbr
hi!      zshCommandsCustom   ctermfg=209 guifg=#ffff30
