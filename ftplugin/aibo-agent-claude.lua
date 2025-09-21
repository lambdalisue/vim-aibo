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

-- Key mappings
vim.keymap.set('', '<S-Tab>', '<Plug>(aibo-claude-mode)', { buffer = true })
vim.keymap.set('', '<F2>', '<Plug>(aibo-claude-mode)', { buffer = true })
vim.keymap.set('', '<C-o>', '<Plug>(aibo-claude-verbose)', { buffer = true })
vim.keymap.set('', '<C-t>', '<Plug>(aibo-claude-todo)', { buffer = true })
vim.keymap.set('', '<C-_>', '<Plug>(aibo-claude-undo)', { buffer = true })
vim.keymap.set('', '<C-->', '<Plug>(aibo-claude-undo)', { buffer = true })
vim.keymap.set('', '<C-z>', '<Plug>(aibo-claude-suspend)', { buffer = true })
vim.keymap.set('', '<C-v>', '<Plug>(aibo-claude-paste)', { buffer = true })

-- Setup undo_ftplugin
local undo_commands = {
  'silent! unmap <buffer> <S-Tab>',
  'silent! unmap <buffer> <F2>',
  'silent! unmap <buffer> <C-o>',
  'silent! unmap <buffer> <C-t>',
  'silent! unmap <buffer> <C-_>',
  'silent! unmap <buffer> <C-->',
  'silent! unmap <buffer> <C-z>',
  'silent! unmap <buffer> <C-v>',
}

local existing_undo = vim.b.undo_ftplugin or ''
if existing_undo ~= '' then
  existing_undo = existing_undo .. ' | '
end
vim.b.undo_ftplugin = existing_undo .. table.concat(undo_commands, ' | ')