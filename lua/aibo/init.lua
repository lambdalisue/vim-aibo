local M = {}

vim.g['aibo#submit_key'] = vim.g['aibo#submit_key'] or vim.api.nvim_replace_termcodes('<CR>', true, false, true)
vim.g['aibo#submit_delay'] = vim.g['aibo#submit_delay'] or 100

local function get_aibo(bufnr)
  bufnr = bufnr or vim.api.nvim_get_current_buf()
  local aibo = vim.b[bufnr].aibo
  if not aibo then
    error(string.format('[aibo] No b:aibo found in the buffer "%s"', vim.api.nvim_buf_get_name(bufnr)))
  end
  return aibo
end

function M.send(data, bufnr)
  local aibo = get_aibo(bufnr)
  aibo.controller.send(data)
end

function M.submit(data, bufnr)
  local aibo = get_aibo(bufnr)
  aibo.controller.send(data)

  vim.defer_fn(function()
    aibo.controller.send(vim.g['aibo#submit_key'])
  end, vim.g['aibo#submit_delay'])

  vim.defer_fn(function()
    aibo.follow()
  end, vim.g['aibo#submit_delay'])
end

return M