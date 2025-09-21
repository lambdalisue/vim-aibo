local M = {}

vim.g['aibo#internal#console#prompt_height'] = vim.g['aibo#internal#console#prompt_height'] or 10

local function follow(winid)
  vim.api.nvim_win_call(winid, function()
    vim.cmd('normal! G')
  end)
end

local function format_prompt_bufname(winid)
  return string.format('aiboprompt://%d', winid)
end

local function ensure_insert(bufnr)
  local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
  local is_empty = table.concat(lines, '\n') == ''

  vim.defer_fn(function()
    if is_empty then
      vim.cmd('startinsert')
    else
      vim.cmd('startinsert!')
    end
  end, 0)
end

local function InsertEnter()
  local winid = vim.api.nvim_get_current_win()
  local bufname = format_prompt_bufname(winid)
  local bufnr = vim.fn.bufnr(bufname)
  local prompt_winid = vim.fn.bufwinid(bufname)

  if prompt_winid == -1 then
    vim.cmd(string.format(
      'rightbelow %dsplit %s',
      vim.g['aibo#internal#console#prompt_height'],
      vim.fn.fnameescape(bufname)
    ))
  else
    vim.api.nvim_set_current_win(prompt_winid)
  end

  ensure_insert(vim.api.nvim_get_current_buf())
end

local function WinClosed(winid)
  local bufname = format_prompt_bufname(winid)
  local bufnr = vim.fn.bufnr(bufname)
  if bufnr ~= -1 then
    vim.defer_fn(function()
      vim.cmd(string.format('%dbwipeout!', bufnr))
    end, 0)
  end
end

function M.open(cmd, args)
  vim.cmd('silent terminal ' .. cmd .. ' ' .. table.concat(args, ' '))

  local bufnr = vim.api.nvim_get_current_buf()
  local winid = vim.api.nvim_get_current_win()
  local controller = require('aibo.internal.controller').new(bufnr)

  vim.b.aibo = {
    cmd = cmd,
    args = args,
    controller = controller,
    follow = function() follow(winid) end
  }

  vim.api.nvim_create_augroup('aibo_autoload_aibo_internal_console_open', { clear = true })

  vim.api.nvim_create_autocmd('WinClosed', {
    group = 'aibo_autoload_aibo_internal_console_open',
    buffer = bufnr,
    nested = true,
    callback = function()
      WinClosed(tonumber(vim.fn.expand('<afile>')))
    end
  })

  vim.api.nvim_create_autocmd('TermEnter', {
    group = 'aibo_autoload_aibo_internal_console_open',
    buffer = bufnr,
    nested = true,
    callback = InsertEnter
  })

  local aibo = require('aibo')

  vim.keymap.set('', '<Plug>(aibo-submit)', function() aibo.submit('') end, { buffer = true, silent = true })
  vim.keymap.set('', '<Plug>(aibo-esc)', function() aibo.send(vim.api.nvim_replace_termcodes('<Esc>', true, false, true)) end, { buffer = true, silent = true })
  vim.keymap.set('', '<Plug>(aibo-interrupt)', function() aibo.send(vim.api.nvim_replace_termcodes('<C-c>', true, false, true)) end, { buffer = true, silent = true })
  vim.keymap.set('', '<Plug>(aibo-clear)', function() aibo.send(vim.api.nvim_replace_termcodes('<C-l>', true, false, true)) end, { buffer = true, silent = true })
  vim.keymap.set('', '<Plug>(aibo-next)', function() aibo.send(vim.api.nvim_replace_termcodes('<C-n>', true, false, true)) end, { buffer = true, silent = true })
  vim.keymap.set('', '<Plug>(aibo-prev)', function() aibo.send(vim.api.nvim_replace_termcodes('<C-p>', true, false, true)) end, { buffer = true, silent = true })
  vim.keymap.set('', '<Plug>(aibo-down)', function() aibo.send(vim.api.nvim_replace_termcodes('<Down>', true, false, true)) end, { buffer = true, silent = true })
  vim.keymap.set('', '<Plug>(aibo-up)', function() aibo.send(vim.api.nvim_replace_termcodes('<Up>', true, false, true)) end, { buffer = true, silent = true })

  vim.cmd(string.format('setfiletype aibo-console.aibo-agent-%s', cmd))
  vim.cmd('stopinsert')

  follow(winid)
  InsertEnter()
end

return M