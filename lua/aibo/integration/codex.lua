local M = {}

---@class CodexArgument
---@field arg string The argument flag
---@field description string Description of the argument
---@field has_value boolean Whether the argument takes a value
---@field values? string[] Possible values for the argument

-- Define meaningful Codex arguments for interactive sessions
local CODEX_ARGUMENTS = {
  {
    arg = "--model",
    description = "Model the agent should use",
    has_value = true,
    values = { "o3", "claude-3.5-sonnet", "gpt-4-turbo", "gemini-pro" },
  },
  {
    arg = "-m",
    description = "Model the agent should use (short)",
    has_value = true,
    values = { "o3", "claude-3.5-sonnet", "gpt-4-turbo", "gemini-pro" },
  },
  {
    arg = "--config",
    description = "Override configuration value",
    has_value = true,
  },
  {
    arg = "-c",
    description = "Override configuration value (short)",
    has_value = true,
  },
  {
    arg = "--profile",
    description = "Configuration profile from config.toml",
    has_value = true,
  },
  {
    arg = "-p",
    description = "Configuration profile (short)",
    has_value = true,
  },
  {
    arg = "--sandbox",
    description = "Select sandbox policy for shell commands",
    has_value = true,
    values = { "none", "read-only", "restricted", "full" },
  },
  {
    arg = "-s",
    description = "Select sandbox policy (short)",
    has_value = true,
    values = { "none", "read-only", "restricted", "full" },
  },
  {
    arg = "--oss",
    description = "Use local open source model provider (Ollama)",
    has_value = false,
  },
  {
    arg = "--image",
    description = "Attach image(s) to initial prompt",
    has_value = true,
  },
  {
    arg = "-i",
    description = "Attach image(s) (short)",
    has_value = true,
  },
  {
    arg = "resume",
    description = "Resume a previous session",
    has_value = false,
    is_subcommand = true,
  },
  {
    arg = "resume --last",
    description = "Resume the most recent session",
    has_value = false,
    is_subcommand = true,
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

---Add subcommand completions to the list
---@param completions string[] The completions list to append to
---@param prefix string The prefix to match (empty string matches all)
local function add_subcommand_completions(completions, prefix)
  -- Handle "resume" subcommand
  if prefix == "" or string.find("resume", "^" .. vim.pesc(prefix)) then
    table.insert(completions, "resume")
  end

  -- Handle "resume --last" as a special case
  if prefix == "" or string.find("resume --last", "^" .. vim.pesc(prefix)) then
    table.insert(completions, "resume --last")
  end
end

---Add argument completions to the list
---@param completions string[] The completions list to append to
---@param prefix string The prefix to match (empty string matches all)
local function add_argument_completions(completions, prefix)
  for _, arg_info in ipairs(CODEX_ARGUMENTS) do
    if not arg_info.is_subcommand then
      if prefix == "" or arg_info.arg:find("^" .. vim.pesc(prefix)) then
        table.insert(completions, arg_info.arg)
      end
    end
  end
end

---Get value completions for a specific argument
---@param arg string The argument that needs a value
---@param prefix string The prefix to match
---@return string[]|nil Completions if found, nil otherwise
local function get_value_completions(arg, prefix)
  for _, arg_info in ipairs(CODEX_ARGUMENTS) do
    if not arg_info.is_subcommand and arg_matches(arg, arg_info) and arg_info.has_value then
      if arg_info.values then
        -- Complete from predefined values
        local completions = {}
        for _, value in ipairs(arg_info.values) do
          if prefix == "" or value:find("^" .. vim.pesc(prefix)) then
            table.insert(completions, value)
          end
        end
        return completions
      elseif arg_info.arg == "--image" or arg_info.arg == "-i" then
        -- Complete image files
        return vim.fn.getcompletion(prefix, "file")
      else
        -- No specific completion available
        return {}
      end
    end
  end
  return nil
end

---Get completion candidates for Codex command arguments
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

  -- Add subcommand completions
  add_subcommand_completions(completions, arglead)

  -- Add argument completions
  add_argument_completions(completions, arglead)

  return completions
end

---Check if codex command is available
---@return boolean
function M.is_available()
  return vim.fn.executable("codex") == 1
end

---Get help text for Codex arguments
---@return string[]
function M.get_help()
  local help = {}
  table.insert(help, "Codex arguments for interactive sessions:")
  table.insert(help, "")

  for _, arg_info in ipairs(CODEX_ARGUMENTS) do
    if not arg_info.is_subcommand then
      local line = string.format("  %-25s %s", arg_info.arg, arg_info.description)
      if arg_info.values then
        line = line .. " [" .. table.concat(arg_info.values, ", ") .. "]"
      end
      table.insert(help, line)
    end
  end

  table.insert(help, "")
  table.insert(help, "Subcommands:")
  table.insert(help, "  resume                    Resume a previous session")
  table.insert(help, "  resume --last             Resume the most recent session")

  return help
end

return M
