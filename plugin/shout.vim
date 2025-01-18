vim9script

if exists('g:loaded_shout')
    finish
endif
g:loaded_shout = 1

import autoload 'shout.vim'

command! -nargs=1 -complete=shellcmdline Sh shout.CaptureOutput(<f-args>)
command! -nargs=0 -bar ShoutToggle    shout.ToggleWindow()
command! -nargs=0 -bar ShoutToQf      shout.ShoutToQf()
command! -nargs=0 -bar OpenFile       shout.OpenFile()
command! -nargs=0 -bar Kill           shout.Kill()
command! -nargs=0 -bar NextError      shout.NextError()
command! -nargs=0 -bar FirstError     shout.FirstError()
command! -nargs=0 -bar PrevError      shout.PrevError()
command! -nargs=0 -bar LastError      shout.LastError()
command! -nargs=0 -bar NextErrorJump  shout.NextErrorJump()
command! -nargs=0 -bar FirstErrorJump shout.FirstErrorJump()
command! -nargs=0 -bar PrevErrorJump  shout.PrevErrorJump()
command! -nargs=0 -bar LastErrorJump  shout.LastErrorJump()
command! -nargs=0 -bar ThisErrorJump  shout.ThisErrorJump()
