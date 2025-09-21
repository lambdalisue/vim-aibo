if exists('b:did_ftplugin_aibo_console')
  finish
endif
let b:did_ftplugin_aibo_console = 1

nnoremap <buffer> <CR> <Plug>(aibo-submit)
nnoremap <buffer> <Esc> <Plug>(aibo-esc)

noremap <buffer> <C-c> <Plug>(aibo-interrupt)
noremap <buffer> <C-l> <Plug>(aibo-clear)
noremap <buffer> <C-n> <Plug>(aibo-next)
noremap <buffer> <C-p> <Plug>(aibo-prev)
noremap <buffer> <Down> <Plug>(aibo-down)
noremap <buffer> <Up> <Plug>(aibo-up)

" S-Tab may not work in some terminal emulators.
nnoremap <buffer><silent> <S-Tab> <Cmd>call aibo#send("\e[Z")<CR>

let s:undo = [
      \ 'silent! unmap <buffer> <CR>',
      \ 'silent! unmap <buffer> <Esc>',
      \ 'silent! unmap <buffer> <C-c>',
      \ 'silent! unmap <buffer> <C-l>',
      \ 'silent! unmap <buffer> <C-n>',
      \ 'silent! unmap <buffer> <C-p>',
      \ 'silent! unmap <buffer> <Down>',
      \ 'silent! unmap <buffer> <Up>',
      \]
let b:undo_ftplugin = (exists('b:undo_ftplugin') ? b:undo_ftplugin .. ' | ' : '') .. join(s:undo, ' | ')
