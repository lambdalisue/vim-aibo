local M = {}

local function find_console_bufnr(bufnr)
  local bufname = vim.api.nvim_buf_get_name(bufnr)
  local winid = bufname:match('^aiboprompt://(%d+)$')

  if not winid then
    error(string.format('[aibo] Invalid aibo-prompt buffer "%s" (bufnr: %d)', bufname, bufnr))
  end

  local console_bufnr = vim.fn.winbufnr(tonumber(winid))
  if console_bufnr == -1 then
    error(string.format('[aibo] No console window found (winid: %d)', winid))
  end

  return console_bufnr
end

local function submit_content(bufnr)
  local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
  local content = table.concat(lines, '\n')

  local aibo = require('aibo')
  aibo.submit(content, bufnr)

  vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, {})
  vim.api.nvim_buf_set_option(bufnr, 'modified', false)
  vim.api.nvim_win_set_cursor(0, {1, 0})
end

local function WinLeave()
  local winnr = vim.fn.winnr()
  vim.cmd(string.format('%dhide', winnr))
end

local function BufWritePre()
  vim.api.nvim_buf_set_option(0, 'modified', true)
end

local function BufWriteCmd()
  submit_content(vim.api.nvim_get_current_buf())
  vim.api.nvim_buf_set_option(0, 'modified', false)
end

local function QuitPre()
  local bufinfos = vim.fn.getbufinfo({bufloaded = 1})
  for _, bufinfo in ipairs(bufinfos) do
    local ft = vim.api.nvim_buf_get_option(bufinfo.bufnr, 'filetype')
    if ft:match('aibo%-prompt') then
      vim.api.nvim_buf_set_option(bufinfo.bufnr, 'modified', false)
    end
  end
end

function M.init(prompt_bufnr)
  local console_bufnr = find_console_bufnr(prompt_bufnr)
  local aibo = vim.b[console_bufnr].aibo

  if not aibo then
    error('[aibo] b:aibo is not defined in the buffer ' .. vim.api.nvim_buf_get_name(console_bufnr))
  end

  vim.b[prompt_bufnr].aibo = aibo

  vim.api.nvim_create_augroup('aibo_autoload_aibo_internal_prompt_init', { clear = true })

  vim.api.nvim_create_autocmd('WinLeave', {
    group = 'aibo_autoload_aibo_internal_prompt_init',
    buffer = prompt_bufnr,
    nested = true,
    callback = WinLeave
  })

  vim.api.nvim_create_autocmd('BufWritePre', {
    group = 'aibo_autoload_aibo_internal_prompt_init',
    buffer = prompt_bufnr,
    nested = true,
    callback = BufWritePre
  })

  vim.api.nvim_create_autocmd('BufWriteCmd', {
    group = 'aibo_autoload_aibo_internal_prompt_init',
    buffer = prompt_bufnr,
    nested = true,
    callback = BufWriteCmd
  })

  vim.api.nvim_buf_set_option(prompt_bufnr, 'modeline', false)
  vim.api.nvim_buf_set_option(prompt_bufnr, 'swapfile', false)
  vim.api.nvim_buf_set_option(prompt_bufnr, 'backup', false)
  vim.api.nvim_buf_set_option(prompt_bufnr, 'buflisted', false)
  vim.api.nvim_buf_set_option(prompt_bufnr, 'buftype', 'acwrite')
  vim.api.nvim_buf_set_option(prompt_bufnr, 'bufhidden', 'hide')

  if vim.fn.has('nvim-0.10') == 1 then
    vim.api.nvim_win_set_option(0, 'winfixbuf', true)
  end
  vim.api.nvim_win_set_option(0, 'winfixheight', true)

  local aibo_module = require('aibo')

  vim.keymap.set('', '<Plug>(aibo-submit)', '<Cmd>write<CR>', { buffer = prompt_bufnr, silent = true })
  vim.keymap.set('', '<Plug>(aibo-submit-close)', '<Cmd>wq<CR>', { buffer = prompt_bufnr, silent = true })
  vim.keymap.set('', '<Plug>(aibo-esc)', function() aibo_module.send(vim.api.nvim_replace_termcodes('<Esc>', true, false, true)) end, { buffer = prompt_bufnr, silent = true })
  vim.keymap.set('', '<Plug>(aibo-interrupt)', function() aibo_module.send(vim.api.nvim_replace_termcodes('<C-c>', true, false, true)) end, { buffer = prompt_bufnr, silent = true })
  vim.keymap.set('', '<Plug>(aibo-clear)', function() aibo_module.send(vim.api.nvim_replace_termcodes('<C-l>', true, false, true)) end, { buffer = prompt_bufnr, silent = true })
  vim.keymap.set('', '<Plug>(aibo-next)', function() aibo_module.send(vim.api.nvim_replace_termcodes('<C-n>', true, false, true)) end, { buffer = prompt_bufnr, silent = true })
  vim.keymap.set('', '<Plug>(aibo-prev)', function() aibo_module.send(vim.api.nvim_replace_termcodes('<C-p>', true, false, true)) end, { buffer = prompt_bufnr, silent = true })
  vim.keymap.set('', '<Plug>(aibo-down)', function() aibo_module.send(vim.api.nvim_replace_termcodes('<Down>', true, false, true)) end, { buffer = prompt_bufnr, silent = true })
  vim.keymap.set('', '<Plug>(aibo-up)', function() aibo_module.send(vim.api.nvim_replace_termcodes('<Up>', true, false, true)) end, { buffer = prompt_bufnr, silent = true })

  vim.cmd(string.format('setfiletype aibo-prompt.aibo-agent-%s', aibo.cmd))
end

vim.api.nvim_create_augroup('aibo_autoload_aibo_internal_prompt', { clear = true })
vim.api.nvim_create_autocmd('QuitPre', {
  group = 'aibo_autoload_aibo_internal_prompt',
  pattern = '*',
  nested = true,
  callback = QuitPre
})

return M