if exists('b:did_ftplugin_aibo_agent_codex')
  finish
endif
let b:did_ftplugin_aibo_agent_codex = 1

" Claude Code specific key mappings
noremap <buffer><silent> <Plug>(aibo-codex-transcript) <Cmd>call aibo#send("\<C-t>")<CR>

noremap <buffer> <C-t> <Plug>(aibo-codex-transcript)
noremap <buffer> <Home> <Cmd>call aibo#send("\<Home>")<CR>
noremap <buffer> <End> <Cmd>call aibo#send("\<End>")<CR>
noremap <buffer> <PageUp> <Cmd>call aibo#send("\<PageUp>")<CR>
noremap <buffer> <PageDown> <Cmd>call aibo#send("\<PageDown>")<CR>
noremap <buffer> q <Cmd>call aibo#send("q")<CR>

let s:undo = [
      \ 'silent! unmap <buffer> <C-t>',
      \ 'silent! unmap <buffer> <Home>',
      \ 'silent! unmap <buffer> <End>',
      \ 'silent! unmap <buffer> <PageUp>',
      \ 'silent! unmap <buffer> <PageDown>',
      \ 'silent! unmap <buffer> q',
      \]
let b:undo_ftplugin = (exists('b:undo_ftplugin') ? b:undo_ftplugin .. ' | ' : '') .. join(s:undo, ' | ')


