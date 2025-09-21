if vim.b.did_ftplugin_aibo_agent_claude then
  return
end
vim.b.did_ftplugin_aibo_agent_claude = 1

local aibo = require('aibo')

-- Claude Code specific plug mappings
vim.keymap.set('', '<Plug>(aibo-claude-mode)', function() aibo.send('\027[Z') end, { buffer = true, silent = true })
vim.keymap.set('', '<Plug>(aibo-claude-verbose)', function() aibo.send('\015') end, { buffer = true, silent = true })
vim.keymap.set('', '<Plug>(aibo-claude-todo)', function() aibo.send('\020') end, { buffer = true, silent = true })
vim.keymap.set('', '<Plug>(aibo-claude-undo)', function() aibo.send('\031') end, { buffer = true, silent = true })
vim.keymap.set('', '<Plug>(aibo-claude-suspend)', function() aibo.send('\026') end, { buffer = true, silent = true })
vim.keymap.set('', '<Plug>(aibo-claude-paste)', function() aibo.send('\022') end, { buffer = true, silent = true })

-- Key mappings for normal and visual modes
vim.keymap.set({'n', 'v'}, '<S-Tab>', '<Plug>(aibo-claude-mode)', { buffer = true })
vim.keymap.set({'n', 'v'}, '<F2>', '<Plug>(aibo-claude-mode)', { buffer = true })
vim.keymap.set({'n', 'v'}, '<C-o>', '<Plug>(aibo-claude-verbose)', { buffer = true })
vim.keymap.set({'n', 'v'}, '<C-t>', '<Plug>(aibo-claude-todo)', { buffer = true })
vim.keymap.set({'n', 'v'}, '<C-_>', '<Plug>(aibo-claude-undo)', { buffer = true })
vim.keymap.set({'n', 'v'}, '<C-->', '<Plug>(aibo-claude-undo)', { buffer = true })
vim.keymap.set({'n', 'v'}, '<C-z>', '<Plug>(aibo-claude-suspend)', { buffer = true })
vim.keymap.set({'n', 'v'}, '<C-v>', '<Plug>(aibo-claude-paste)', { buffer = true })

-- Key mappings for insert mode (use <C-\><C-o> to execute normal mode command without leaving insert)
vim.keymap.set('i', '<S-Tab>', '<C-\\><C-o><Plug>(aibo-claude-mode)', { buffer = true })
vim.keymap.set('i', '<F2>', '<C-\\><C-o><Plug>(aibo-claude-mode)', { buffer = true })
vim.keymap.set('i', '<C-o>', '<C-\\><C-o><Plug>(aibo-claude-verbose)', { buffer = true })
vim.keymap.set('i', '<C-t>', '<C-\\><C-o><Plug>(aibo-claude-todo)', { buffer = true })
vim.keymap.set('i', '<C-_>', '<C-\\><C-o><Plug>(aibo-claude-undo)', { buffer = true })
vim.keymap.set('i', '<C-->', '<C-\\><C-o><Plug>(aibo-claude-undo)', { buffer = true })
vim.keymap.set('i', '<C-z>', '<C-\\><C-o><Plug>(aibo-claude-suspend)', { buffer = true })
vim.keymap.set('i', '<C-v>', '<C-\\><C-o><Plug>(aibo-claude-paste)', { buffer = true })

-- Setup undo_ftplugin
local undo_commands = {
  'silent! nunmap <buffer> <S-Tab>',
  'silent! iunmap <buffer> <S-Tab>',
  'silent! vunmap <buffer> <S-Tab>',
  'silent! nunmap <buffer> <F2>',
  'silent! iunmap <buffer> <F2>',
  'silent! vunmap <buffer> <F2>',
  'silent! nunmap <buffer> <C-o>',
  'silent! iunmap <buffer> <C-o>',
  'silent! vunmap <buffer> <C-o>',
  'silent! nunmap <buffer> <C-t>',
  'silent! iunmap <buffer> <C-t>',
  'silent! vunmap <buffer> <C-t>',
  'silent! nunmap <buffer> <C-_>',
  'silent! iunmap <buffer> <C-_>',
  'silent! vunmap <buffer> <C-_>',
  'silent! nunmap <buffer> <C-->',
  'silent! iunmap <buffer> <C-->',
  'silent! vunmap <buffer> <C-->',
  'silent! nunmap <buffer> <C-z>',
  'silent! iunmap <buffer> <C-z>',
  'silent! vunmap <buffer> <C-z>',
  'silent! nunmap <buffer> <C-v>',
  'silent! iunmap <buffer> <C-v>',
  'silent! vunmap <buffer> <C-v>',
}

local existing_undo = vim.b.undo_ftplugin or ''
if existing_undo ~= '' then
  existing_undo = existing_undo .. ' | '
end
vim.b.undo_ftplugin = existing_undo .. table.concat(undo_commands, ' | ')