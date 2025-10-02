--- Floating prompt window management module for AI agent interaction.
---
--- This module provides a floating window style prompt interface that appears
--- at the bottom of console windows. Unlike the traditional split window style,
--- the floating prompt:
--- - Remains visible at all times while the console is focused
--- - Overlays at the bottom of the console window
--- - Adds virtual padding to console content to prevent overlap
--- - Supports the same submission and control features as the split style
---
local M = {}
local PREFIX = "aiboprompt://"

--- Find floating window associated with a buffer
---@param bufnr number Prompt buffer number
---@return number? float_winid or nil if not found
local function find_floating_window(bufnr)
  -- Check all windows in current tabpage
  for _, winid in ipairs(vim.api.nvim_tabpage_list_wins(0)) do
    if vim.api.nvim_win_get_buf(winid) == bufnr then
      local config = vim.api.nvim_win_get_config(winid)
      -- Check if it's a floating window
      if config.relative ~= "" then
        return winid
      end
    end
  end
  return nil
end

--- Get or create namespace ID
---@param bufnr number Prompt buffer number
---@return number namespace_id
local function get_or_create_namespace(bufnr)
  local ns_id = vim.b[bufnr].aibo_floating_ns_id
  if not ns_id then
    ns_id = vim.api.nvim_create_namespace(string.format("aibo_floating_prompt_%d", bufnr))
    vim.b[bufnr].aibo_floating_ns_id = ns_id
  end
  return ns_id
end

---@param bufname string
---@return number? console_winid or nil if not a valid prompt buffer
local function parse_bufname(bufname)
  local console_winid = string.match(bufname, "^" .. vim.pesc(PREFIX) .. "(%d+)$")
  if console_winid then
    return tonumber(console_winid)
  else
    return nil
  end
end

---@param partial { winid?: number, bufnr?: number, bufname?: string }
---@return nil or {
---  winid: number,
---  bufnr: number,
---  bufname: string,
---  console_info: nil or {
---    winid: number,
---    bufnr: number,
---    jobinfo: {
---      cmd: string,
---      args: string[],
---      job_id: number,
---    },
---  }
--- } Complete info or nil if invalid
local function build_info(partial)
  local console = require("aibo.internal.console_window")

  local winid = partial.winid
  local bufnr = partial.bufnr
  local bufname
  if winid then
    if not vim.api.nvim_win_is_valid(winid) then
      return nil
    end
    bufnr = bufnr or vim.api.nvim_win_get_buf(winid)
    bufname = partial.bufname or vim.api.nvim_buf_get_name(bufnr)
  elseif bufnr then
    if not vim.api.nvim_buf_is_valid(bufnr) then
      return nil
    end
    -- フローティングウィンドウを探す
    winid = find_floating_window(bufnr) or -1
    bufname = partial.bufname or vim.api.nvim_buf_get_name(bufnr)
  else
    error("[aibo] Either winid or bufnr must be provided")
  end
  if string.sub(bufname, 1, #PREFIX) ~= PREFIX then
    return nil
  end
  local console_info = nil
  local console_winid = parse_bufname(bufname)
  if console_winid then
    console_info = console.get_info_by_winid(console_winid)
  end

  return {
    winid = winid,
    bufnr = bufnr,
    bufname = bufname,
    console_info = console_info,
  }
end

---@param bufnr number Buffer number
local function setup_mappings(bufnr)
  local aibo = require("aibo")
  local console = require("aibo.internal.console_window")

  local define = function(lhs, desc, rhs)
    vim.keymap.set({ "n", "i" }, lhs, rhs, {
      buffer = bufnr,
      desc = desc,
      silent = true,
    })
  end

  local send = function(key)
    local info = M.get_info_by_bufnr(bufnr)
    if info and info.console_info then
      local code = aibo.resolve(key) or key
      console.send(info.console_info.bufnr, code)
    end
  end

  define("<Plug>(aibo-send)", "Get one key from user and send it to associated console", function()
    vim.api.nvim_echo({ { "Oneshot (press any key): ", "MoreMsg" } }, false, {})
    local ok, char = pcall(vim.fn.getchar)
    vim.api.nvim_echo({ { "", "Normal" } }, false, {})
    if ok and char then
      local key = type(char) == "number" and vim.fn.nr2char(char) or vim.fn.keytrans(char)
      send(key)
    end
  end)
  define("<Plug>(aibo-submit)", "Submit prompt to associated console", function()
    vim.cmd("write")
  end)
end

---@param ev { buf: number, file: string }
local function BufWritePre(ev)
  vim.bo[ev.buf].modified = true
end

---@param ev { buf: number, file: string }
local function BufWriteCmd(ev)
  local info = M.get_info_by_bufnr(ev.buf)
  if not info then
    return
  end
  M.submit(info.bufnr)
end

--- Add virtual line margin at the bottom of console window
---@param console_bufnr number Console buffer number
---@param height number Height of the floating prompt (content area only)
---@param ns_id number Namespace ID for virtual lines
local function add_console_margin(console_bufnr, height, ns_id)
  if not vim.api.nvim_buf_is_valid(console_bufnr) then
    return
  end

  -- Clear existing virtual lines
  vim.api.nvim_buf_clear_namespace(console_bufnr, ns_id, 0, -1)

  -- Add virtual lines after the last line (including +2 for borders)
  local line_count = vim.api.nvim_buf_line_count(console_bufnr)
  local virtual_lines = {}
  local total_height = height + 2 -- Top and bottom borders
  for _ = 1, total_height do
    table.insert(virtual_lines, { { "", "Normal" } })
  end

  vim.api.nvim_buf_set_extmark(console_bufnr, ns_id, line_count - 1, 0, {
    virt_lines = virtual_lines,
    virt_lines_above = false,
  })
end

--- Calculate appropriate height for prompt buffer
---@param bufnr number Prompt buffer number
---@param max_height number Maximum height
---@return number height Calculated height (minimum 1, maximum max_height)
local function calculate_height(bufnr, max_height)
  local line_count = vim.api.nvim_buf_line_count(bufnr)
  -- Default to 1 line for empty buffer
  if line_count == 0 then
    return 1
  end
  -- Minimum 1 line, maximum max_height lines
  return math.max(1, math.min(line_count, max_height))
end

--- Create or update floating window
---@param console_winid number Console window ID
---@param prompt_bufnr number Prompt buffer number
---@param height number Height of the floating window
---@return number float_winid Floating window ID
local function create_or_update_float(console_winid, prompt_bufnr, height)
  -- Find existing floating window
  local existing_float = find_floating_window(prompt_bufnr)

  -- Get console window dimensions
  local console_width = vim.api.nvim_win_get_width(console_winid)
  local console_height = vim.api.nvim_win_get_height(console_winid)

  -- Total height including borders
  local total_height = height + 2 -- Top and bottom borders

  -- Floating window configuration
  local float_opts = {
    relative = "win",
    win = console_winid,
    width = console_width - 2, -- Left and right borders
    height = height,
    row = console_height - total_height,
    col = 0,
    style = "minimal",
    border = "rounded",
    focusable = true,
    zindex = 1,
    fixed = true, -- Not affected by window layout commands
  }

  local float_winid
  if existing_float and vim.api.nvim_win_is_valid(existing_float) then
    -- Update existing window
    float_winid = existing_float
    vim.api.nvim_win_set_config(float_winid, float_opts)
  else
    -- Create new floating window
    float_winid = vim.api.nvim_open_win(prompt_bufnr, false, float_opts)

    -- Set window options
    vim.wo[float_winid].winblend = 0
    vim.wo[float_winid].winhighlight = "Normal:Normal,FloatBorder:FloatBorder"
    vim.wo[float_winid].cursorline = true
    vim.wo[float_winid].wrap = true
    vim.wo[float_winid].linebreak = true
    vim.wo[float_winid].number = false
    vim.wo[float_winid].relativenumber = false
    vim.wo[float_winid].signcolumn = "no"
    vim.wo[float_winid].foldcolumn = "0"
  end

  return float_winid
end

--- Get prompt window information by buffer number.
function M.get_info_by_bufnr(bufnr)
  return build_info({ bufnr = bufnr })
end

--- Get prompt window information by window ID.
function M.get_info_by_winid(winid)
  return build_info({ winid = winid })
end

--- Get prompt window information by its associated console window ID.
function M.get_info_by_console_winid(console_winid)
  local bufname = string.format("%s%s", PREFIX, console_winid)
  local bufnr = vim.fn.bufnr(bufname)
  if bufnr == -1 then
    return nil
  end
  return build_info({ bufnr = bufnr, bufname = bufname })
end

--- Find prompt window information in the current tabpage
function M.find_info_in_tabpage()
  local console = require("aibo.internal.console_window")
  local console_info = console.find_info_in_tabpage()
  if not console_info then
    return nil
  end
  return M.get_info_by_console_winid(console_info.winid)
end

--- Update prompt window (internal use)
---@param bufnr number Prompt buffer number
local function update_prompt_window(bufnr)
  local info = M.get_info_by_bufnr(bufnr)
  if info and info.console_info and vim.api.nvim_win_is_valid(info.console_info.winid) then
    local float_winid = find_floating_window(bufnr)
    if float_winid and vim.api.nvim_win_is_valid(float_winid) then
      local max_height = vim.b[bufnr].aibo_prompt_max_height or 10
      local height = calculate_height(bufnr, max_height)
      create_or_update_float(info.console_info.winid, bufnr, height)
      local ns_id = get_or_create_namespace(bufnr)
      add_console_margin(info.console_info.bufnr, height, ns_id)
    end
  end
end

--- Open or show a floating prompt window for a console.
--- Creates a new prompt buffer or reuses an existing one. The prompt window
--- floats at the bottom of the console window.
---
--- @param console_winid number The console window ID to attach to
--- @param options? table Optional configuration:
---   - max_height?: number - Maximum height of the floating prompt (default: 10)
---   - startinsert?: boolean - Enter insert mode after opening (default: true)
--- @return nil|table Returns nil on failure, otherwise returns prompt info
function M.open(console_winid, options)
  local aibo = require("aibo")
  local integration = require("aibo.internal.integration")
  local console = require("aibo.internal.console_window")

  local console_info = console.get_info_by_winid(console_winid)
  if not console_info then
    vim.notify(
      string.format("Failed to find a valid console info from winid %d", console_winid),
      vim.log.levels.ERROR,
      { title = "Aibo floating prompt" }
    )
    return nil
  end

  options = options or {}
  local max_height = options.max_height or 10

  -- プロンプトバッファを作成または取得
  local bufname = string.format("%s%s", PREFIX, console_winid)
  local bufnr = vim.fn.bufnr(bufname)

  if bufnr == -1 then
    -- 新しいバッファを作成
    bufnr = vim.api.nvim_create_buf(false, true)
    vim.api.nvim_buf_set_name(bufnr, bufname)
  end

  -- Get or create namespace ID
  local ns_id = get_or_create_namespace(bufnr)

  -- Save max_height for later use in TextChanged
  vim.b[bufnr].aibo_prompt_max_height = max_height

  -- Calculate height based on buffer content
  local height = calculate_height(bufnr, max_height)

  -- Create or update floating window
  local float_winid = create_or_update_float(console_winid, bufnr, height)

  -- Add virtual margin to console
  add_console_margin(console_info.bufnr, height, ns_id)

  -- Setup buffer
  setup_mappings(bufnr)
  integration.setup_mappings(console_info.jobinfo.cmd, bufnr)
  vim.bo[bufnr].buftype = "acwrite"
  vim.bo[bufnr].bufhidden = "hide"
  vim.bo[bufnr].buflisted = false
  vim.bo[bufnr].swapfile = false
  vim.bo[bufnr].filetype = string.format("aibo-prompt.aibo-tool-%s", console_info.jobinfo.cmd)

  local info = {
    type = "prompt",
    cmd = console_info.jobinfo.cmd,
    args = console_info.jobinfo.args,
    job_id = console_info.jobinfo.job_id,
  }
  local buffer_cfg = aibo.get_buffer_config("prompt")
  if buffer_cfg.on_attach then
    buffer_cfg.on_attach(bufnr, info)
  end
  local tool_cfg = aibo.get_tool_config(console_info.jobinfo.cmd)
  if tool_cfg.on_attach then
    tool_cfg.on_attach(bufnr, info)
  end

  -- Insert mode
  if options.startinsert then
    vim.defer_fn(function()
      if vim.api.nvim_win_is_valid(float_winid) then
        vim.api.nvim_set_current_win(float_winid)
        vim.cmd("startinsert")
      end
    end, 0)
  end

  return {
    winid = float_winid,
    bufnr = bufnr,
    bufname = bufname,
    console_info = console_info,
  }
end

--- Hide floating prompt (internal use)
---@param bufnr number Prompt buffer number
local function hide_floating(bufnr)
  local float_winid = find_floating_window(bufnr)
  if float_winid and vim.api.nvim_win_is_valid(float_winid) then
    vim.api.nvim_win_hide(float_winid)
  end

  -- Clear virtual margin as well
  local info = M.get_info_by_bufnr(bufnr)
  if info and info.console_info then
    local ns_id = vim.b[bufnr].aibo_floating_ns_id
    if ns_id then
      vim.api.nvim_buf_clear_namespace(info.console_info.bufnr, ns_id, 0, -1)
    end
  end
end


--- Write input to a prompt buffer.
--- Inserts or replaces text in the specified prompt buffer.
---@param bufnr number The prompt buffer number to modify
---@param content string[] The text to insert (string or list of lines)
---@param options? table Optional configuration:
---  - replace?: boolean - If true, replaces entire buffer content (default: false)
---@return boolean|nil Returns true on success, nil if buffer is invalid
function M.write(bufnr, content, options)
  if M.get_info_by_bufnr(bufnr) == nil then
    vim.notify(
      string.format("Buffer %d is not a valid prompt buffer", bufnr),
      vim.log.levels.ERROR,
      { title = "Aibo floating prompt Error" }
    )
    return nil
  end

  options = options or {}

  local replace = options.replace or false
  if replace then
    vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, content)
  else
    local existing = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
    if #existing == 1 and existing[1] == "" then
      vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, content)
    else
      vim.api.nvim_buf_set_lines(bufnr, -1, -1, false, content)
    end
  end

  return true
end

--- Submit the contents of a prompt buffer to its associated console.
---@param bufnr number The prompt buffer number to submit
---@return nil Returns nil if buffer is invalid or submission fails
function M.submit(bufnr)
  local console = require("aibo.internal.console_window")

  local info = M.get_info_by_bufnr(bufnr)
  if not info or not info.console_info then
    vim.notify(
      string.format("Buffer %d is not a valid prompt buffer", bufnr),
      vim.log.levels.ERROR,
      { title = "Aibo floating prompt Error" }
    )
    return nil
  end

  local content = table.concat(vim.api.nvim_buf_get_lines(bufnr, 0, -1, false), "\n")
  vim.defer_fn(function()
    local b = info.console_info.bufnr
    if vim.api.nvim_buf_is_valid(b) then
      console.submit(b, content)
    end
  end, 0)

  -- Clear buffer
  vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, {})
  vim.bo[bufnr].modified = false

  -- Reset cursor position (if floating window is valid)
  local float_winid = find_floating_window(bufnr)
  if float_winid and vim.api.nvim_win_is_valid(float_winid) then
    vim.api.nvim_win_set_cursor(float_winid, { 1, 0 })
  end
end

--- Cleanup (internal use)
---@param bufnr number Prompt buffer number
local function cleanup(bufnr)
  hide_floating(bufnr)
  -- Clear namespace ID
  vim.b[bufnr].aibo_floating_ns_id = nil
end

-- Autocmds
local augroup = vim.api.nvim_create_augroup("aibo_prompt_floating_internal", { clear = true })

vim.api.nvim_create_autocmd("BufWritePre", {
  group = augroup,
  pattern = string.format("%s*", PREFIX),
  nested = false,
  callback = BufWritePre,
})

vim.api.nvim_create_autocmd("BufWriteCmd", {
  group = augroup,
  pattern = string.format("%s*", PREFIX),
  nested = true,
  callback = BufWriteCmd,
})

vim.api.nvim_create_autocmd("BufWipeout", {
  group = augroup,
  pattern = string.format("%s*", PREFIX),
  nested = false,
  callback = function(ev)
    cleanup(ev.buf)
  end,
})


-- Monitor prompt buffer content changes and adjust height
vim.api.nvim_create_autocmd({ "TextChanged", "TextChangedI", "TextChangedP" }, {
  group = augroup,
  pattern = string.format("%s*", PREFIX),
  nested = false,
  callback = function(ev)
    update_prompt_window(ev.buf)
  end,
})

-- Common function to update all prompt windows
local function update_all_prompts()
  for _, bufnr in ipairs(vim.api.nvim_list_bufs()) do
    if vim.api.nvim_buf_is_valid(bufnr) then
      local bufname = vim.api.nvim_buf_get_name(bufnr)
      if bufname:match("^" .. vim.pesc(PREFIX)) then
        update_prompt_window(bufnr)
      end
    end
  end
end

-- Detect multiple window layout change events
vim.api.nvim_create_autocmd({ "WinScrolled", "WinResized", "VimResized" }, {
  group = augroup,
  pattern = "*",
  nested = false,
  callback = update_all_prompts,
})

-- Update when windows are created or closed
vim.api.nvim_create_autocmd({ "WinNew", "WinClosed" }, {
  group = augroup,
  pattern = "*",
  nested = false,
  callback = function()
    vim.defer_fn(update_all_prompts, 50)
  end,
})

-- Also update on BufEnter/WinEnter (when moving between windows)
vim.api.nvim_create_autocmd({ "BufEnter", "WinEnter" }, {
  group = augroup,
  pattern = "*",
  nested = false,
  callback = update_all_prompts,
})

return M

