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

    -- If we're still on the first argument (the AI tool name)
    -- Only complete tool names if we're at position 2 or if parts[2] isn't a known tool
    local known_tools = { "claude", "codex", "ollama" }
    local is_known_tool = vim.tbl_contains(known_tools, parts[2] or "")

    if #parts <= 2 or (not is_known_tool and arglead:match("^%w")) then
      -- Basic completion for common AI tools
      if arglead == "" then
        return known_tools
      end
      return vim.tbl_filter(function(val)
        return val:find("^" .. vim.pesc(arglead))
      end, known_tools)
    end

    -- Provide tool-specific argument completions based on the AI tool
    local tool = parts[2]

    -- Strip "Aibo " prefix to pass cleaner cmdline to integrations
    -- This allows adding Aibo options between "Aibo" and the tool name in the future
    -- e.g., "Aibo --opener split ollama run ..." -> "ollama run ..."
    local tool_cmdline = cmdline:gsub("^Aibo%s+", "")
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
  local args = vim.split(cmd_opts.args, "%s+")
  if #args == 0 then
    vim.api.nvim_err_writeln("Usage: :Aibo <cmd> [args...]")
    return
  end
  local cmd = table.remove(args, 1)
  require("aibo.internal.console").open(cmd, args)
end, {
  nargs = "+",
  desc = "Start an AI bot session",
  complete = _G._aibo_complete,
})

