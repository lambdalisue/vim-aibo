if vim.b.did_ftplugin_aibo_agent_codex then
  return
end
vim.b.did_ftplugin_aibo_agent_codex = 1

local aibo = require('aibo')

-- Codex specific plug mappings
vim.keymap.set('', '<Plug>(aibo-codex-transcript)', function() aibo.send('\020') end, { buffer = true, silent = true })

-- Key mappings
vim.keymap.set('', '<C-t>', '<Plug>(aibo-codex-transcript)', { buffer = true })
vim.keymap.set('', '<Home>', function() aibo.send(vim.api.nvim_replace_termcodes('<Home>', true, false, true)) end, { buffer = true })
vim.keymap.set('', '<End>', function() aibo.send(vim.api.nvim_replace_termcodes('<End>', true, false, true)) end, { buffer = true })
vim.keymap.set('', '<PageUp>', function() aibo.send(vim.api.nvim_replace_termcodes('<PageUp>', true, false, true)) end, { buffer = true })
vim.keymap.set('', '<PageDown>', function() aibo.send(vim.api.nvim_replace_termcodes('<PageDown>', true, false, true)) end, { buffer = true })
vim.keymap.set('', 'q', function() aibo.send('q') end, { buffer = true })

-- Setup undo_ftplugin
local undo_commands = {
  'silent! unmap <buffer> <C-t>',
  'silent! unmap <buffer> <Home>',
  'silent! unmap <buffer> <End>',
  'silent! unmap <buffer> <PageUp>',
  'silent! unmap <buffer> <PageDown>',
  'silent! unmap <buffer> q',
}

local existing_undo = vim.b.undo_ftplugin or ''
if existing_undo ~= '' then
  existing_undo = existing_undo .. ' | '
end
vim.b.undo_ftplugin = existing_undo .. table.concat(undo_commands, ' | ')