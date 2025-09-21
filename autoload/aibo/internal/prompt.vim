function! aibo#internal#prompt#init(prompt_bufnr) abort
  let l:console_bufnr = s:find_console_bufnr(a:prompt_bufnr)
  let l:aibo = getbufvar(l:console_bufnr, 'aibo', v:null)
  if l:aibo is# v:null
    throw '[aibo] b:aibo is not defined in the buffer ' .. bufname(l:console_bufnr)
  endif
  let b:aibo = l:aibo

  augroup aibo_autoload_aibo_internal_prompt_init
    autocmd! * <buffer>
    autocmd WinLeave <buffer> ++nested call s:WinLeave()
    autocmd BufWritePre <buffer> ++nested call s:BufWritePre()
    autocmd BufWriteCmd <buffer> ++nested call s:BufWriteCmd()
  augroup END

  setlocal nomodeline noswapfile nobackup nobuflisted
  setlocal buftype=acwrite bufhidden=hide
  setlocal winfixbuf winfixheight

  noremap <buffer><silent> <Plug>(aibo-submit) <Cmd>write<CR>
  noremap <buffer><silent> <Plug>(aibo-submit-close) <Cmd>wq<CR>
  noremap <buffer><silent> <Plug>(aibo-esc) <Cmd>call aibo#send("\e")<CR>

  noremap <buffer><silent> <Plug>(aibo-interrupt) <Cmd>call aibo#send("\<C-c>")<CR>
  noremap <buffer><silent> <Plug>(aibo-clear) <Cmd>call aibo#send("\<C-l>")<CR>
  noremap <buffer><silent> <Plug>(aibo-next) <Cmd>call aibo#send("\<C-n>")<CR>
  noremap <buffer><silent> <Plug>(aibo-prev) <Cmd>call aibo#send("\<C-p>")<CR>
  noremap <buffer><silent> <Plug>(aibo-down) <Cmd>call aibo#send("\<Down>")<CR>
  noremap <buffer><silent> <Plug>(aibo-up) <Cmd>call aibo#send("\<Up>")<CR>

  execute printf('setfiletype aibo-prompt.aibo-agent-%s', b:aibo.cmd)
endfunction

function! s:find_console_bufnr(bufnr) abort
  let l:bufname = bufname(a:bufnr)
  let l:winid = matchstr(l:bufname, '^aiboprompt://\zs\d\+$')
  if l:winid ==# ''
    throw printf('[aibo] Invalid aibo-prompt buffer "%s" (bufnr: %d)', l:bufname, a:bufnr)
  endif
  let l:bufnr = winbufnr(str2nr(l:winid))
  if l:bufnr == -1
    throw printf('[aibo] No console window found (winid: %d)', l:winid)
  endif
  return l:bufnr
endfunction

function! s:submit_content(bufnr) abort
  let l:content = getbufline(a:bufnr, 1, '$')->join("\n")
  call aibo#submit(l:content, a:bufnr)
  call deletebufline(a:bufnr, 1, '$')
  call setbufvar(a:bufnr, '&modified', 0)
  call setpos('.', [a:bufnr, 1, 1, 0])
endfunction

function! s:WinLeave() abort
  let l:winnr = winnr()
  execute printf('%dhide', l:winnr)
endfunction

function! s:BufWritePre() abort
  " BufWriteCmd won't be triggered if the buffer is not modified so force it
  " to be modified.
  setlocal modified
endfunction

function! s:BufWriteCmd() abort
  call s:submit_content(bufnr())
  setlocal nomodified
endfunction

augroup aibo_autoload_aibo_internal_prompt
  autocmd!
  autocmd QuitPre * ++nested call s:QuitPre()
augroup END

function! s:QuitPre() abort
  " Force all aibo-prompt buffers to be unmodified to avoid the prompt to save
  for l:bufinfo in getbufinfo(#{bufloaded: 1 })
    if getbufvar(l:bufinfo.bufnr, '&filetype') =~# '\<aibo-prompt\>'
      call setbufvar(l:bufinfo.bufnr, '&modified', 0)
    endif
  endfor
endfunction
