local M = {}

-- Claude-specific terminal codes
local CLAUDE_CODES = {
  mode = "\027[Z", -- Shift+Tab - Toggle mode
  verbose = "\015", -- Ctrl+O - Verbose
  todo = "\020", -- Ctrl+T - Todo
  undo = "\031", -- Ctrl+Y - Undo
  suspend = "\026", -- Ctrl+Z - Suspend
  paste = "\022", -- Ctrl+V - Paste
}

-- Codex-specific terminal codes
local CODEX_CODES = {
  transcript = "\020", -- Ctrl+T - Transcript
}

---Create action functions for prompt buffers
---@param bufnr integer Buffer number
---@return table<string, function> Action functions
function M.prompt(bufnr)
  return {
    submit = function()
      -- Write buffer (triggers BufWriteCmd autocmd)
      vim.cmd("write")
    end,
    submit_close = function()
      -- Write and quit (triggers BufWriteCmd autocmd then closes)
      vim.cmd("wq")
    end,
    esc = function()
      local aibo = require("aibo")
      aibo.send(vim.api.nvim_replace_termcodes("<Esc>", true, false, true), bufnr)
    end,
    interrupt = function()
      local aibo = require("aibo")
      aibo.send(vim.api.nvim_replace_termcodes("<C-c>", true, false, true), bufnr)
    end,
    clear = function()
      local aibo = require("aibo")
      aibo.send(vim.api.nvim_replace_termcodes("<C-l>", true, false, true), bufnr)
    end,
    next = function()
      local aibo = require("aibo")
      aibo.send(vim.api.nvim_replace_termcodes("<C-n>", true, false, true), bufnr)
    end,
    prev = function()
      local aibo = require("aibo")
      aibo.send(vim.api.nvim_replace_termcodes("<C-p>", true, false, true), bufnr)
    end,
    down = function()
      local aibo = require("aibo")
      aibo.send(vim.api.nvim_replace_termcodes("<Down>", true, false, true), bufnr)
    end,
    up = function()
      local aibo = require("aibo")
      aibo.send(vim.api.nvim_replace_termcodes("<Up>", true, false, true), bufnr)
    end,
  }
end

---Create action functions for console buffers
---@param bufnr integer Buffer number
---@return table<string, function> Action functions
function M.console(bufnr)
  return {
    submit = function()
      local aibo = require("aibo")
      aibo.submit("", bufnr)
    end,
    close = function()
      vim.cmd("quit")
    end,
    esc = function()
      local aibo = require("aibo")
      aibo.send(vim.api.nvim_replace_termcodes("<Esc>", true, false, true), bufnr)
    end,
    interrupt = function()
      local aibo = require("aibo")
      aibo.send(vim.api.nvim_replace_termcodes("<C-c>", true, false, true), bufnr)
    end,
    clear = function()
      local aibo = require("aibo")
      aibo.send(vim.api.nvim_replace_termcodes("<C-l>", true, false, true), bufnr)
    end,
    next = function()
      local aibo = require("aibo")
      aibo.send(vim.api.nvim_replace_termcodes("<C-n>", true, false, true), bufnr)
    end,
    prev = function()
      local aibo = require("aibo")
      aibo.send(vim.api.nvim_replace_termcodes("<C-p>", true, false, true), bufnr)
    end,
    down = function()
      local aibo = require("aibo")
      aibo.send(vim.api.nvim_replace_termcodes("<Down>", true, false, true), bufnr)
    end,
    up = function()
      local aibo = require("aibo")
      aibo.send(vim.api.nvim_replace_termcodes("<Up>", true, false, true), bufnr)
    end,
  }
end

---Create Claude-specific action functions
---@param bufnr integer Buffer number
---@return table<string, function> Action functions
function M.claude(bufnr)
  local aibo = require("aibo")
  return {
    mode = function()
      aibo.send(CLAUDE_CODES.mode, bufnr)
    end,
    verbose = function()
      aibo.send(CLAUDE_CODES.verbose, bufnr)
    end,
    todo = function()
      aibo.send(CLAUDE_CODES.todo, bufnr)
    end,
    undo = function()
      aibo.send(CLAUDE_CODES.undo, bufnr)
    end,
    suspend = function()
      aibo.send(CLAUDE_CODES.suspend, bufnr)
    end,
    paste = function()
      aibo.send(CLAUDE_CODES.paste, bufnr)
    end,
  }
end

---Create Codex-specific action functions
---@param bufnr integer Buffer number
---@return table<string, function> Action functions
function M.codex(bufnr)
  local aibo = require("aibo")
  return {
    transcript = function()
      aibo.send(CODEX_CODES.transcript, bufnr)
    end,
    home = function()
      aibo.send(vim.api.nvim_replace_termcodes("<Home>", true, false, true), bufnr)
    end,
    end_key = function()
      aibo.send(vim.api.nvim_replace_termcodes("<End>", true, false, true), bufnr)
    end,
    page_up = function()
      aibo.send(vim.api.nvim_replace_termcodes("<PageUp>", true, false, true), bufnr)
    end,
    page_down = function()
      aibo.send(vim.api.nvim_replace_termcodes("<PageDown>", true, false, true), bufnr)
    end,
    quit = function()
      aibo.send("q", bufnr)
    end,
  }
end

return M
