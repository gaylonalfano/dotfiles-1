runtime autoload/plug_addon.vim

let s:darwin = has('mac')

" Plug buffers appear in a new tab
let g:plug_window = '-tabnew'

" for neovim plugins (rplugin)
if has('nvim')
  function! UpdateRemote(arg)
    if has_key(g:, 'did_plug_UpdateRemote') | return | endif
    let g:did_plug_UpdateDoRemote = 1
    UpdateRemotePlugins
  endfunction
endif

let s:_python3_version = ''
function! s:python3_version()
  if has('nvim')           | return g:python3_host_version
  elseif has('python3')
    if empty(s:_python3_version)
      let s:_python3_version = join(py3eval('sys.version_info'), ".")
    endif
    return s:_python3_version
  else | return ''
  endif
endfunction

" Detect (neo)vim features
let s:floating_available = exists('*nvim_open_win') &&
      \ (exists('##MenuPopupChanged') || exists('##CompleteChanged'))

" An utility to tell whether a plugin is configured.
function! HasPlug(name) abort
  return has_key(g:plugs, a:name)
endfunction

"==============================================
call plug#begin('~/.vim/plugged')
"==============================================

" General Plugins
" -------------------------------------
Plug 'flazz/vim-colorschemes'
Plug 'embear/vim-localvimrc', PlugCond(has('patch-7.4.1154'))  " requires v:false
Plug 'tweekmonster/helpful.vim', { 'on' : ['HelpfulVersion'] }

" Vim Interfaces
" -------------------------------------
Plug 'vim-airline/vim-airline'
Plug 'vim-airline/vim-airline-themes'

Plug 'junegunn/fzf', { 'dir': '~/.fzf', 'do': './install --all --no-update-rc' }
Plug 'junegunn/fzf.vim'
Plug 'wookayin/fzf-ripgrep.vim'
if has('nvim-0.4.0')
  Plug 'liuchengxu/vim-clap'   " Deprecated
  Plug 'voldikss/vim-floaterm'
endif
if has('nvim-0.4.0') || has('popup')
  Plug 'skywind3000/vim-quickui'
endif
Plug 'mg979/vim-xtabline'
Plug 'ervandew/supertab'
Plug 'scrooloose/nerdtree'
Plug 'jistr/vim-nerdtree-tabs'
Plug 'Xuyuanp/nerdtree-git-plugin'
Plug 'vim-voom/VOoM', { 'on' : ['Voom', 'VoomToggle'] }
Plug 'tpope/vim-dispatch', { 'tag' : 'v1.1' }
if has('nvim') || v:version >= 800
  Plug 'neomake/neomake'
endif
if has('nvim-0.4.0')
  Plug 'gelguy/wilder.nvim', { 'do': function('UpdateRemote') }
endif
Plug 'tpope/vim-tbone'
Plug 'szw/vim-maximizer'    " zoom and unzoom!
Plug 'junegunn/goyo.vim'
Plug 'christoomey/vim-tmux-navigator'
if !has('nvim')
  " focus-events work by default in Neovim (see issue #1), so
  " this plugin is not needed for neovim. Don't reserve <F24>
  Plug 'tmux-plugins/vim-tmux-focus-events'
        \ | ForcePlugURI 'vim-tmux-focus-events'
endif
Plug 'tpope/vim-fugitive'
Plug 'junegunn/gv.vim'
Plug 'airblade/vim-gitgutter'
if has('nvim-0.4.0') && exists('*nvim_open_win')
  " git blame with floating window (requires nvim 0.4.0+)
  Plug 'rhysd/git-messenger.vim'
endif
Plug 'majutsushi/tagbar'
Plug 'rking/ag.vim'
Plug 'kshenoy/vim-signature'
Plug 'junegunn/vim-easy-align'
if has('nvim-0.5.0')
  Plug 'lukas-reineke/indent-blankline.nvim'
else
  Plug 'Yggdroot/indentLine'
endif
if exists('##WinScrolled')  " neovim nightly (0.5.0+)
  Plug 'dstein64/nvim-scrollview'
endif

" Miscellanious Utilities
" -------------------------------------
Plug 'junegunn/vim-emoji'
Plug 'cocopon/colorswatch.vim', { 'on' : ['ColorSwatchGenerate'] }
Plug 'tpope/vim-surround'
Plug 'tpope/vim-repeat'
Plug 'Lokaltog/vim-easymotion'
Plug 'unblevable/quick-scope'
Plug 'haya14busa/vim-asterisk'
Plug 'haya14busa/incsearch.vim'
Plug 'haya14busa/incsearch-fuzzy.vim'
Plug 't9md/vim-quickhl'
if executable('diff') && has('patch-7.4.1685')
  Plug 'machakann/vim-highlightedundo'
endif

if v:version >= 800 || v:version == 704 && has('patch786')
  " requires vim 7.4.786+ (see issue #23)
  Plug 'machakann/vim-highlightedyank'
endif

Plug 'scrooloose/nerdcommenter'
Plug 'junegunn/vim-peekaboo'
Plug 'sjl/gundo.vim'
if has('python3') && s:python3_version() >= '3.5'
  Plug 'SirVer/ultisnips'
endif
Plug 'vim-scripts/matchit.zip'
Plug 'tomtom/tlib_vim'
Plug 'junegunn/vader.vim'
Plug 'MarcWeber/vim-addon-mw-utils'
Plug 'tpope/vim-eunuch'
Plug 'rizzatti/dash.vim',   { 'on': 'Dash' }
Plug 'wookayin/vim-typora', { 'on': 'Typora' }
Plug 'liuchengxu/vim-which-key', { 'on': ['WhichKey', 'WhichKey!'] }

if has('nvim-0.5.0')
  " Some lua-powered plugins for neovim 0.5.0+
  Plug 'kyazdani42/nvim-tree.lua'
  Plug 'nvim-lua/plenary.nvim'
  Plug 'nvim-telescope/telescope.nvim'
  if s:darwin
    Plug 'nvim-telescope/telescope-frecency.nvim'
    Plug 'tami5/sql.nvim'    " required for telescope-frecency
  endif
endif

" Syntax, Completion, Language Servers, etc.
" ------------------------------------------
Plug 'editorconfig/editorconfig-vim'

Plug 'sheerun/vim-polyglot', {'tag': 'v4.2.1'}   " conflicts with vimtex (see polyglot#484)
Plug 'tmux-plugins/vim-tmux'

Plug 'klen/python-mode', { 'branch': 'develop' } |
      \ Plug 'wookayin/vim-python-enhanced-syntax'
if has('nvim') && s:python3_version() >= '3.5'
  Plug 'numirias/semshi', { 'do': function('UpdateRemote') }
  Plug 'stsewd/isort.nvim', { 'do': function('UpdateRemote') }
endif
if has('python3') && s:python3_version() >= '3.5'
  Plug 'wookayin/vim-autoimport'
endif

Plug 'artur-shaik/vim-javacomplete2'

Plug 'vim-pandoc/vim-pandoc'
Plug 'vim-pandoc/vim-pandoc-syntax'
"Plug 'LaTeX-Box-Team/LaTeX-Box'
Plug 'lervag/vimtex', { 'for' : ['tex', 'plaintex'] }
Plug 'machakann/vim-Verdin', { 'for': ['vim'] }   " vimscript omnifunc
Plug 'gisraptor/vim-lilypond-integrator'
Plug 'tfnico/vim-gradle'
Plug 'Tyilo/applescript.vim'
Plug 'rdolgushin/groovy.vim'

Plug 'xolox/vim-misc'
Plug 'xolox/vim-lua-ftplugin', { 'for' : ['lua'] }

" [Completion Engine or LSP backend]
" We have a long history and I want to make completion work for legacy and
" older vim as well. Choose the completion or LSP engine in the order of
" preferred and up-to-date technology with a fallback manner.
" (Read g:dotfiles_completion_backend to see which one has been chosen)
function! s:choose_completion_backend()
  " 1. Neovim 0.5.0+: built-in LSP
  if has('nvim-0.5.0')
    return '@lsp'
  endif

  " 2. Neovim 0.3.1+ or vim 8.0+: coc.nvim
  "   (i) Proper neovim/vim8 version and python3
  "   (ii) 'node' and 'npm' are installed
  "   (iii) Directory ~/.config/coc exists (opt-in)
  if (has('nvim-0.3.1') || v:version >= 800) &&
        \ executable('npm') && executable('python3') &&
        \ isdirectory(expand("\~/.config/coc/"))
    " Check minimum node version
    let node_version = system('node --version')
    if !plug_addon#version_lessthan(node_version, 'v8.10')
      return '@coc'
    else
      autocmd VimEnter * echohl WarningMsg | echom
            \ 'WARNING: Node v8.10.0+ is required for coc.nvim. '
            \ . '(Try: dotfiles install node)' | echohl None
    endif
  endif

  " (At this point, apparently we are maybe using legacy (neo)vim. Warn users!)
  if has('nvim') && !has('nvim-0.3.1')
    autocmd VimEnter * echohl WarningMsg | echom
          \ 'WARNING: Neovim 0.3.1+ or Vim 8.0+ is required for coc.nvim. '
          \ . '(Try: dotfiles install neovim)' | echohl None
    return
  endif

  " 3. Legacy Neovim: Deoplete
  if has('nvim') && s:python3_version() >= '3.6.1'
    return '@deoplete'
  endif

  " No completion available :(
  return ''
endfunction
let g:dotfiles_completion_backend = s:choose_completion_backend()

" Asynchronous Lint Engine (ALE): seems orthogonal to backend
if has('nvim') || v:version >= 800
  Plug 'w0rp/ale'
endif

" 1. [Neovim 0.5.0 LSP]
" See also for more config: ~/.config/nvim/lua/config/lsp.lua
if g:dotfiles_completion_backend == '@lsp'
  Plug 'neovim/nvim-lspconfig'
  Plug 'williamboman/nvim-lsp-installer'
  Plug 'hrsh7th/nvim-compe'
  Plug 'ray-x/lsp_signature.nvim'
  Plug 'nvim-lua/lsp-status.nvim'
  Plug 'folke/trouble.nvim'
  Plug 'kyazdani42/nvim-web-devicons'

  UnPlug 'ervandew/supertab'   " Custom <TAB> mapping for coc.nvim supercedes supertab
  UnPlug 'w0rp/ale'            " Disable ALE for now (TODO: we might still need it for LSP-lacking filetypes)
endif

" 2. [coc.nvim]
if g:dotfiles_completion_backend == '@coc'
  Plug 'neoclide/coc.nvim', {'branch': 'release'}
  Plug 'neoclide/jsonc.vim'
  if has('nvim-0.4.0')
    Plug 'antoinemadec/coc-fzf'
  endif

  " coc supercedes deoplete and supertab
  UnPlug 'ervandew/supertab'   " Custom <TAB> mapping for coc.nvim supercedes supertab

  if s:floating_available
    " disable vim-which-key if floating windows are used (have some conflicts)
    UnPlug 'liuchengxu/vim-which-key'
  endif

  " automatically install CocExtensions by default
  let g:coc_global_extensions = [
        \ 'coc-json', 'coc-highlight', 'coc-snippets', 'coc-explorer',
        \ 'coc-python', 'coc-vimlsp', 'coc-texlab'
        \ ]

  UnPlug 'kyazdani42/nvim-tree.lua'   " use coc-explorer
endif

" 3. [Legacy neovim: deoplete]
if g:dotfiles_completion_backend == '@deoplete'
  Plug 'Shougo/deoplete.nvim', { 'do': function('UpdateRemote') }
  Plug 'zchee/deoplete-jedi'    " Python
  Plug 'zchee/deoplete-clang'   " C/C++
  Plug 'zchee/deoplete-zsh', { 'for': ['zsh'] }     " zsh
endif

if g:dotfiles_completion_backend == '' || g:dotfiles_completion_backend == '@deoplete'
  " Use jedi-vim, only if we are not using coc.nvim or LSP.
  Plug 'davidhalter/jedi-vim'
endif

if g:dotfiles_completion_backend == '' || g:dotfiles_completion_backend == '@deoplete'
  " echodoc: not needed for coc.nvim and nvim-lsp
  if has('nvim')
    Plug 'Shougo/echodoc.vim'
  endif
endif


" =======================================================
" Additional, optional local plugins
" =======================================================
if filereadable(expand("\~/.vim/plugins.local.vim"))
  source \~/.vim/plugins.local.vim
endif

call plug#end()

delcom UnPlug
delcom ForcePlugURI
silent delfunction PlugCond

" vim: set ts=2 sts=2 sw=2:
