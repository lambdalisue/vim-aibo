local M = {}

--- Parse a command-line string into arguments, handling quoted strings
--- This function mimics shell-like argument parsing where:
--- - Arguments can be separated by spaces
--- - Single-quoted strings: treated as literal (no escape sequences)
--- - Double-quoted strings: escape sequences are interpreted
--- - Quotes can be escaped with backslash
---@param cmdline string The command line to parse
---@return string[] The parsed arguments
function M.parse_cmdline(cmdline)
  local args = {}
  local current_arg = ""
  local in_single_quotes = false
  local in_double_quotes = false
  local escaped = false

  for i = 1, #cmdline do
    local char = cmdline:sub(i, i)

    if escaped then
      if in_double_quotes then
        -- In double quotes, interpret escape sequences
        if char == "n" then
          current_arg = current_arg .. "\n"
        elseif char == "t" then
          current_arg = current_arg .. "\t"
        elseif char == "r" then
          current_arg = current_arg .. "\r"
        elseif char == "\\" then
          current_arg = current_arg .. "\\"
        elseif char == '"' then
          current_arg = current_arg .. '"'
        else
          -- Unknown escape sequence, keep the backslash
          current_arg = current_arg .. "\\" .. char
        end
      elseif in_single_quotes then
        -- In single quotes, only \' is special
        if char == "'" then
          current_arg = current_arg .. "'"
        else
          -- Everything else is literal, including the backslash
          current_arg = current_arg .. "\\" .. char
        end
      else
        -- Outside quotes, treat as literal escaped character
        current_arg = current_arg .. char
      end
      escaped = false
    elseif char == "\\" then
      -- Backslash starts escape sequence
      escaped = true
    elseif char == "'" and not in_double_quotes and not escaped then
      -- Toggle single quote state
      in_single_quotes = not in_single_quotes
    elseif char == '"' and not in_single_quotes and not escaped then
      -- Toggle double quote state
      in_double_quotes = not in_double_quotes
    elseif char == " " and not in_single_quotes and not in_double_quotes then
      -- Space outside quotes means end of argument
      if current_arg ~= "" then
        table.insert(args, current_arg)
        current_arg = ""
      end
    else
      -- Regular character
      current_arg = current_arg .. char
    end
  end

  -- Handle any remaining escaped state
  if escaped then
    current_arg = current_arg .. "\\"
  end

  -- Add the last argument if any
  if current_arg ~= "" then
    table.insert(args, current_arg)
  end

  return args
end

--- Parse option arguments like -key=value, supporting quoted values
--- This handles:
--- - Simple flags: -flag
--- - Key-value pairs: -key=value
--- - Quoted values: -key="value with spaces"
---@param args string[] Array of arguments (from fargs or parse_cmdline)
---@return table options Table of parsed options
---@return string[] remaining Array of non-option arguments
function M.parse_options(args)
  local options = {}
  local remaining = {}

  for _, arg in ipairs(args) do
    if arg:sub(1, 1) == "-" then
      -- This is an option
      local eq_pos = arg:find("=")
      if eq_pos then
        -- Key-value option
        local key = arg:sub(2, eq_pos - 1)
        local value = arg:sub(eq_pos + 1)
        options[key] = value
      else
        -- Flag option
        local key = arg:sub(2)
        options[key] = true
      end
    else
      -- Not an option
      table.insert(remaining, arg)
    end
  end

  return options, remaining
end

--- Convert options table back to command-line arguments
--- Useful for reconstructing command lines with proper quoting
---@param options table Options table
---@param remaining string[]? Non-option arguments
---@return string[] Array of arguments
function M.options_to_args(options, remaining)
  local args = {}

  -- Add options
  for key, value in pairs(options) do
    if value == true then
      -- Flag option
      table.insert(args, "-" .. key)
    else
      -- Key-value option - quote if contains spaces
      local val_str = tostring(value)
      if val_str:find(" ") then
        table.insert(args, string.format('-%s="%s"', key, val_str))
      else
        table.insert(args, string.format("-%s=%s", key, val_str))
      end
    end
  end

  -- Add remaining arguments
  if remaining then
    for _, arg in ipairs(remaining) do
      table.insert(args, arg)
    end
  end

  return args
end

--- Parse fargs handling both vim's native parsing and quoted strings
--- When vim.cmd is used with quotes, Vim may handle them differently
--- This function normalizes the behavior
---@param fargs string[] The fargs from command
---@return table options Parsed options
---@return string[] remaining Non-option arguments
function M.parse_fargs(fargs)
  -- First, reconstruct the command line from fargs
  -- This is needed because Vim might split quoted arguments incorrectly
  local needs_reparsing = false
  for _, arg in ipairs(fargs) do
    -- Check if any argument contains a quote or looks like a partial quoted string
    if arg:find('"') or (arg:match("^%-[^=]+=") and not arg:match("=$")) then
      needs_reparsing = true
      break
    end
  end

  if needs_reparsing then
    -- Reconstruct and reparse
    local cmdline = table.concat(fargs, " ")
    local reparsed = M.parse_cmdline(cmdline)
    return M.parse_options(reparsed)
  else
    -- Use fargs as-is
    return M.parse_options(fargs)
  end
end

return M
