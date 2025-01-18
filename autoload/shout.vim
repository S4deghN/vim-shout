vim9script

const W_THRESHOLD = 160
var bufname = '[shout]'
var alt_filetype = ''

# Define global variables
var shout_job: job
var initial_winid = 0

var bufnr = -1
var follow = 1

var shout_count = 0


def Vertical(): string
    var result = ""
    # if the overall vim width is too narrow or
    # there are >=2 vertical windows, split below
    if &columns >= W_THRESHOLD && winlayout()[0] != 'row'
        result ..= "vertical"
    endif
    return result
enddef

def FindOtherWin(): number
    var result = -1
    var winid = win_getid()
    for wnd in range(1, winnr('$'))
        if win_getid(wnd) != winid
            result = win_getid(wnd)
            break
        endif
    endfor
    return result
enddef

def ShoutWinId(): number
    var buffers = getbufinfo()->filter((_, v) => fnamemodify(v.name, ":t") =~ '^\[shout\]$')
    for shbuf in buffers
        if len(shbuf.windows) > 0
            return shbuf.windows[0]
        endif
    endfor
    return -1
enddef

export def GetShoutBufnr(): number
    var buffers = getbufinfo()->filter((_, v) => fnamemodify(v.name, ":t") == bufname)
    if len(buffers) > 0
        return buffers[0].bufnr
    else
        return -1
    endif
enddef

def UseSplitOrCreate(): number
    var current_win_pos = win_screenpos(0)
    var winnr = winnr()

    if &columns > 160
        if winnr != winnr('1l')
            return win_getid(winnr('1l'))
        elseif winnr != winnr('1h')
            return win_getid(winnr('1h'))
        else
            :botright vsplit
            :wincmd p
            return win_getid(winnr('#'))
        endif
    else
        if winnr != winnr('1j')
            return win_getid(winnr('1j'))
        elseif winnr != winnr('1k')
            return win_getid(winnr('1k'))
        else
            :botright split
            :wincmd p
            return win_getid(winnr('#'))
        endif
    endif
enddef

def PrepareBuffer(shell_cwd: string): number
    initial_winid = win_getid()

    bufnr = GetShoutBufnr()
    var windows = win_findbuf(bufnr)

    var shout_window_exist = len(windows)
    if shout_window_exist
        win_gotoid(windows[0])
    else
        var winid = UseSplitOrCreate()
        win_gotoid(winid)
        if bufnr < 0
            bufnr = bufadd(bufname)
        endif
        exec "buffer " .. bufnr
        setl filetype=shout
    endif

    silent :%d _
    # or. because a buftype=nofile is emptied with this command
    # but it causes weird syntax highlihgt bug!
    #:e

    b:shout_cwd = shell_cwd
    exe 'silent lcd' shell_cwd

    setl undolevels=-1

    return bufnr
enddef

export def CaptureOutput(command: string, ...args: list<string>)
    # Optionaly set file name and filetype
    bufname = get(args, 0, '[shout]')
    alt_filetype = get(args, 1, '')

    var cwd = getcwd()
    bufnr = PrepareBuffer(cwd->substitute('#', '\\&', 'g'))

    setbufvar(bufnr, "shout_exit_code", "")

    setbufline(bufnr, 1, "$ " .. command)
    appendbufline(bufnr, "$", "")

    if job_status(shout_job) == "run"
        job_stop(shout_job)
    endif

    var job_command = has('win32') ? command : [&shell, &shellcmdflag, escape(command, '\')]

    shout_job = job_start(job_command, {
        cwd: cwd,
        pty: 1,
        # in_io: 'buffer',
        # in_buf: bufnr,
        out_io: 'buffer',
        out_buf: bufnr,
        out_msg: 0,
        err_io: 'buffer',
        err_buf: bufnr,
        err_msg: 0,
        close_cb: (channel) => {
            if !bufexists(bufnr) | return | endif

            var winid = bufwinid(bufnr)
            var exit_code = job_info(shout_job).exitval

            if exit_code == 0 && len(alt_filetype) > 0
                win_execute(winid, "setl filetype=" .. alt_filetype .. " buftype=nofile buflisted")
                win_execute(winid, "nnoremap <buffer> <CR> :OpenFile<CR>")
            else
                if &filetype != 'shout'
                    win_execute(winid, "setl filetype=shout")
                endif

                if get(g:, "shout_print_exit_code", 1)
                    appendbufline(bufnr, line('$', winid), "")
                    appendbufline(bufnr, line('$', winid), "Exit code: " .. exit_code)
                endif
                setbufvar(bufnr, "shout_exit_code", string(exit_code))
            endif

            # if follow
            #     win_execute(winid, "normal! G")
            # endif

            win_execute(winid, "setl undolevels&")
        }
    })

    t:shout_cmd = command

    if follow
        normal! G
    endif

    win_gotoid(initial_winid)
enddef

sign define ShoutArrow text==> texthl=Normal

if !prop_type_get('arrow')
    prop_type_add('arrow', {highlight: 'Comment'})
endif

var pr = 0
def SignJumpLine()
    sign_unplace('Shout', {'id': 1, 'buffer': bufnr()})
    sign_place(1, 'Shout', 'ShoutArrow', bufnr(), {'lnum': line('.')})
    # if !!get(b:, 'match') | silent! matchdelete(b:match) | endif
    # b:match = matchaddpos('Visual', [[line('.'), 1, 3]])
    # if !!pr
    #     prop_remove({id: pr})
    # endif
    # pr = prop_add(line('.'), 1, {type: 'arrow', text: '=>'})
enddef

export def OpenFile()
    var shout_cwd = get(b:, "shout_cwd", "")
    if !empty(shout_cwd)
        exe "silent lcd" b:shout_cwd
    endif

    # re-run the command if on line 1
    if line('.') == 1
        var cmd = getline(".")->matchstr('^\$ \zs.*$')
        if cmd !~ '^\s*$'
            var pos = getcurpos()
            CaptureOutput(cmd, bufname, alt_filetype)
            setpos('.', pos)
        endif
        return
    endif

    # Windows has : in `isfname` thus for ./filename:20:10: gf can't find filename cause
    # it sees filename:20:10: instead of just filename
    # So the "hack" would be:
    # - take <cWORD> or a line under cursor
    # - extract file name, line, column
    # - edit file name

    # python
    var fname = getline('.')->matchlist('^\s\+File "\(.\{-}\)", line \(\d\+\)')

    # erlang escript
    if empty(fname)
        fname = getline('.')->matchlist('^\s\+in function\s\+.\{-}(\(.\{-}\), line \(\d\+\))')
    endif

    # rust
    if empty(fname)
        fname = getline('.')->matchlist('^\s\+--> \(.\{-}\):\(\d\+\):\(\d\+\)')
    endif

    # regular filename:linenr:colnr:
    if empty(fname)
        fname = getline('.')->matchlist('^\(.\{-}\):\(\d\+\):\(\d\+\).*')
    endif

    # regular filename:linenr:
    if empty(fname)
        fname = getline('.')->matchlist('^\(.\{-}\):\(\d\+\):\?.*')
    endif

    # regular filename:
    if empty(fname)
        fname = getline('.')->matchlist('^\(.\{-}\):.*')
    endif

    if fname->len() > 0 && filereadable(fname[1])
        SignJumpLine()
        try
            var should_split = 0
            var buffers = filter(getbufinfo(), (idx, v) => fnamemodify(fname[1], ":p") == v.name)
            fname[1] = substitute(fname[1], '#', '\&', 'g')

            # goto opened file if it is visible
            if len(buffers) > 0
                if len(buffers[0].windows) > 0
                    win_gotoid(buffers[0].windows[0])
                else
                    win_gotoid(UseSplitOrCreate())
                    execute "buffer" fname[1]
                endif
            else
                win_gotoid(UseSplitOrCreate())
                execute "edit" fname[1]
            endif

            if !empty(fname[2])
                execute ":" .. fname[2]
                execute "normal! 0"
            endif

            if !empty(fname[3]) && str2nr(fname[3]) > 1
                execute "normal! " .. (str2nr(fname[3])) .. "|"
            endif
            normal! zz
        catch
        endtry
    endif
enddef

export def Kill()
    if shout_job != null
        job_stop(shout_job)
    endif
enddef

export def OpenWindow(): number
    bufnr = GetShoutBufnr()
    if bufnr < 0
        bufnr = bufadd(bufname)
    endif

    var windows = win_findbuf(bufnr)
    initial_winid = win_getid()

    # TODO: instead of this hack of jumping back find a ways to open the window without jumping to it.
    if len(windows) == 0
        exe 'botright ' .. Vertical() .. ' sbuffer' bufnr
        setl filetype=shout
        var ret = win_getid()
        win_gotoid(initial_winid)
        return ret
    else
        return windows[0]
    endif
enddef

export def ToggleWindow()
    var winid = ShoutWinId()
    if winid == -1
        OpenWindow()
    else
        var winnr = getwininfo(winid)[0].winnr
        exe $":{winnr}close"
    endif
enddef

export def ShoutToQf()
    bufnr = GetShoutBufnr()
    if bufnr > 0
        cgetexpr getbufline(bufnr, 1, "$")
    endif
enddef

export def NextError()
    # Search for python error
    var rxError = '^.\{-}:\d\+\(:\d\+:\?\)\?'
    var rxPyError = '^\s*File ".\{-}", line \d\+,'
    var rxErlEscriptError = '^\s\+in function\s\+.\{-}(.\{-}, line \d\+)'
    search($'\({rxError}\)\|\({rxPyError}\)\|\({rxErlEscriptError}\)', 'W')
enddef

export def FirstError()
    :2
    NextError()
enddef

export def PrevError(accept_at_curpos: bool = false)
    var rxError = '^.\{-}:\d\+\(:\d\+:\?\)\?'
    var rxPyError = '^\s*File ".\{-}", line \d\+,'
    var rxErlEscriptError = '^\s\+in function\s\+.\{-}(.\{-}, line \d\+)'
    search($'\({rxError}\)\|\({rxPyError}\)\|\({rxErlEscriptError}\)', 'bW')
enddef

export def LastError()
    :$
    if getline('$') =~ "^Exit code: .*$"
        PrevError()
    else
        PrevError(true)
    endif
enddef

export def NextErrorJump()
    if win_gotoid(ShoutWinId())
       :exe "normal ]]\<CR>"
    endif
enddef

export def FirstErrorJump()
    if win_gotoid(ShoutWinId())
       :exe "normal [{\<CR>"
    endif
enddef

export def PrevErrorJump()
    if win_gotoid(ShoutWinId())
       :exe "normal [[\<CR>"
    endif
enddef

export def LastErrorJump()
    if win_gotoid(ShoutWinId())
       :exe "normal ]}\<CR>"
    endif
enddef

export def ThisErrorJump()
    if win_gotoid(ShoutWinId())
        :exe "normal \<CR>"
    endif
enddef

defc
