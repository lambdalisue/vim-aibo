if vim.b.did_ftplugin_aibo_prompt then
  return
end
vim.b.did_ftplugin_aibo_prompt = 1

-- Display settings
vim.opt_local.number = false
vim.opt_local.relativenumber = false
vim.opt_local.signcolumn = 'no'

vim.keymap.set('n', '<CR>', '<Plug>(aibo-submit)', { buffer = true })
vim.keymap.set('n', '<Esc>', '<Plug>(aibo-esc)', { buffer = true })
vim.keymap.set('i', '<C-Enter>', '<Esc><Plug>(aibo-submit-close)', { buffer = true })
vim.keymap.set('n', '<C-Enter>', '<Plug>(aibo-submit-close)', { buffer = true })
vim.keymap.set('i', '<C-S-Enter>', '<Esc><Plug>(aibo-submit)i', { buffer = true })
vim.keymap.set('n', '<C-S-Enter>', '<Plug>(aibo-submit)', { buffer = true })

-- F5 key mappings (alternative submit keys)
vim.keymap.set('n', '<F5>', '<Plug>(aibo-submit-close)', { buffer = true })
vim.keymap.set('i', '<F5>', '<Esc><Plug>(aibo-submit-close)', { buffer = true })
vim.keymap.set('n', '<C-F5>', '<Plug>(aibo-submit)', { buffer = true })
vim.keymap.set('i', '<C-F5>', '<Esc><Plug>(aibo-submit)i', { buffer = true })

vim.keymap.set('', '<C-c>', '<Plug>(aibo-interrupt)', { buffer = true })
vim.keymap.set('', '<C-l>', '<Plug>(aibo-clear)', { buffer = true })
vim.keymap.set('', '<C-n>', '<Plug>(aibo-next)', { buffer = true })
vim.keymap.set('', '<C-p>', '<Plug>(aibo-prev)', { buffer = true })
vim.keymap.set('', '<Down>', '<Plug>(aibo-down)', { buffer = true })
vim.keymap.set('', '<Up>', '<Plug>(aibo-up)', { buffer = true })

local undo_commands = {
  'silent! nunmap <buffer> <CR>',
  'silent! nunmap <buffer> <Esc>',
  'silent! unmap <buffer> <C-c>',
  'silent! unmap <buffer> <C-l>',
  'silent! unmap <buffer> <C-n>',
  'silent! unmap <buffer> <C-p>',
  'silent! unmap <buffer> <Down>',
  'silent! unmap <buffer> <Up>',
  'silent! nunmap <buffer> <C-Enter>',
  'silent! iunmap <buffer> <C-Enter>',
  'silent! nunmap <buffer> <C-S-Enter>',
  'silent! iunmap <buffer> <C-S-Enter>',
  'silent! nunmap <buffer> <F5>',
  'silent! iunmap <buffer> <F5>',
  'silent! nunmap <buffer> <C-F5>',
  'silent! iunmap <buffer> <C-F5>',
}

local existing_undo = vim.b.undo_ftplugin or ''
if existing_undo ~= '' then
  existing_undo = existing_undo .. ' | '
end
vim.b.undo_ftplugin = existing_undo .. table.concat(undo_commands, ' | ')

