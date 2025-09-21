local M = {}

---Find the console buffer number from prompt buffer
---@param bufnr integer Prompt buffer number
---@return integer Console buffer number
local function find_console_bufnr(bufnr)
  local bufname = vim.api.nvim_buf_get_name(bufnr)
  local winid = bufname:match('^aiboprompt://(%d+)$')

  if not winid then
    vim.notify(('Invalid aibo-prompt buffer "%s"'):format(bufname), vim.log.levels.ERROR, { title = 'Aibo' })
    return -1
  end

  local console_bufnr = vim.fn.winbufnr(tonumber(winid))
  if console_bufnr == -1 then
    vim.notify(('No console window found for window ID %s'):format(winid), vim.log.levels.ERROR, { title = 'Aibo' })
    return -1
  end

  return console_bufnr
end

---Submit content from prompt buffer
---@param bufnr integer Buffer number
---@return nil
local function submit_content(bufnr)
  local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
  local content = table.concat(lines, '\n')

  local aibo = require('aibo')
  aibo.submit(content, bufnr)

  vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, {})
  vim.bo[bufnr].modified = false
  vim.api.nvim_win_set_cursor(0, {1, 0})
end

---Handle WinLeave event
---@return nil
local function WinLeave()
  local winnr = vim.fn.winnr()
  vim.cmd(string.format('%dhide', winnr))
end

---Handle BufWritePre event
---@return nil
local function BufWritePre()
  vim.bo.modified = true
end

---Handle BufWriteCmd event
---@return nil
local function BufWriteCmd()
  submit_content(vim.api.nvim_get_current_buf())
  vim.bo.modified = false
end

---Handle QuitPre event
---@return nil
local function QuitPre()
  local bufinfos = vim.fn.getbufinfo({bufloaded = 1})
  for _, bufinfo in ipairs(bufinfos) do
    local ft = vim.bo[bufinfo.bufnr].filetype
    if ft:match('aibo%-prompt') then
      vim.bo[bufinfo.bufnr].modified = false
    end
  end
end

---Initialize prompt buffer
---@param prompt_bufnr integer Prompt buffer number
---@return nil
function M.init(prompt_bufnr)
  local console_bufnr = find_console_bufnr(prompt_bufnr)
  if console_bufnr == -1 then
    return
  end

  local aibo = vim.b[console_bufnr].aibo
  if not aibo then
    vim.notify(('No aibo instance found in console buffer %d'):format(console_bufnr),
               vim.log.levels.ERROR, { title = 'Aibo' })
    return
  end

  vim.b[prompt_bufnr].aibo = aibo

  local augroup = vim.api.nvim_create_augroup('aibo_prompt_' .. prompt_bufnr, { clear = true })

  vim.api.nvim_create_autocmd('WinLeave', {
    group = augroup,
    buffer = prompt_bufnr,
    nested = true,
    callback = WinLeave
  })

  vim.api.nvim_create_autocmd('BufWritePre', {
    group = augroup,
    buffer = prompt_bufnr,
    nested = true,
    callback = BufWritePre
  })

  vim.api.nvim_create_autocmd('BufWriteCmd', {
    group = augroup,
    buffer = prompt_bufnr,
    nested = true,
    callback = BufWriteCmd
  })

  vim.bo[prompt_bufnr].modeline = false
  vim.bo[prompt_bufnr].swapfile = false
  vim.bo[prompt_bufnr].buflisted = false
  vim.bo[prompt_bufnr].buftype = 'acwrite'
  vim.bo[prompt_bufnr].bufhidden = 'hide'

  -- Set window options for the current window
  local winid = vim.api.nvim_get_current_win()
  vim.wo[winid].winfixbuf = true
  vim.wo[winid].winfixheight = true

  local aibo_module = require('aibo')

  -- Create keymaps helper
  local function create_keymap(name, rhs)
    vim.keymap.set('', name, rhs, { buffer = prompt_bufnr, silent = true })
  end

  -- Helper for terminal key sends
  local function send_key(key)
    return function()
      aibo_module.send(vim.api.nvim_replace_termcodes(key, true, false, true))
    end
  end

  -- Define all keymaps
  create_keymap('<Plug>(aibo-submit)', '<Cmd>write<CR>')
  create_keymap('<Plug>(aibo-submit-close)', '<Cmd>wq<CR>')
  create_keymap('<Plug>(aibo-esc)', send_key('<Esc>'))
  create_keymap('<Plug>(aibo-interrupt)', send_key('<C-c>'))
  create_keymap('<Plug>(aibo-clear)', send_key('<C-l>'))
  create_keymap('<Plug>(aibo-next)', send_key('<C-n>'))
  create_keymap('<Plug>(aibo-prev)', send_key('<C-p>'))
  create_keymap('<Plug>(aibo-down)', send_key('<Down>'))
  create_keymap('<Plug>(aibo-up)', send_key('<Up>'))

  vim.bo[prompt_bufnr].filetype = string.format('aibo-prompt.aibo-agent-%s', aibo.cmd)
end

local global_augroup = vim.api.nvim_create_augroup('aibo_prompt_global', { clear = true })
vim.api.nvim_create_autocmd('QuitPre', {
  group = global_augroup,
  pattern = '*',
  nested = true,
  callback = QuitPre
})

return M