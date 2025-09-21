if exists('b:did_ftplugin_aibo_agent_claude')
  finish
endif
let b:did_ftplugin_aibo_agent_claude = 1

" Claude Code specific key mappings
noremap <buffer><silent> <Plug>(aibo-claude-mode) <Cmd>call aibo#send("\e[Z")<CR>
noremap <buffer><silent> <Plug>(aibo-claude-verbose) <Cmd>call aibo#send("\<C-o>")<CR>
noremap <buffer><silent> <Plug>(aibo-claude-todo) <Cmd>call aibo#send("\<C-t>")<CR>
noremap <buffer><silent> <Plug>(aibo-claude-undo) <Cmd>call aibo#send("\<C-_>")<CR>
noremap <buffer><silent> <Plug>(aibo-claude-suspend) <Cmd>call aibo#send("\<C-z>")<CR>
noremap <buffer><silent> <Plug>(aibo-claude-paste) <Cmd>call aibo#send("\<C-v>")<CR>

noremap <buffer> <S-Tab> <Plug>(aibo-claude-mode)
noremap <buffer> <F2> <Plug>(aibo-claude-mode)
noremap <buffer> <C-o> <Plug>(aibo-claude-verbose)
noremap <buffer> <C-t> <Plug>(aibo-claude-todo)
noremap <buffer> <C-_> <Plug>(aibo-claude-undo)
noremap <buffer> <C--> <Plug>(aibo-claude-undo)
noremap <buffer> <C-z> <Plug>(aibo-claude-suspend)
noremap <buffer> <C-v> <Plug>(aibo-claude-paste)

let s:undo = [
      \ 'silent! unmap <buffer> <S-Tab>',
      \ 'silent! unmap <buffer> <F2>',
      \ 'silent! unmap <buffer> <C-o>',
      \ 'silent! unmap <buffer> <C-t>',
      \ 'silent! unmap <buffer> <C-_>',
      \ 'silent! unmap <buffer> <C-->',
      \ 'silent! unmap <buffer> <C-z>',
      \ 'silent! unmap <buffer> <C-v>',
      \]
let b:undo_ftplugin = (exists('b:undo_ftplugin') ? b:undo_ftplugin .. ' | ' : '') .. join(s:undo, ' | ')
