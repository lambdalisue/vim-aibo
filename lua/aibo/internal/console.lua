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

---Check if a buffer is visible in any window
---@param bufnr integer Buffer number
---@return integer|nil Window ID if visible, nil otherwise
local function find_buffer_window(bufnr)
  for _, win in ipairs(vim.api.nvim_list_wins()) do
    if vim.api.nvim_win_get_buf(win) == bufnr then
      return win
    end
  end
  return nil
end

---Check if a buffer is visible in the current tabpage
---@param bufnr integer Buffer number
---@return integer|nil Window ID if visible in current tabpage, nil otherwise
local function find_buffer_window_in_tabpage(bufnr)
  local tabpage = vim.api.nvim_get_current_tabpage()
  local wins = vim.api.nvim_tabpage_list_wins(tabpage)
  for _, win in ipairs(wins) do
    if vim.api.nvim_win_get_buf(win) == bufnr then
      return win
    end
  end
  return nil
end

---Follow terminal output to bottom
---@param winid integer Window ID
---@return nil
local function follow(bufnr)
  local winid = vim.fn.bufwinid(bufnr)
  if winid == -1 then
    return
  end
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
---@param opener? string Optional window opener command (e.g., "20vsplit", "tabedit")
---@param stay? boolean Whether to stay in the original window after opening
---@return nil
function M.open(cmd, args, opener, stay)
  -- Save the current window if we need to stay
  local orig_win = nil
  if stay then
    orig_win = vim.api.nvim_get_current_win()
  end

  local open_cmd = opener or ""
  if open_cmd ~= "" then
    open_cmd = open_cmd .. " | "
  end
  vim.cmd(open_cmd .. "silent terminal " .. cmd .. " " .. table.concat(args, " "))

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
      follow(bufnr)
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

  -- Call on_attach callbacks AFTER ftplugin files have run
  local aibo_module = require("aibo")
  local info = {
    type = "console",
    agent = cmd,
    aibo = vim.b.aibo,
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

  follow(winid)
  InsertEnter()

  -- Restore focus to original window if stay option is set
  if stay and orig_win and vim.api.nvim_win_is_valid(orig_win) then
    vim.api.nvim_set_current_win(orig_win)
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
    local win_id = find_buffer_window_in_tabpage(bufnr)
    if win_id then
      table.insert(visible_in_tabpage, { bufnr = bufnr, win = win_id })
    end
  end

  -- If exactly one visible console in current tabpage, toggle it
  if #visible_in_tabpage == 1 then
    -- Hide the visible console
    vim.api.nvim_win_close(visible_in_tabpage[1].win, false)
    return true
  elseif #visible_in_tabpage > 1 then
    -- Multiple visible consoles in tabpage, let user choose which to hide
    local choices = {}
    local bufnr_map = {}

    for _, item in ipairs(visible_in_tabpage) do
      local bufnr = item.bufnr
      local display = string.format("Buffer %d (Window %d)", bufnr, item.win)
      table.insert(choices, display)
      bufnr_map[display] = item.win
    end

    vim.ui.select(choices, {
      prompt = "Select console to hide:",
      format_item = function(item) return item end,
    }, function(choice)
      if choice and bufnr_map[choice] then
        vim.api.nvim_win_close(bufnr_map[choice], false)
      end
    end)
    return true
  end

  -- No visible consoles in current tabpage, need to show one
  local console_bufnr = nil

  if #matching_buffers == 1 then
    -- Only one matching console, use it
    console_bufnr = matching_buffers[1]
  else
    -- Multiple matching consoles, let user choose
    local choices = {}
    local bufnr_map = {}

    for _, bufnr in ipairs(matching_buffers) do
      local display = string.format("Buffer %d", bufnr)
      -- Add status if visible in another tabpage
      local win = find_buffer_window(bufnr)
      if win then
        display = display .. " (visible in another tab)"
      end
      table.insert(choices, display)
      bufnr_map[display] = bufnr
    end

    -- Use synchronous selection
    local selected = nil
    vim.ui.select(choices, {
      prompt = "Select console to show:",
      format_item = function(item) return item end,
    }, function(choice)
      if choice then
        selected = bufnr_map[choice]
      end
    end)

    console_bufnr = selected
  end

  if console_bufnr then
    -- Show the selected console
    local open_cmd = opener or "split"
    vim.cmd(open_cmd .. " | buffer " .. console_bufnr)

    -- Enter insert mode when console becomes visible (unless stay option is set)
    if not stay then
      vim.cmd("startinsert")
    end

    -- Restore focus to original window if stay option is set
    if stay and orig_win and vim.api.nvim_win_is_valid(orig_win) then
      vim.api.nvim_set_current_win(orig_win)
    end
  end

  return true
end

return M
