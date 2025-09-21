if vim.g.loaded_aibo then
  return
end
vim.g.loaded_aibo = 1

local aibo = require('aibo')

vim.api.nvim_create_augroup('aibo_plugin', { clear = true })
vim.api.nvim_create_autocmd('BufReadCmd', {
  group = 'aibo_plugin',
  pattern = 'aiboprompt://*',
  nested = true,
  callback = function()
    local bufnr = vim.fn.expand('<abuf>')
    require('aibo.internal.prompt').init(tonumber(bufnr))
  end
})

vim.api.nvim_create_user_command('Aibo', function(opts)
  local args = vim.split(opts.args, '%s+')
  local cmd = table.remove(args, 1)
  require('aibo.internal.console').open(cmd, args)
end, { nargs = '+' })