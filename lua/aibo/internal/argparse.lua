local M = {}

--- Strip surrounding quotes from a value
---@param value string The value to strip quotes from
---@return string The value without surrounding quotes
local function strip_quotes(value)
  if (value:sub(1, 1) == "'" and value:sub(-1) == "'") or (value:sub(1, 1) == '"' and value:sub(-1) == '"') then
    return value:sub(2, -2)
  end
  return value
end

--- Check if a value is a broken quoted string (quote opened but not closed)
---@param value string The value to check
---@return boolean is_broken
---@return string|nil quote_type
local function is_broken_quote(value)
  -- Empty quote
  if value == '"' or value == "'" then
    return true, value
  end
  -- Starts with quote but doesn't end with same quote
  if value:sub(1, 1) == '"' and value:sub(-1) ~= '"' then
    return true, '"'
  end
  if value:sub(1, 1) == "'" and value:sub(-1) ~= "'" then
    return true, "'"
  end
  return false, nil
end

--- Continue collecting a broken quoted value across arguments
---@param collected string The value collected so far
---@param quote_type string The type of quote (' or ")
---@param next_arg string The next argument to add
---@return boolean is_complete
---@return string value
local function continue_broken_quote(collected, quote_type, next_arg)
  local combined = collected .. " " .. next_arg
  -- Check if this argument ends with the closing quote
  if next_arg:sub(-1) == quote_type then
    -- Remove opening and closing quotes and return completed value
    return true, combined:sub(2, -2)
  end
  -- Still collecting
  return false, combined
end

--- Extract key from an option argument
---@param arg string The argument (e.g., "-key=value" or "--key=value")
---@return string|nil key
---@return number|nil eq_pos
local function extract_option_key(arg)
  if arg:sub(1, 1) ~= "-" then
    return nil, nil
  end

  local eq_pos = arg:find("=")
  local key
  if eq_pos then
    key = arg:sub(2, eq_pos - 1)
  else
    key = arg:sub(2)
  end

  -- Handle double dash
  if key:sub(1, 1) == "-" then
    key = key:sub(2)
  end

  return key, eq_pos
end

--- Process a known option and extract its value
---@param arg string The full argument
---@param key string The option key
---@param eq_pos number|nil Position of = in arg
---@return string|boolean|nil value
---@return table|nil partial_state
local function process_option_value(arg, key, eq_pos)
  if not eq_pos then
    -- Flag option
    return true, nil
  end

  -- Key-value option
  local value = arg:sub(eq_pos + 1)
  local is_broken, quote_type = is_broken_quote(value)

  if is_broken then
    -- Start collecting broken quoted value
    return nil, {
      key = key,
      collected = value,
      quote_type = quote_type,
    }
  end

  -- Complete value - strip quotes if present
  return strip_quotes(value), nil
end

--- Parse arguments from vim command fargs or other sources
--- Options must come before positional arguments
--- Parsing stops at: first non-option, unknown option, or --
---@param args string[] The arguments to parse
---@param opts {known_options: table<string, boolean>} Parsing options
---@return table options Parsed options
---@return string[] remaining Non-option arguments
function M.parse(args, opts)
  assert(opts and opts.known_options, "parse requires opts.known_options to be specified")
  local known_options = opts.known_options

  local options = {}
  local remaining = {}
  local partial_state = nil -- For handling broken quoted options
  local stop_parsing = false -- Stop parsing options after first non-option or --

  for _, arg in ipairs(args) do
    if stop_parsing then
      -- Everything after stop_parsing goes to remaining
      table.insert(remaining, arg)
    elseif partial_state then
      -- Continue collecting broken quoted value
      local is_complete, value = continue_broken_quote(partial_state.collected, partial_state.quote_type, arg)

      if is_complete then
        options[partial_state.key] = value
        partial_state = nil
      else
        partial_state.collected = value
      end
    elseif arg == "--" then
      -- Special separator: stop parsing options
      stop_parsing = true
    elseif arg:sub(1, 1) == "-" then
      -- Option-like argument
      local key, eq_pos = extract_option_key(arg)

      if not key or known_options[key] == nil then
        -- Unknown option - stop parsing
        stop_parsing = true
        table.insert(remaining, arg)
      else
        -- Known option - process it
        local value, partial = process_option_value(arg, key, eq_pos)
        if partial then
          partial_state = partial
        elseif value then
          options[key] = value
        end
      end
    else
      -- Non-option argument - stop parsing
      stop_parsing = true
      table.insert(remaining, arg)
    end
  end

  return options, remaining
end

--- Get available option completions based on known options and what's already used
--- @param arglead string Current argument being completed
--- @param cmdline string Full command line
--- @param known_options table Known options configuration
--- @return string[] Available completions
function M.get_option_completions(arglead, cmdline, known_options)
  if arglead ~= "" and not arglead:match("^%-") then
    return {}
  end

  -- Build list of available options
  local available = {}
  for option_name, has_value in pairs(known_options) do
    if has_value then
      table.insert(available, "-" .. option_name .. "=")
    else
      table.insert(available, "-" .. option_name)
    end
  end

  -- Find which options have already been used
  local used_options = {}
  -- Check for options with values (key=value)
  for opt in cmdline:gmatch("%-([%w]+)=") do
    used_options[opt] = true
  end
  -- Check for standalone flags
  for opt in cmdline:gmatch("%-([%w]+)%s") do
    used_options[opt] = true
  end
  -- Check for flags at end of line
  for opt in cmdline:gmatch("%-([%w]+)$") do
    used_options[opt] = true
  end

  -- Filter out used options
  available = vim.tbl_filter(function(opt)
    local option_name = opt:match("^%-([%w]+)")
    return not used_options[option_name]
  end, available)

  -- Filter by arglead if not empty
  if arglead ~= "" then
    return vim.tbl_filter(function(val)
      return val:find("^" .. vim.pesc(arglead))
    end, available)
  end

  return available
end

--- Parse command line and determine position for completion
--- @param cmdline string Full command line
--- @param known_options table Known options configuration
--- @return table Parsed state with options, remaining args, and completion context
function M.parse_for_completion(cmdline, known_options)
  local parts = vim.split(cmdline, "%s+")
  if #parts == 0 then
    return { options = {}, remaining = {}, at_options = true }
  end

  -- Remove command name
  table.remove(parts, 1)

  local options, remaining = M.parse(parts, { known_options = known_options })

  return {
    options = options,
    remaining = remaining,
    at_options = #remaining == 0 or (#parts > 0 and parts[#parts]:match("^%-")),
  }
end

return M
