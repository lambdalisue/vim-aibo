function! aibo#internal#controller#new(bufnr) abort
  let l:chan = getbufvar(a:bufnr, 'terminal_job_id', v:null)
  if l:chan is v:null
    throw printf('[aibo] Failed to create controller of the buffer (bufnr: %d): terminal channel is not found', a:bufnr)
  endif
  let l:controller = #{ send: { data -> chansend(l:chan, data) } }
  return l:controller
endfunction
