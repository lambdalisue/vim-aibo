if exists('b:did_ftplugin_aibo_prompt')
  finish
endif
let b:did_ftplugin_aibo_prompt = 1

setlocal nonumber norelativenumber signcolumn=no

nnoremap <buffer> <CR> <Plug>(aibo-submit)
nnoremap <buffer> <Esc> <Plug>(aibo-esc)

noremap <buffer> <C-c> <Plug>(aibo-interrupt)
noremap <buffer> <C-l> <Plug>(aibo-clear)
noremap <buffer> <C-n> <Plug>(aibo-next)
noremap <buffer> <C-p> <Plug>(aibo-prev)
noremap <buffer> <Down> <Plug>(aibo-down)
noremap <buffer> <Up> <Plug>(aibo-up)

" Submit mappings (C-Enter/C-S-Enter may not work in some terminal emulators)
nnoremap <buffer> <F5> <Plug>(aibo-submit-close)
inoremap <buffer> <F5> <Esc><Plug>(aibo-submit-close)
nnoremap <buffer> <C-F5> <Plug>(aibo-submit)
inoremap <buffer> <C-F5> <Esc><Plug>(aibo-submit)i
nnoremap <buffer> <C-Enter> <Plug>(aibo-submit-close)
inoremap <buffer> <C-Enter> <Esc><Plug>(aibo-submit-close)
nnoremap <buffer> <C-S-Enter> <Plug>(aibo-submit)
inoremap <buffer> <C-S-Enter> <Esc><Plug>(aibo-submit)i

let s:undo = [
      \ 'silent! unmap <buffer> <CR>',
      \ 'silent! unmap <buffer> <Esc>',
      \ 'silent! unmap <buffer> <C-c>',
      \ 'silent! unmap <buffer> <C-l>',
      \ 'silent! unmap <buffer> <C-n>',
      \ 'silent! unmap <buffer> <C-p>',
      \ 'silent! unmap <buffer> <Down>',
      \ 'silent! unmap <buffer> <Up>',
      \ 'silent! nunmap <buffer> <F5>',
      \ 'silent! iunmap <buffer> <F5>',
      \ 'silent! nunmap <buffer> <C-F5>',
      \ 'silent! iunmap <buffer> <C-F5>',
      \ 'silent! nunmap <buffer> <C-Enter>',
      \ 'silent! iunmap <buffer> <C-Enter>',
      \ 'silent! nunmap <buffer> <C-S-Enter>',
      \ 'silent! iunmap <buffer> <C-S-Enter>',
      \]
let b:undo_ftplugin = (exists('b:undo_ftplugin') ? b:undo_ftplugin .. ' | ' : '') .. join(s:undo, ' | ')
