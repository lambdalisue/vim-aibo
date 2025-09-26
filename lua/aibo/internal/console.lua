local utils = require("aibo.internal.utils")

local M = {}

---Find all console buffers matching the given cmd and args
---@param cmd string Command to match
---@param args string[] Arguments to match
---@return integer[] List of matching buffer numbers
local function find_console_buffers(cmd, args)
  local matching_buffers = {}
  for _, bufnr in ipairs(vim.api.nvim_list_bufs()) do
    if vim.api.nvim_buf_is_valid(bufnr) then
      local ft = vim.bo[bufnr].filetype or ""
      if ft:match("^aibo%-console") then
        local aibo = vim.b[bufnr].aibo
        if aibo and aibo.cmd == cmd then
          -- Compare args
          local args_match = true
          if #aibo.args ~= #args then
            args_match = false
          else
            for i, arg in ipairs(args) do
              if aibo.args[i] ~= arg then
                args_match = false
                break
              end
            end
          end
          if args_match then
            table.insert(matching_buffers, bufnr)
          end
        end
      end
    end
  end
  return matching_buffers
end

---Follow terminal output to bottom (smart follow - only scrolls if near bottom)
---@param bufnr integer Buffer number
---@return nil
local function follow(bufnr)
  local winid = vim.fn.bufwinid(bufnr)
  if winid == -1 then
    return
  end

  -- Smart follow: only scroll if already near bottom
  vim.api.nvim_win_call(winid, function()
    local win_height = vim.api.nvim_win_get_height(0)
    local buf_line_count = vim.api.nvim_buf_line_count(bufnr)
    local view = vim.fn.winsaveview()
    local current_bottom_line = view.topline + win_height - 1

    -- Use Neovim's scrolloff setting as threshold
    -- Prefer window-local setting, fallback to global
    local threshold = vim.wo.scrolloff
    if threshold == -1 then
      threshold = vim.o.scrolloff
    end
    -- Ensure minimum threshold (provide some margin even if scrolloff is 0)
    threshold = math.max(threshold, 3)

    -- Check if viewport is near bottom
    local is_near_bottom = current_bottom_line >= (buf_line_count - threshold)

    -- Don't scroll if already at the last line
    local cursor_line = vim.api.nvim_win_get_cursor(0)[1]
    local is_at_bottom = cursor_line == buf_line_count

    -- Only scroll if near bottom but not yet at the very bottom
    if is_near_bottom and not is_at_bottom then
      -- Use Lua API to move cursor to last line
      local last_line = vim.api.nvim_buf_line_count(bufnr)
      local last_col = #vim.api.nvim_buf_get_lines(bufnr, last_line - 1, last_line, false)[1]
      vim.api.nvim_win_set_cursor(0, { last_line, last_col })
    end
    -- Preserve scroll position when user is reviewing history (when is_near_bottom is false)
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
  local expected_win = vim.api.nvim_get_current_win()
  local expected_buf = vim.api.nvim_get_current_buf()

  vim.defer_fn(function()
    -- Only trigger startinsert if we're still in the expected prompt window
    -- Check both window and buffer to ensure we're in the right prompt
    if vim.api.nvim_get_current_win() == expected_win and vim.api.nvim_get_current_buf() == expected_buf then
      if is_empty then
        vim.cmd("startinsert")
      else
        vim.cmd("startinsert!")
      end
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
  local bufname = format_prompt_bufname(tonumber(winid) or 0)
  local bufnr = vim.fn.bufnr(bufname)
  if bufnr ~= -1 then
    vim.defer_fn(function()
      vim.cmd(string.format("%dbwipeout!", bufnr))
    end, 0)
  end
end

--- Helper to open a buffer in a window with an optional opener command
---@param bufnr integer The buffer number to open
---@param opener? string Optional window opener command (e.g., "20vsplit", "tabedit")
local function open_buffer_in_window(bufnr, opener)
  if opener then
    vim.cmd(opener .. " | buffer " .. bufnr)
  else
    -- Default: just switch to the buffer in current window
    vim.cmd("buffer " .. bufnr)
  end
end

--- Helper to start a terminal job in a buffer
---@param bufnr integer The buffer to start the terminal in
---@param cmd string The command to execute
---@param args string[] Command arguments
---@return integer job_id The job ID, or 0 on failure
local function start_terminal_job(bufnr, cmd, args)
  -- Build the command array for jobstart
  local cmd_array = { cmd }
  vim.list_extend(cmd_array, args)

  -- Start the terminal job with proper argument handling
  -- The buffer needs to be focused for jobstart to attach the terminal
  return vim.api.nvim_buf_call(bufnr, function()
    return vim.fn.jobstart(cmd_array, {
      term = true,
    })
  end)
end

---Open aibo console with command
---@param cmd string Command to execute
---@param args string[] Arguments for command
---@param opener? string Optional window opener command (e.g., "20vsplit", "tabedit")
---@param stay? boolean Whether to stay in the original window after opening
---@return nil
function M.open(cmd, args, opener, stay)
  -- Save the current window if we need to stay
  local orig_win = nil
  if stay then
    orig_win = vim.api.nvim_get_current_win()
  end

  -- Create a new buffer for the terminal
  local bufnr = vim.api.nvim_create_buf(false, true)

  -- Apply the opener command to show the buffer in a window
  open_buffer_in_window(bufnr, opener)

  -- Start the terminal job
  local job_id = start_terminal_job(bufnr, cmd, args)

  if job_id <= 0 then
    vim.api.nvim_err_writeln("Failed to start terminal: " .. cmd)
    vim.api.nvim_buf_delete(bufnr, { force = true })
    return
  end

  -- Store the job ID in the buffer for later reference
  vim.b[bufnr].terminal_job_id = job_id
  local controller = require("aibo.internal.controller").new(bufnr)

  if not controller then
    vim.notify("Failed to create controller for terminal", vim.log.levels.ERROR, { title = "Aibo" })
    return
  end

  local aibo = {
    cmd = cmd,
    args = args,
    controller = controller,
    follow = function()
      follow(bufnr)
    end,
  }
  vim.b[bufnr].aibo = aibo

  -- Setup buffer autocmds
  local augroup = vim.api.nvim_create_augroup("aibo_console_" .. bufnr, { clear = true })

  vim.api.nvim_create_autocmd("WinClosed", {
    group = augroup,
    buffer = bufnr,
    nested = true,
    callback = function()
      local win_id = tonumber(vim.fn.expand("<afile>"))
      if win_id then
        WinClosed(win_id)
      end
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

  -- Call on_attach callbacks AFTER ftplugin files have run
  local aibo_module = require("aibo")
  local info = {
    type = "console",
    agent = cmd,
    aibo = aibo,
  }

  -- Call buffer type on_attach
  local buffer_cfg = aibo_module.get_buffer_config("console")
  if buffer_cfg.on_attach then
    buffer_cfg.on_attach(bufnr, info)
  end

  -- Call agent-specific on_attach
  local agent_cfg = aibo_module.get_agent_config(cmd)
  if agent_cfg.on_attach then
    agent_cfg.on_attach(bufnr, info)
  end

  vim.cmd("stopinsert")

  aibo.follow()
  InsertEnter()

  -- Restore focus to original window if stay option is set
  if stay then
    utils.restore_window_focus(orig_win)
  end
end

---Toggle aibo console - open/show/hide based on current state
---@param cmd string Command to execute
---@param args string[] Arguments for command
---@param opener? string Optional window opener command (e.g., "20vsplit", "tabedit")
---@param stay? boolean Whether to stay in the original window after opening
---@return boolean True if a console was toggled (shown/hidden), false if a new one was created
function M.toggle(cmd, args, opener, stay)
  -- Save the current window if we need to stay
  local orig_win = nil
  if stay then
    orig_win = vim.api.nvim_get_current_win()
  end

  -- Look for existing consoles with matching cmd and args
  local matching_buffers = find_console_buffers(cmd, args)

  if #matching_buffers == 0 then
    -- No matching console exists, create a new one
    M.open(cmd, args, opener, stay)
    return false
  end

  -- Check for visible consoles in current tabpage
  local visible_in_tabpage = {}
  for _, bufnr in ipairs(matching_buffers) do
    local winnr = vim.fn.bufwinnr(bufnr)
    if winnr ~= -1 then
      local win_id = vim.fn.win_getid(winnr)
      table.insert(visible_in_tabpage, { bufnr = bufnr, win = win_id })
    end
  end

  -- If exactly one visible console in current tabpage, toggle it
  if #visible_in_tabpage == 1 then
    -- Hide the visible console
    vim.api.nvim_win_close(visible_in_tabpage[1].win, false)
    return true
  elseif #visible_in_tabpage > 1 then
    -- Multiple visible consoles in tabpage
    local win_to_close = utils.select_or_first(visible_in_tabpage, "Select console to hide:", function(item)
      return string.format("Buffer %d (Window %d)", item.bufnr, item.win)
    end, function(item)
      return item.win
    end)

    if win_to_close then
      vim.api.nvim_win_close(win_to_close, false)
    end
    return true
  end

  -- No visible consoles in current tabpage, need to show one
  local console_bufnr = utils.select_or_first(matching_buffers, "Select console to show:", function(bufnr)
    local display = string.format("Buffer %d", bufnr)
    -- Add status if visible in another tabpage
    local winid = vim.fn.bufwinid(bufnr)
    if winid ~= -1 then
      display = display .. " (visible in another tab)"
    end
    return display
  end, function(bufnr)
    return bufnr
  end)

  if console_bufnr then
    -- Show the selected console
    open_buffer_in_window(console_bufnr, opener or "split")

    -- Enter insert mode when console becomes visible (unless stay option is set)
    if not stay then
      vim.cmd("startinsert")
    end

    -- Restore focus to original window if stay option is set
    if stay then
      utils.restore_window_focus(orig_win)
    end
  end

  return true
end

---Reuse aibo console - focus if visible, open/show if not
---@param cmd string Command to execute
---@param args string[] Arguments for command
---@param opener? string Optional window opener command (e.g., "20vsplit", "tabedit")
---@param stay? boolean Whether to stay in the original window after opening
---@return boolean True if reused existing console, false if created new
function M.reuse(cmd, args, opener, stay)
  -- Save the current window if we need to stay
  local orig_win = nil
  if stay then
    orig_win = vim.api.nvim_get_current_win()
  end

  -- Look for existing consoles with matching cmd and args
  local matching_buffers = find_console_buffers(cmd, args)

  if #matching_buffers == 0 then
    -- No matching console exists, create a new one
    M.open(cmd, args, opener, stay)
    return false
  end

  -- Check for visible consoles in current tabpage
  local visible_in_tabpage = {}
  for _, bufnr in ipairs(matching_buffers) do
    local winnr = vim.fn.bufwinnr(bufnr)
    if winnr ~= -1 then
      local win_id = vim.fn.win_getid(winnr)
      table.insert(visible_in_tabpage, { bufnr = bufnr, win = win_id })
    end
  end

  -- If exactly one visible console in current tabpage, focus it
  if #visible_in_tabpage == 1 then
    -- Focus the visible console
    vim.api.nvim_set_current_win(visible_in_tabpage[1].win)

    -- Enter insert mode (unless stay option is set)
    if not stay then
      vim.cmd("startinsert")
    end

    -- Restore focus to original window if stay option is set
    if stay then
      utils.restore_window_focus(orig_win)
    end
    return true
  elseif #visible_in_tabpage > 1 then
    -- Multiple visible consoles in tabpage
    local win_to_focus = utils.select_or_first(visible_in_tabpage, "Select console to focus:", function(item)
      return string.format("Buffer %d (Window %d)", item.bufnr, item.win)
    end, function(item)
      return item.win
    end)

    if win_to_focus then
      vim.api.nvim_set_current_win(win_to_focus)

      -- Enter insert mode (unless stay option is set)
      if not stay then
        vim.cmd("startinsert")
      end

      -- Restore focus to original window if stay option is set
      if stay then
        utils.restore_window_focus(orig_win)
      end
    end
    return true
  end

  -- No visible consoles in current tabpage, need to show one
  local console_bufnr = utils.select_or_first(matching_buffers, "Select console to show:", function(bufnr)
    local display = string.format("Buffer %d", bufnr)
    -- Add status if visible in another tabpage
    local winid = vim.fn.bufwinid(bufnr)
    if winid ~= -1 then
      display = display .. " (visible in another tab)"
    end
    return display
  end, function(bufnr)
    return bufnr
  end)

  if console_bufnr then
    -- Show the selected console
    open_buffer_in_window(console_bufnr, opener or "split")

    -- Enter insert mode when console becomes visible (unless stay option is set)
    if not stay then
      vim.cmd("startinsert")
    end

    -- Restore focus to original window if stay option is set
    if stay then
      utils.restore_window_focus(orig_win)
    end
  end

  return true
end

---Setup console <Plug> mappings
---@param bufnr number Buffer number to set mappings for
function M.setup_plug_mappings(bufnr)
  local aibo = require("aibo")

  -- Define <Plug> mappings for console functionality
  vim.keymap.set("n", "<Plug>(aibo-console-submit)", function()
    aibo.submit("", bufnr)
  end, { buffer = bufnr, desc = "Submit empty message" })

  vim.keymap.set("n", "<Plug>(aibo-console-close)", function()
    vim.cmd("quit")
  end, { buffer = bufnr, desc = "Close console" })

  vim.keymap.set("n", "<Plug>(aibo-console-esc)", function()
    aibo.send(aibo.termcode.resolve("<Esc>"), bufnr)
  end, { buffer = bufnr, desc = "Send ESC to agent" })

  vim.keymap.set("n", "<Plug>(aibo-console-interrupt)", function()
    aibo.send(aibo.termcode.resolve("<C-c>"), bufnr)
  end, { buffer = bufnr, desc = "Send interrupt signal (original <C-c>)" })

  vim.keymap.set("n", "<Plug>(aibo-console-clear)", function()
    aibo.send(aibo.termcode.resolve("<C-l>"), bufnr)
  end, { buffer = bufnr, desc = "Clear screen" })

  vim.keymap.set("n", "<Plug>(aibo-console-next)", function()
    aibo.send(aibo.termcode.resolve("<C-n>"), bufnr)
  end, { buffer = bufnr, desc = "Next history" })

  vim.keymap.set("n", "<Plug>(aibo-console-prev)", function()
    aibo.send(aibo.termcode.resolve("<C-p>"), bufnr)
  end, { buffer = bufnr, desc = "Previous history" })

  vim.keymap.set("n", "<Plug>(aibo-console-down)", function()
    aibo.send(aibo.termcode.resolve("<Down>"), bufnr)
  end, { buffer = bufnr, desc = "Move down" })

  vim.keymap.set("n", "<Plug>(aibo-console-up)", function()
    aibo.send(aibo.termcode.resolve("<Up>"), bufnr)
  end, { buffer = bufnr, desc = "Move up" })
end

return M
