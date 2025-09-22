local M = {}

---Follow terminal output to bottom
---@param winid integer Window ID
---@return nil
local function follow(winid)
  vim.api.nvim_win_call(winid, function()
    vim.cmd("normal! G")
  end)
end

---Format prompt buffer name
---@param winid integer Window ID
---@return string Formatted buffer name
local function format_prompt_bufname(winid)
  return string.format("aiboprompt://%d", winid)
end

---Ensure insert mode in buffer
---@param bufnr integer Buffer number
---@return nil
local function ensure_insert(bufnr)
  local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
  local is_empty = table.concat(lines, "\n") == ""

  vim.defer_fn(function()
    if is_empty then
      vim.cmd("startinsert")
    else
      vim.cmd("startinsert!")
    end
  end, 0)
end

---Handle InsertEnter event
---@return nil
local function InsertEnter()
  local winid = vim.api.nvim_get_current_win()
  local bufname = format_prompt_bufname(winid)
  local prompt_winid = vim.fn.bufwinid(bufname)

  if prompt_winid == -1 then
    local config = require("aibo").get_config()
    vim.cmd(string.format("rightbelow %dsplit %s", config.prompt_height, vim.fn.fnameescape(bufname)))
  else
    vim.api.nvim_set_current_win(prompt_winid)
  end

  ensure_insert(vim.api.nvim_get_current_buf())
end

---Handle WinClosed event
---@param winid integer|string Window ID
---@return nil
local function WinClosed(winid)
  local bufname = format_prompt_bufname(winid)
  local bufnr = vim.fn.bufnr(bufname)
  if bufnr ~= -1 then
    vim.defer_fn(function()
      vim.cmd(string.format("%dbwipeout!", bufnr))
    end, 0)
  end
end

---Open aibo console with command
---@param cmd string Command to execute
---@param args string[] Arguments for command
---@return nil
function M.open(cmd, args)
  vim.cmd("silent terminal " .. cmd .. " " .. table.concat(args, " "))

  local bufnr = vim.api.nvim_get_current_buf()
  local winid = vim.api.nvim_get_current_win()
  local controller = require("aibo.internal.controller").new(bufnr)

  if not controller then
    vim.notify("Failed to create controller for terminal", vim.log.levels.ERROR, { title = "Aibo" })
    return
  end

  vim.b.aibo = {
    cmd = cmd,
    args = args,
    controller = controller,
    follow = function()
      follow(winid)
    end,
  }

  -- Setup buffer autocmds
  local augroup = vim.api.nvim_create_augroup("aibo_console_" .. bufnr, { clear = true })

  vim.api.nvim_create_autocmd("WinClosed", {
    group = augroup,
    buffer = bufnr,
    nested = true,
    callback = function()
      WinClosed(tonumber(vim.fn.expand("<afile>")))
    end,
  })

  vim.api.nvim_create_autocmd("TermEnter", {
    group = augroup,
    buffer = bufnr,
    nested = true,
    callback = InsertEnter,
  })

  -- Set filetype (this triggers ftplugin files)
  vim.bo[bufnr].filetype = string.format("aibo-console.aibo-agent-%s", cmd)

  -- Call on_attach AFTER ftplugin files have run
  local aibo_module = require("aibo")
  local cfg = aibo_module.get_buffer_config("console", cmd)
  if cfg and cfg.on_attach then
    cfg.on_attach(bufnr, {
      type = "console",
      agent = cmd,
      aibo = vim.b.aibo,
    })
  end
  vim.cmd("stopinsert")

  follow(winid)
  InsertEnter()
end

return M
