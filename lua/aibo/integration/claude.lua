local M = {}

---@class ClaudeArgument
---@field arg string The argument flag
---@field description string Description of the argument
---@field has_value boolean Whether the argument takes a value
---@field values? string[] Possible values for the argument

-- Define meaningful Claude arguments for interactive sessions
local CLAUDE_ARGUMENTS = {
  {
    arg = "--continue",
    description = "Continue the most recent conversation",
    has_value = false,
  },
  {
    arg = "-c",
    description = "Continue the most recent conversation (short)",
    has_value = false,
  },
  {
    arg = "--resume",
    description = "Resume a conversation",
    has_value = true,
  },
  {
    arg = "-r",
    description = "Resume a conversation (short)",
    has_value = true,
  },
  {
    arg = "--fork-session",
    description = "Create new session ID when resuming",
    has_value = false,
  },
  {
    arg = "--verbose",
    description = "Override verbose mode setting",
    has_value = false,
  },
  {
    arg = "--model",
    description = "Model for the session",
    has_value = true,
    values = {
      "sonnet",
      "opus",
      "haiku",
      "claude-3-5-sonnet-latest",
      "claude-3-5-haiku-latest",
      "claude-3-opus-latest",
    },
  },
  {
    arg = "--permission-mode",
    description = "Permission mode for the session",
    has_value = true,
    values = { "default", "acceptEdits", "bypassPermissions", "plan" },
  },
  {
    arg = "--add-dir",
    description = "Additional directories to allow tool access",
    has_value = true,
  },
  {
    arg = "--ide",
    description = "Auto-connect to IDE on startup",
    has_value = false,
  },
  {
    arg = "--debug",
    description = "Enable debug mode",
    has_value = true,
  },
  {
    arg = "--settings",
    description = "Path to settings JSON file",
    has_value = true,
  },
  {
    arg = "--append-system-prompt",
    description = "Append to system prompt",
    has_value = true,
  },
  {
    arg = "--allowed-tools",
    description = "Comma-separated list of tools to allow",
    has_value = true,
  },
  {
    arg = "--disallowed-tools",
    description = "Comma-separated list of tools to deny",
    has_value = true,
  },
}

---Parse command line into parts
---@param cmdline string The full command line
---@return string[] The parsed parts
local function parse_command(cmdline)
  local parts = {}
  for part in cmdline:gmatch("%S+") do
    table.insert(parts, part)
  end
  return parts
end

---Check if an argument matches (handling both long and short forms)
---@param arg string The argument to check
---@param arg_info table The argument info containing the arg field
---@return boolean True if the argument matches
local function arg_matches(arg, arg_info)
  -- Check exact match or short form match
  return arg == arg_info.arg or arg == arg_info.arg:gsub("%-%-", "-")
end

---Add argument completions to the list
---@param completions string[] The completions list to append to
---@param prefix string The prefix to match (empty string matches all)
local function add_argument_completions(completions, prefix)
  for _, arg_info in ipairs(CLAUDE_ARGUMENTS) do
    if prefix == "" or arg_info.arg:find("^" .. vim.pesc(prefix)) then
      table.insert(completions, arg_info.arg)
    end
  end
end

---Add value completions for a specific argument
---@param arg string The argument that needs a value
---@param prefix string The prefix to match
---@return string[]|nil Completions if found, nil otherwise
local function get_value_completions(arg, prefix)
  for _, arg_info in ipairs(CLAUDE_ARGUMENTS) do
    if arg_matches(arg, arg_info) and arg_info.has_value then
      if arg_info.values then
        -- Complete from predefined values
        local completions = {}
        for _, value in ipairs(arg_info.values) do
          if prefix == "" or value:find("^" .. vim.pesc(prefix)) then
            table.insert(completions, value)
          end
        end
        return completions
      elseif arg_info.arg == "--add-dir" then
        -- Complete directories
        return vim.fn.getcompletion(prefix, "dir")
      elseif arg_info.arg == "--settings" then
        -- Complete files
        return vim.fn.getcompletion(prefix, "file")
      else
        -- No specific completion available
        return {}
      end
    end
  end
  return nil
end

---Get completion candidates for Claude command arguments
---@param arglead string Current argument being typed
---@param cmdline string Full command line
---@param cursorpos integer Cursor position
---@return string[] Completion candidates
function M.get_command_completions(arglead, cmdline, cursorpos)
  local completions = {}

  -- Parse the command line
  local parts = parse_command(cmdline)
  local part_count = #parts

  -- Check if we're completing a value for the previous argument
  if part_count >= 3 then
    local prev_arg
    if arglead == parts[part_count] then
      -- We're completing the current partial argument
      prev_arg = parts[part_count - 1] or ""
    else
      -- We have a trailing space, check the last complete argument
      prev_arg = parts[part_count] or ""
    end

    local value_completions = get_value_completions(prev_arg, arglead)
    if value_completions then
      return value_completions
    end
  end

  -- Otherwise, complete argument names
  add_argument_completions(completions, arglead)

  return completions
end

---Check if claude command is available
---@return boolean
function M.is_available()
  return vim.fn.executable("claude") == 1
end

---Get help text for Claude arguments
---@return string[]
function M.get_help()
  local help = {}
  table.insert(help, "Claude arguments for interactive sessions:")
  table.insert(help, "")

  for _, arg_info in ipairs(CLAUDE_ARGUMENTS) do
    local line = string.format("  %-25s %s", arg_info.arg, arg_info.description)
    if arg_info.values then
      line = line .. " [" .. table.concat(arg_info.values, ", ") .. "]"
    end
    table.insert(help, line)
  end

  return help
end

return M
