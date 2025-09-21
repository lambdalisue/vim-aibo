function! aibo#send(data, ...) abort
  let l:aibo = call('s:get_aibo', a:000)
  call l:aibo.controller.send(a:data)
endfunction

function! aibo#submit(data, ...) abort
  let l:aibo = call('s:get_aibo', a:000)
  call l:aibo.controller.send(a:data)
  " We need to add a small delay so that AI agents can distinguish between
  " newline and submit.
  call timer_start(g:aibo#submit_delay, { -> l:aibo.controller.send(g:aibo#submit_key) })
  call timer_start(g:aibo#submit_delay, { -> l:aibo.follow() })
endfunction

function! s:get_aibo(...) abort
  let l:bufnr = a:0 ? a:1 : bufnr('%')
  let l:aibo = getbufvar(l:bufnr, 'aibo', v:null)
  if l:aibo is# v:null
    throw printf('[aibo] No b:aibo found in the buffer "%s"', bufname(l:bufnr))
  endif
  return l:aibo
endfunction

let g:aibo#submit_key = get(g:, 'aibo#submit_key', "\r")
let g:aibo#submit_delay = get(g:, 'aibo#submit_delay', 100)
