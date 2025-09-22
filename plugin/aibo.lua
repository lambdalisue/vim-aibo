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
  complete = function(arglead, cmdline, cursorpos)
    -- Basic completion for common AI tools
    local completions = { "claude", "codex", "gh", "ollama" }
    if arglead == "" then
      return completions
    end
    return vim.tbl_filter(function(val)
      return val:find("^" .. vim.pesc(arglead))
    end, completions)
  end,
})

