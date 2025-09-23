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

  -- Skip options when looking for the tool
  local tool_index = 2
  for i = 2, #parts do
    if parts[i] and (parts[i]:match("^-opener=") or parts[i] == "-stay" or parts[i] == "-toggle" or parts[i] == "-jump") then
      tool_index = i + 1
    else
      break
    end
  end

  -- If we're still on the first argument (the AI tool name)
  -- Only complete tool names if we're at the right position or if parts[tool_index] isn't a known tool
  local known_tools = { "claude", "codex", "ollama" }
  local is_known_tool = vim.tbl_contains(known_tools, parts[tool_index] or "")

  if #parts <= tool_index or (not is_known_tool and arglead:match("^%w")) then
    -- Also offer options if we're at the beginning
    if arglead:match("^%-") then
      local options = {}
      -- Check which options haven't been used yet
      local has_opener = false
      local has_stay = false
      local has_toggle = false
      local has_jump = false
      for _, part in ipairs(parts) do
        if part:match("^-opener=") then
          has_opener = true
        elseif part == "-stay" then
          has_stay = true
        elseif part == "-toggle" then
          has_toggle = true
        elseif part == "-jump" then
          has_jump = true
        end
      end
      if not has_opener then
        table.insert(options, "-opener=")
      end
      if not has_stay then
        table.insert(options, "-stay")
      end
      if not has_toggle then
        table.insert(options, "-toggle")
      end
      if not has_jump then
        table.insert(options, "-jump")
      end
      return options
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
  -- e.g., "Aibo -opener=split -stay ollama run ..." -> "ollama run ..."
  local tool_cmdline = cmdline:gsub("^Aibo%s+", "")
  -- Strip all options before the tool
  tool_cmdline = tool_cmdline:gsub("^%-opener=[^%s]+%s+", "")
  tool_cmdline = tool_cmdline:gsub("^%-stay%s+", "")
  tool_cmdline = tool_cmdline:gsub("^%-toggle%s+", "")
  tool_cmdline = tool_cmdline:gsub("^%-jump%s+", "")
  -- Continue stripping if options are present in any order
  tool_cmdline = tool_cmdline:gsub("^%-opener=[^%s]+%s+", "")
  tool_cmdline = tool_cmdline:gsub("^%-stay%s+", "")
  tool_cmdline = tool_cmdline:gsub("^%-toggle%s+", "")
  tool_cmdline = tool_cmdline:gsub("^%-jump%s+", "")

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
    vim.api.nvim_err_writeln("Usage: :Aibo [-opener=<opener>] [-stay] [-toggle|-jump] <cmd> [args...]")
    return
  end

  -- Parse options using the new argparse module
  local argparse = require("aibo.internal.argparse")
  local options, remaining = argparse.parse_fargs(args)

  -- Extract specific options
  local opener = options.opener
  local stay = options.stay or false
  local toggle = options.toggle or false
  local jump = options.jump or false

  if opener == "" then
    vim.api.nvim_err_writeln("Usage: :Aibo [-opener=<opener>] [-stay] [-toggle|-jump] <cmd> [args...]")
    vim.api.nvim_err_writeln("Example: :Aibo -opener=vsplit -stay ollama run llama3.2")
    return
  end

  if #remaining == 0 then
    vim.api.nvim_err_writeln("Usage: :Aibo [-opener=<opener>] [-stay] [-toggle|-jump] <cmd> [args...]")
    return
  end

  -- Validate mutually exclusive options
  if toggle and jump then
    vim.api.nvim_err_writeln("Error: -toggle and -jump cannot be used together")
    return
  end

  local cmd = table.remove(remaining, 1)
  args = remaining  -- Update args to the remaining non-option arguments

  -- Validate the command
  local known_cmds = { "claude", "codex", "ollama" }
  if not vim.tbl_contains(known_cmds, cmd) then
    vim.api.nvim_err_writeln(string.format("Error: Unknown command '%s'", cmd))
    vim.api.nvim_err_writeln("Available commands: " .. table.concat(known_cmds, ", "))
    return
  end

  -- Use appropriate behavior based on options
  if toggle then
    require("aibo.internal.console").toggle(cmd, args, opener, stay)
  elseif jump then
    require("aibo.internal.console").jump(cmd, args, opener, stay)
  else
    require("aibo.internal.console").open(cmd, args, opener, stay)
  end
end, {
  nargs = "+",
  desc = "Start an AI bot session",
  complete = _G._aibo_complete,
})

-- Create AiboSend command
vim.api.nvim_create_user_command("AiboSend", function(cmd_opts)
  -- Parse options using the new argparse module
  local argparse = require("aibo.internal.argparse")
  local options, remaining = argparse.parse_fargs(cmd_opts.fargs or {})

  -- Check if a range was explicitly provided
  -- When no range is given, line1 == line2 == current line
  -- In that case, send the whole buffer
  local line1, line2
  if cmd_opts.range == 0 then
    -- No range provided, send whole buffer
    line1 = nil
    line2 = nil
  else
    -- Range provided, use it
    line1 = cmd_opts.line1
    line2 = cmd_opts.line2
  end

  require("aibo.internal.send").send({
    line1 = line1,
    line2 = line2,
    input = options.input or false,
    submit = options.submit or false,
    replace = options.replace or false,
    prefix = options.prefix,
    suffix = options.suffix,
  })
end, {
  range = true,
  nargs = "*",
  desc = "Send buffer content to Aibo console prompt",
  complete = function(arglead, cmdline, cursorpos)
    if arglead == "" or arglead:match("^%-") then
      local options = { "-input", "-submit", "-replace", "-prefix=", "-suffix=" }
      -- Filter out options already present in cmdline
      local used_options = {}
      for opt in cmdline:gmatch("%-[%w]+") do
        used_options[opt] = true
      end
      -- Also check for -prefix= and -suffix= with values
      if cmdline:match("-prefix=") then
        used_options["-prefix"] = true
      end
      if cmdline:match("-suffix=") then
        used_options["-suffix"] = true
      end

      local available = {}
      for _, opt in ipairs(options) do
        local base_opt = opt:match("^(%-[%w]+)") or opt
        if not used_options[base_opt] then
          table.insert(available, opt)
        end
      end

      -- Filter by arglead if it's not empty
      if arglead ~= "" then
        return vim.tbl_filter(function(val)
          return val:find("^" .. vim.pesc(arglead))
        end, available)
      end
      return available
    end
    return {}
  end,
})
