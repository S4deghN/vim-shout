vim9script

if exists("b:did_ftplugin")
    finish
endif

b:did_ftplugin = 1

# setl nocursorline
# setl cursorlineopt=both
setl bufhidden=hide
setl buftype=nofile
setl buflisted
setl noswapfile
setl noundofile
setl signcolumn=number
setl stl=%(%{%bufname()%}%):%(%{%get(b:,'shout_exit_code','')%}%):%(%{%get(t:,'shout_cmd','')%}%)%=\ \ \ \ %-8(%l,%c%)\ %P

b:undo_ftplugin = 'setlocal cursorline< cursorlineopt< bufhidden< buftype< buflisted< swapfile< undofile< signcolumn< stl<'
b:undo_ftplugin ..= '| exe "nunmap <buffer> <C-c>"'

# b:undo_ftplugin ..= '| exe "nunmap <buffer> <cr>"'
# b:undo_ftplugin ..= '| exe "nunmap <buffer> <C-c>"'
# b:undo_ftplugin ..= '| exe "nunmap <buffer> ]]"'
# b:undo_ftplugin ..= '| exe "nunmap <buffer> [["'
# b:undo_ftplugin ..= '| exe "nunmap <buffer> ]}"'
# b:undo_ftplugin ..= '| exe "nunmap <buffer> [{"'
# b:undo_ftplugin ..= '| exe "nunmap <buffer> gq"'

import autoload 'shout.vim'

nnoremap <buffer> <cr> <scriptcmd>shout.OpenFile()<cr>
nnoremap <buffer> <C-c> <scriptcmd>shout.Kill()<cr><C-c>
nnoremap <buffer> ]] <scriptcmd>shout.NextError()<cr>
nnoremap <buffer> [[ <scriptcmd>shout.PrevError()<cr>
nnoremap <buffer> [{ <scriptcmd>shout.FirstError()<cr>
nnoremap <buffer> ]} <scriptcmd>shout.LastError()<cr>
