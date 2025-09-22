local M = {}

---Find all console buffers in the current tabpage
---@return table<integer, string> Map of buffer numbers to display names
local function find_console_buffers()
  local tabpage = vim.api.nvim_get_current_tabpage()
  local wins = vim.api.nvim_tabpage_list_wins(tabpage)
  local console_buffers = {}

  for _, win in ipairs(wins) do
    local bufnr = vim.api.nvim_win_get_buf(win)
    local ft = vim.bo[bufnr].filetype
    if ft and ft:match("^aibo%-console") then
      local aibo = vim.b[bufnr].aibo
      if aibo then
        -- Create display name with command and args
        local display = aibo.cmd
        if aibo.args and #aibo.args > 0 then
          display = display .. " " .. table.concat(aibo.args, " ")
        end
        console_buffers[bufnr] = display
      end
    end
  end

  return console_buffers
end

---Find prompt buffer for a console buffer
---@param console_bufnr integer Console buffer number
---@return integer|nil, integer|nil Prompt buffer number and console window ID (or nil if not found)
local function find_prompt_bufnr(console_bufnr)
  -- Get the window ID of the console buffer
  local console_winid = vim.fn.bufwinid(console_bufnr)
  local actual_console_winid = console_winid
  if console_winid == -1 then
    -- Console buffer is not visible, but we can still find/create the prompt buffer
    -- Find the first window showing this console buffer across all tabpages
    for _, tabpage in ipairs(vim.api.nvim_list_tabpages()) do
      for _, win in ipairs(vim.api.nvim_tabpage_list_wins(tabpage)) do
        if vim.api.nvim_win_get_buf(win) == console_bufnr then
          console_winid = win
          actual_console_winid = win
          break
        end
      end
      if console_winid ~= -1 then
        break
      end
    end

    -- If still not found, use a placeholder window ID
    if console_winid == -1 then
      -- Use the console buffer number as a unique identifier
      console_winid = console_bufnr
      actual_console_winid = nil
    end
  end

  local prompt_bufname = string.format("aiboprompt://%d", console_winid)
  local prompt_bufnr = vim.fn.bufnr(prompt_bufname)

  if prompt_bufnr == -1 then
    -- Create the prompt buffer if it doesn't exist
    prompt_bufnr = vim.api.nvim_create_buf(false, true)
    vim.api.nvim_buf_set_name(prompt_bufnr, prompt_bufname)

    -- Initialize the prompt buffer
    local prompt_module = require("aibo.internal.prompt")
    prompt_module.init(prompt_bufnr)
  end

  return prompt_bufnr, actual_console_winid
end

---Send content to a prompt buffer
---@param content string|string[] Content to send (string or array of lines)
---@param prompt_bufnr integer Prompt buffer number
---@param replace boolean Whether to replace existing content or append
local function send_to_prompt(content, prompt_bufnr, replace)
  local lines
  if type(content) == "string" then
    lines = vim.split(content, "\n", { plain = true })
  else
    lines = content
  end

  if replace then
    -- Replace entire buffer content
    vim.api.nvim_buf_set_lines(prompt_bufnr, 0, -1, false, lines)
  else
    -- Get existing content in prompt buffer
    local existing = vim.api.nvim_buf_get_lines(prompt_bufnr, 0, -1, false)

    -- If prompt buffer is not empty, append to existing content
    if #existing == 1 and existing[1] == "" then
      vim.api.nvim_buf_set_lines(prompt_bufnr, 0, -1, false, lines)
    else
      -- Append with newline separation
      vim.api.nvim_buf_set_lines(prompt_bufnr, -1, -1, false, lines)
    end
  end
end

---Send buffer content to aibo console
---@param opts table Options with start_line, end_line, input, submit, replace
function M.send(opts)
  opts = opts or {}
  local start_line = opts.line1 or 1
  local end_line = opts.line2 or vim.api.nvim_buf_line_count(0)
  local input = opts.input or false
  local submit = opts.submit or false
  local replace = opts.replace or false

  -- Get the content to send
  local lines = vim.api.nvim_buf_get_lines(0, start_line - 1, end_line, false)
  local content = table.concat(lines, "\n")

  -- Find all console buffers in current tabpage
  local console_buffers = find_console_buffers()

  if vim.tbl_isempty(console_buffers) then
    vim.notify("No Aibo console buffers found in current tabpage", vim.log.levels.ERROR, { title = "Aibo" })
    return
  end

  local console_bufnr

  -- If only one console buffer, use it directly
  if vim.tbl_count(console_buffers) == 1 then
    console_bufnr = next(console_buffers)
  else
    -- Multiple console buffers, let user select
    local choices = {}
    local bufnr_map = {}

    for bufnr, display in pairs(console_buffers) do
      table.insert(choices, display)
      bufnr_map[display] = bufnr
    end

    vim.ui.select(choices, {
      prompt = "Select Aibo console to send to:",
      format_item = function(item)
        return item
      end,
    }, function(choice)
      if choice then
        console_bufnr = bufnr_map[choice]
      end
    end)

    -- If user cancelled selection
    if not console_bufnr then
      return
    end
  end

  -- Find or create the prompt buffer for the selected console
  local prompt_bufnr, console_winid = find_prompt_bufnr(console_bufnr)
  if not prompt_bufnr then
    vim.notify("Failed to find/create prompt buffer", vim.log.levels.ERROR, { title = "Aibo" })
    return
  end

  -- Send the content
  send_to_prompt(content, prompt_bufnr, replace)

  -- Warn if both input and submit are specified
  if input and submit then
    vim.notify(
      "Both -input and -submit specified. -submit takes precedence.",
      vim.log.levels.WARN,
      { title = "Aibo" }
    )
  end

  -- Function to position cursor at the end of prompt buffer content
  local function position_cursor_at_end()
    for _, win in ipairs(vim.api.nvim_list_wins()) do
      if vim.api.nvim_win_get_buf(win) == prompt_bufnr then
        local line_count = vim.api.nvim_buf_line_count(prompt_bufnr)
        local last_line = vim.api.nvim_buf_get_lines(prompt_bufnr, line_count - 1, line_count, false)[1] or ""
        local col = vim.fn.strdisplaywidth(last_line)
        vim.api.nvim_win_set_cursor(win, { line_count, col })
      end
    end
  end

  -- If submit option is enabled, save current window, submit content, and return
  if submit and console_winid then
    -- Save current window to return to after submission
    local orig_win = vim.api.nvim_get_current_win()

    -- Focus the console window
    vim.api.nvim_set_current_win(console_winid)

    -- Enter insert mode to trigger prompt window opening
    vim.cmd("startinsert")

    -- Schedule the :wq command to run after the prompt window is opened
    vim.schedule(function()
      -- Check if we're in a prompt buffer window
      local current_buf = vim.api.nvim_get_current_buf()
      local bufname = vim.api.nvim_buf_get_name(current_buf)
      if bufname:match("^aiboprompt://") then
        -- Use :wq to submit the prompt content (this triggers BufWriteCmd)
        vim.cmd("wq")
        -- Focus back to the original window
        vim.schedule(function()
          if vim.api.nvim_win_is_valid(orig_win) then
            vim.api.nvim_set_current_win(orig_win)
          end
        end)
      end
    end)
  -- If input option is enabled, focus the console window and trigger insert mode
  elseif input and console_winid then
    -- Focus the console window
    vim.api.nvim_set_current_win(console_winid)

    -- Enter insert mode on the console window
    -- This will trigger the InsertEnter autocmd which handles:
    -- - Opening/focusing the prompt window
    -- - Entering insert mode in the prompt
    vim.cmd("startinsert")

    -- Schedule cursor positioning after prompt window opens
    vim.schedule(function()
      position_cursor_at_end()
    end)
  else
    -- Just position cursor if prompt window is already visible
    position_cursor_at_end()
  end
end

return M