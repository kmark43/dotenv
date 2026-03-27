syntax on
filetype plugin indent on

set number
set ruler
set showcmd
set showmatch

set hlsearch
set incsearch
set ignorecase
set smartcase

set expandtab
set shiftwidth=2
set tabstop=2
set softtabstop=2
set autoindent

set backspace=indent,eol,start
set scrolloff=5
set wildmenu
set wildmode=longest:full,full

set noswapfile
set nobackup
set undofile
set undodir=~/.vim/undodir

" Strip trailing whitespace on save
autocmd BufWritePre * :%s/\s\+$//e
