if vim.g.loaded_aibo then
  return
end
vim.g.loaded_aibo = 1

-- Check Neovim version (silently skip if not satisfied)
if vim.fn.has("nvim-0.10.0") ~= 1 then
  return
end

-- Create autocmd for aiboprompt:// URIs
local augroup = vim.api.nvim_create_augroup("aibo_plugin", { clear = true })
vim.api.nvim_create_autocmd("BufReadCmd", {
  group = augroup,
  pattern = "aiboprompt://*",
  nested = true,
  callback = function()
    local bufnr = vim.fn.expand("<abuf>")
    require("aibo.internal.prompt").init(tonumber(bufnr))
  end,
})

-- Store completion function globally for testing
_G._aibo_complete = function(arglead, cmdline, cursorpos)
  -- Parse command line to get the AI tool
  local parts = vim.split(cmdline, "%s+")

  -- Check if we're completing the -opener= option
  if arglead:match("^-opener") then
    -- Common window opener commands
    local openers = {
      "-opener=split",
      "-opener=vsplit",
      "-opener=tabedit",
      "-opener=edit",
      "-opener=topleft\\ split",
      "-opener=topleft\\ vsplit",
      "-opener=botright\\ split",
      "-opener=botright\\ vsplit",
      "-opener=leftabove\\ split",
      "-opener=leftabove\\ vsplit",
      "-opener=rightbelow\\ split",
      "-opener=rightbelow\\ vsplit",
    }
    if arglead == "-opener=" then
      return openers
    end
    return vim.tbl_filter(function(val)
      return val:find("^" .. vim.pesc(arglead))
    end, openers)
  end

  -- Skip -opener=... when looking for the tool
  local tool_index = 2
  if parts[2] and parts[2]:match("^-opener=") then
    tool_index = 3
  end

  -- If we're still on the first argument (the AI tool name)
  -- Only complete tool names if we're at the right position or if parts[tool_index] isn't a known tool
  local known_tools = { "claude", "codex", "ollama" }
  local is_known_tool = vim.tbl_contains(known_tools, parts[tool_index] or "")

  if #parts <= tool_index or (not is_known_tool and arglead:match("^%w")) then
    -- Also offer -opener= if we're at the beginning
    if #parts == 2 and arglead:match("^%-") then
      return { "-opener=" }
    end
    -- Basic completion for common AI tools
    if arglead == "" then
      return known_tools
    end
    return vim.tbl_filter(function(val)
      return val:find("^" .. vim.pesc(arglead))
    end, known_tools)
  end

  -- Provide tool-specific argument completions based on the AI tool
  local tool = parts[tool_index]

  -- Strip "Aibo " prefix to pass cleaner cmdline to integrations
  -- This allows adding Aibo options between "Aibo" and the tool name in the future
  -- e.g., "Aibo -opener=split ollama run ..." -> "ollama run ..."
  local tool_cmdline = cmdline:gsub("^Aibo%s+", "")
  -- Also strip the -opener=... option if present
  if parts[2] and parts[2]:match("^-opener=") then
    tool_cmdline = tool_cmdline:gsub("^%-opener=[^%s]+%s+", "")
  end
  local tool_cursorpos = cursorpos - #("Aibo ")
  if tool_cursorpos < 0 then
    tool_cursorpos = 0
  end

  if tool == "claude" then
    local ok, integration = pcall(require, "aibo.integration.claude")
    if ok and integration.get_command_completions then
      local comp_ok, completions = pcall(integration.get_command_completions, arglead, tool_cmdline, tool_cursorpos)
      if comp_ok then
        return completions
      end
    end
  elseif tool == "codex" then
    local ok, integration = pcall(require, "aibo.integration.codex")
    if ok and integration.get_command_completions then
      local comp_ok, completions = pcall(integration.get_command_completions, arglead, tool_cmdline, tool_cursorpos)
      if comp_ok then
        return completions
      end
    end
  elseif tool == "ollama" then
    local ok, integration = pcall(require, "aibo.integration.ollama")
    if ok and integration.get_command_completions then
      local comp_ok, completions = pcall(integration.get_command_completions, arglead, tool_cmdline, tool_cursorpos)
      if comp_ok then
        return completions
      end
    end
  end

  -- No completions for unknown tools
  return {}
end

-- Create user command
vim.api.nvim_create_user_command("Aibo", function(cmd_opts)
  local args = cmd_opts.fargs
  if #args == 0 then
    vim.api.nvim_err_writeln("Usage: :Aibo [-opener=<opener>] <cmd> [args...]")
    return
  end

  -- Parse -opener option
  local opener = nil
  if args[1] and args[1]:match("^-opener=") then
    opener = args[1]:match("^-opener=(.+)")
    if not opener or opener == "" then
      vim.api.nvim_err_writeln("Usage: :Aibo [-opener=<opener>] <cmd> [args...]")
      vim.api.nvim_err_writeln("Example: :Aibo -opener=vsplit ollama run llama3.2")
      return
    end
    table.remove(args, 1) -- remove "-opener=..."
  end

  if #args == 0 then
    vim.api.nvim_err_writeln("Usage: :Aibo [-opener=<opener>] <cmd> [args...]")
    return
  end

  local cmd = table.remove(args, 1)

  -- Validate the command
  local known_cmds = { "claude", "codex", "ollama" }
  if not vim.tbl_contains(known_cmds, cmd) then
    vim.api.nvim_err_writeln(string.format("Error: Unknown command '%s'", cmd))
    vim.api.nvim_err_writeln("Available commands: " .. table.concat(known_cmds, ", "))
    return
  end

  require("aibo.internal.console").open(cmd, args, opener)
end, {
  nargs = "+",
  desc = "Start an AI bot session",
  complete = _G._aibo_complete,
})