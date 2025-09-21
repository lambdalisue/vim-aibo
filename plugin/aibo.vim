if exists('g:loaded_aibo')
  finish
endif
let g:loaded_aibo = 1

augroup aibo_plugin
  autocmd!
  autocmd BufReadCmd aiboprompt://* ++nested call aibo#internal#prompt#init(str2nr(expand('<abuf>')))
augroup END

function! s:aibo(args) abort
  let l:cmd = a:args[0]
  let l:args = a:args[1:]
  call aibo#internal#console#open(l:cmd, l:args)
endfunction

command! -nargs=+ Aibo call s:aibo([<f-args>])
