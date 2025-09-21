function! aibo#internal#console#open(cmd, args) abort
  silent execute 'terminal' a:cmd join(a:args, ' ')

  let l:bufnr = bufnr()
  let l:winid = win_getid()
  let b:aibo = #{
        \ cmd: a:cmd,
        \ args: a:args,
        \ controller: aibo#internal#controller#new(l:bufnr),
        \ follow: { -> s:follow(l:winid) },
        \}

  augroup aibo_autoload_aibo_internal_console_open
    autocmd! * <buffer>

    autocmd WinClosed <buffer> ++nested call s:WinClosed()
    autocmd TermEnter <buffer> ++nested call s:InsertEnter()
  augroup END

  noremap <buffer><silent> <Plug>(aibo-submit) <Cmd>call aibo#submit("")<CR>
  noremap <buffer><silent> <Plug>(aibo-esc) <Cmd>call aibo#send("\e")<CR>

  noremap <buffer><silent> <Plug>(aibo-interrupt) <Cmd>call aibo#send("\<C-c>")<CR>
  noremap <buffer><silent> <Plug>(aibo-clear) <Cmd>call aibo#send("\<C-l>")<CR>
  noremap <buffer><silent> <Plug>(aibo-next) <Cmd>call aibo#send("\<C-n>")<CR>
  noremap <buffer><silent> <Plug>(aibo-prev) <Cmd>call aibo#send("\<C-p>")<CR>
  noremap <buffer><silent> <Plug>(aibo-down) <Cmd>call aibo#send("\<Down>")<CR>
  noremap <buffer><silent> <Plug>(aibo-up) <Cmd>call aibo#send("\<Up>")<CR>

  execute printf('setfiletype aibo-console.aibo-agent-%s', a:cmd)
  stopinsert

  call s:follow(l:winid)
  call s:InsertEnter()
endfunction

function! s:follow(winid) abort
  call win_execute(a:winid, 'normal! G')
endfunction

function! s:format_prompt_bufname(winid) abort
  return printf('aiboprompt://%d', a:winid)
endfunction

function! s:WinClosed() abort
  let l:bufname = s:format_prompt_bufname(a:1)
  let l:bufnr = bufnr(l:bufname)
  if l:bufnr != -1
    call timer_start(0, { -> execute(printf('%dbwipeout!', l:bufnr)) })
  endif
endfunction

function! s:InsertEnter() abort
  let l:bufname = s:format_prompt_bufname(win_getid())
  let l:bufnr = bufnr(l:bufname)
  let l:winid = bufwinid(l:bufname)
  if l:winid is# -1
    " No prompt buffer exists for the window.
    execute printf(
          \ 'rightbelow %dsplit %s',
          \ g:aibo#internal#console#prompt_height,
          \ fnameescape(l:bufname),
          \)
  else
    " Focus the prompt window if it's already opened
    call win_gotoid(l:winid)
  endif
  " Enter insert mode
  call s:ensure_insert(bufnr())
endfunction

function! s:ensure_insert(bufnr) abort
  let l:is_empty = join(getbufline(a:bufnr, 1, '$'), "\n") ==# ''
  if l:is_empty
    call timer_start(0, { -> execute('startinsert') })
  else
    call timer_start(0, { -> execute('startinsert!') })
  endif 
endfunction

let g:aibo#internal#console#prompt_height = get(g:, 'aibo#internal#console#prompt_height', 10)
