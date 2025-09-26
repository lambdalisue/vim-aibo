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

---Re-apply bottom margin for existing console buffer
---@param bufnr integer Buffer number
---@return nil
local function reapply_bottom_margin(bufnr)
  local config = require("aibo").get_config()
  local ns = vim.api.nvim_create_namespace("aibo_console_margin")

  local function add_margin()
    -- Clear existing virtual text
    vim.api.nvim_buf_clear_namespace(bufnr, ns, 0, -1)

    -- Get the last line of the buffer
    local last_line = vim.api.nvim_buf_line_count(bufnr) - 1

    -- Create virtual lines for padding
    local virt_lines = {}
    for i = 1, config.prompt_height do
      table.insert(virt_lines, { { "", "Normal" } })
    end

    -- Set virtual lines below the last line
    vim.api.nvim_buf_set_extmark(bufnr, ns, last_line, 0, {
      virt_lines = virt_lines,
      virt_lines_above = false,
    })
  end

  -- Apply margin with a small delay
  vim.defer_fn(add_margin, 50)
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
  local console_winid = vim.api.nvim_get_current_win()
  local bufname = format_prompt_bufname(console_winid)
  local prompt_bufnr = vim.fn.bufnr(bufname)

  -- Check if prompt window already exists
  local prompt_winid = vim.fn.bufwinid(prompt_bufnr)

  if prompt_winid == -1 then
    -- Create or get prompt buffer
    if prompt_bufnr == -1 then
      -- Create new prompt buffer with special name
      prompt_bufnr = vim.fn.bufnr(bufname, true)
    end

    local config = require("aibo").get_config()

    -- Get console window dimensions and position
    local console_width = vim.api.nvim_win_get_width(console_winid)
    local console_height = vim.api.nvim_win_get_height(console_winid)
    local console_pos = vim.api.nvim_win_get_position(console_winid)

    -- Calculate floating window position (bottom of console window)
    local float_row = console_pos[1] + console_height - config.prompt_height
    local float_col = console_pos[2]

    -- Create floating window for prompt with border
    prompt_winid = vim.api.nvim_open_win(prompt_bufnr, true, {
      relative = 'editor',
      width = console_width - 2,  -- Account for border
      height = config.prompt_height,
      row = float_row,
      col = float_col + 1,  -- Indent slightly for border alignment
      style = 'minimal',
      border = { '─', '─', '─', '', '', '', '', '' },  -- Top border only
      title = ' Prompt ',
      title_pos = 'center',
      zindex = 50,  -- Ensure it's above console
    })

    -- Set window options for prompt
    vim.wo[prompt_winid].winhighlight = 'Normal:Normal,FloatBorder:Comment,FloatTitle:Title'
    vim.wo[prompt_winid].cursorline = false
    vim.wo[prompt_winid].number = false
    vim.wo[prompt_winid].relativenumber = false
    vim.wo[prompt_winid].signcolumn = 'no'
    vim.wo[prompt_winid].wrap = true
    vim.wo[prompt_winid].linebreak = true

    -- Store console window reference in buffer variable
    vim.b[prompt_bufnr].console_winid = console_winid
  else
    -- Focus existing prompt window
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
---@param on_output? function Callback for stdout/stderr output
---@return integer job_id The job ID, or 0 on failure
local function start_terminal_job(bufnr, cmd, args, on_output)
  -- Build the command array for jobstart
  local cmd_array = { cmd }
  vim.list_extend(cmd_array, args)

  -- Setup job options with output callbacks
  local job_opts = {
    term = true,
  }

  -- Add output callbacks if provided
  if on_output then
    job_opts.on_stdout = function(...)
      vim.defer_fn(on_output, 50)
    end
    job_opts.on_stderr = function(...)
      vim.defer_fn(on_output, 50)
    end
  end

  -- Start the terminal job with proper argument handling
  -- The buffer needs to be focused for jobstart to attach the terminal
  return vim.api.nvim_buf_call(bufnr, function()
    return vim.fn.jobstart(cmd_array, job_opts)
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

  -- Create a function to update bottom margin
  local update_margin_callback = function()
    reapply_bottom_margin(bufnr)
  end

  -- Start the terminal job with output callback
  local job_id = start_terminal_job(bufnr, cmd, args, update_margin_callback)

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

  -- Add virtual lines at the end of buffer to create bottom margin
  local config = require("aibo").get_config()
  local ns = vim.api.nvim_create_namespace("aibo_console_margin")

  -- Function to add virtual lines for bottom padding
  local function add_bottom_margin()
    -- Clear existing virtual text
    vim.api.nvim_buf_clear_namespace(bufnr, ns, 0, -1)

    -- Get the last line of the buffer
    local last_line = vim.api.nvim_buf_line_count(bufnr) - 1

    -- Create virtual lines for padding
    local virt_lines = {}
    for i = 1, config.prompt_height do
      table.insert(virt_lines, { { "", "Normal" } })
    end

    -- Set virtual lines below the last line
    vim.api.nvim_buf_set_extmark(bufnr, ns, last_line, 0, {
      virt_lines = virt_lines,
      virt_lines_above = false,
    })
  end

  -- Add margin initially
  vim.defer_fn(add_bottom_margin, 100)

  -- Update margin when window focus changes or scrolls
  -- Note: Terminal output updates are handled by jobstart callbacks
  vim.api.nvim_create_autocmd({
    "WinEnter",
    "WinLeave",
    "BufWinEnter",
    "WinScrolled"
  }, {
    group = augroup,
    buffer = bufnr,
    callback = function()
      -- Debounce to avoid excessive updates
      vim.defer_fn(add_bottom_margin, 10)
    end,
  })

  -- Update floating prompt position when console window is resized
  vim.api.nvim_create_autocmd("WinResized", {
    group = augroup,
    callback = function()
      local console_win = vim.fn.bufwinid(bufnr)
      if console_win ~= -1 then
        local bufname = format_prompt_bufname(console_win)
        local prompt_bufnr = vim.fn.bufnr(bufname)
        local prompt_winid = vim.fn.bufwinid(prompt_bufnr)

        if prompt_winid ~= -1 then
          -- Update floating window position and size
          local console_width = vim.api.nvim_win_get_width(console_win)
          local console_height = vim.api.nvim_win_get_height(console_win)
          local console_pos = vim.api.nvim_win_get_position(console_win)

          vim.api.nvim_win_set_config(prompt_winid, {
            relative = 'editor',
            width = console_width - 2,
            height = config.prompt_height,
            row = console_pos[1] + console_height - config.prompt_height,
            col = console_pos[2] + 1,
          })
        end
      end
    end,
  })

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

    -- Re-apply bottom margin when showing existing console
    reapply_bottom_margin(console_bufnr)

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

    -- Re-apply bottom margin when focusing existing console
    reapply_bottom_margin(visible_in_tabpage[1].bufnr)

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

      -- Re-apply bottom margin when focusing existing console
      for _, item in ipairs(visible_in_tabpage) do
        if item.win == win_to_focus then
          reapply_bottom_margin(item.bufnr)
          break
        end
      end

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

    -- Re-apply bottom margin when showing existing console
    reapply_bottom_margin(console_bufnr)

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

---Force update bottom margin for console buffer
---@param bufnr? integer Buffer number (optional, defaults to current)
---@return nil
function M.force_update_margin(bufnr)
  bufnr = bufnr or vim.api.nvim_get_current_buf()

  -- Check if it's a console buffer
  local ft = vim.bo[bufnr].filetype or ""
  if not ft:match("^aibo%-console") then
    vim.notify("Not a console buffer", vim.log.levels.WARN, { title = "Aibo" })
    return
  end

  -- Apply margin immediately (no defer for forced update)
  local config = require("aibo").get_config()
  local ns = vim.api.nvim_create_namespace("aibo_console_margin")

  -- Clear existing virtual text
  vim.api.nvim_buf_clear_namespace(bufnr, ns, 0, -1)

  -- Get the last line of the buffer
  local last_line = vim.api.nvim_buf_line_count(bufnr) - 1

  -- Create virtual lines for padding
  local virt_lines = {}
  for i = 1, config.prompt_height do
    table.insert(virt_lines, { { "", "Normal" } })
  end

  -- Set virtual lines below the last line
  vim.api.nvim_buf_set_extmark(bufnr, ns, last_line, 0, {
    virt_lines = virt_lines,
    virt_lines_above = false,
  })

  -- Debug information
  local extmarks = vim.api.nvim_buf_get_extmarks(bufnr, ns, 0, -1, {details = true})

  vim.notify(string.format(
    "Margin updated:\n" ..
    "  Buffer: %d\n" ..
    "  Prompt height: %d\n" ..
    "  Virtual lines: %d extmarks\n" ..
    "  Last line: %d",
    bufnr,
    config.prompt_height,
    #extmarks,
    vim.api.nvim_buf_line_count(bufnr)
  ), vim.log.levels.INFO, { title = "Aibo Console Margin" })
end

---Debug console margin state
---@param bufnr? integer Buffer number (optional, defaults to current)
---@return nil
function M.debug_margin(bufnr)
  bufnr = bufnr or vim.api.nvim_get_current_buf()

  local ft = vim.bo[bufnr].filetype or ""
  if not ft:match("^aibo%-console") then
    vim.notify("Not a console buffer", vim.log.levels.WARN, { title = "Aibo" })
    return
  end

  local config = require("aibo").get_config()
  local ns = vim.api.nvim_create_namespace("aibo_console_margin")
  local extmarks = vim.api.nvim_buf_get_extmarks(bufnr, ns, 0, -1, {details = true})

  print("=== Console Margin Debug Info ===")
  print("Buffer: " .. bufnr)
  print("Filetype: " .. ft)
  print("Prompt height (config): " .. config.prompt_height)
  print("Buffer line count: " .. vim.api.nvim_buf_line_count(bufnr))
  print("Extmarks found: " .. #extmarks)

  if #extmarks > 0 then
    print("\nExtmark details:")
    for i, mark in ipairs(extmarks) do
      local id, row, col, details = mark[1], mark[2], mark[3], mark[4]
      print(string.format("  [%d] Row: %d, Col: %d", id, row, col))
      if details.virt_lines then
        print("    Virtual lines: " .. #details.virt_lines)
      end
    end
  else
    print("\n⚠ No virtual lines found!")
  end

  print("\nTo force update, run: :AiboUpdateMargin")
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
