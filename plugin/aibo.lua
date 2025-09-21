-- Guard against multiple loads
if vim.g.loaded_aibo then
  return
end
vim.g.loaded_aibo = 1

-- Check Neovim version
if vim.fn.has('nvim-0.10.0') ~= 1 then
  vim.api.nvim_err_writeln('vim-aibo requires Neovim 0.10.0 or later')
  return
end

-- Setup autocommands
local augroup = vim.api.nvim_create_augroup('aibo_plugin', { clear = true })
vim.api.nvim_create_autocmd('BufReadCmd', {
  group = augroup,
  pattern = 'aiboprompt://*',
  nested = true,
  callback = function()
    local bufnr = vim.fn.expand('<abuf>')
    require('aibo.internal.prompt').init(tonumber(bufnr))
  end
})

-- Create user command
vim.api.nvim_create_user_command('Aibo', function(opts)
  local args = vim.split(opts.args, '%s+')
  local cmd = table.remove(args, 1)
  require('aibo.internal.console').open(cmd, args)
end, {
  nargs = '+',
  desc = 'Open Aibo console with specified command'
})