if vim.b.loaded_aibo_agent_claude_ftplugin then
  return
end
vim.b.loaded_aibo_agent_claude_ftplugin = true

local bufnr = vim.api.nvim_get_current_buf()
local aibo = require("aibo")

local CLAUDE_CODES = {
  mode = "\027[Z",
  verbose = "\015",
  todo = "\020",
  undo = "\031",
  suspend = "\026",
  paste = "\022",
}

vim.keymap.set({ "n", "i" }, "<Plug>(aibo-claude-mode)", function()
  aibo.send(CLAUDE_CODES.mode, bufnr)
end, { buffer = bufnr, desc = "Toggle mode (Shift+Tab)" })

vim.keymap.set({ "n", "i" }, "<Plug>(aibo-claude-verbose)", function()
  aibo.send(CLAUDE_CODES.verbose, bufnr)
end, { buffer = bufnr, desc = "Verbose (Ctrl+O)" })

vim.keymap.set({ "n", "i" }, "<Plug>(aibo-claude-todo)", function()
  aibo.send(CLAUDE_CODES.todo, bufnr)
end, { buffer = bufnr, desc = "Todo (Ctrl+T)" })

vim.keymap.set({ "n", "i" }, "<Plug>(aibo-claude-undo)", function()
  aibo.send(CLAUDE_CODES.undo, bufnr)
end, { buffer = bufnr, desc = "Undo (Ctrl+Y)" })

vim.keymap.set({ "n", "i" }, "<Plug>(aibo-claude-suspend)", function()
  aibo.send(CLAUDE_CODES.suspend, bufnr)
end, { buffer = bufnr, desc = "Suspend (Ctrl+Z)" })

vim.keymap.set({ "n", "i" }, "<Plug>(aibo-claude-paste)", function()
  aibo.send(CLAUDE_CODES.paste, bufnr)
end, { buffer = bufnr, desc = "Paste (Ctrl+V)" })

-- Default mappings (unless disabled in config)
local cfg = aibo.get_agent_config("claude")
if not (cfg and cfg.no_default_mappings) then
  vim.keymap.set({ "n" }, "<S-Tab>", "<Plug>(aibo-claude-mode)", { buffer = bufnr })
  vim.keymap.set({ "n" }, "<F2>", "<Plug>(aibo-claude-mode)", { buffer = bufnr })
  vim.keymap.set({ "n" }, "<C-o>", "<Plug>(aibo-claude-verbose)", { buffer = bufnr })
  vim.keymap.set({ "n" }, "<C-t>", "<Plug>(aibo-claude-todo)", { buffer = bufnr })
  vim.keymap.set({ "n" }, "<C-_>", "<Plug>(aibo-claude-undo)", { buffer = bufnr })
  vim.keymap.set({ "n" }, "<C-->", "<Plug>(aibo-claude-undo)", { buffer = bufnr })
  vim.keymap.set({ "n" }, "<C-z>", "<Plug>(aibo-claude-suspend)", { buffer = bufnr })
  vim.keymap.set({ "n" }, "<C-v>", "<Plug>(aibo-claude-paste)", { buffer = bufnr })

  -- Insert mode mappings
  vim.keymap.set("i", "<S-Tab>", "<C-\\><C-o><Plug>(aibo-claude-mode)", { buffer = bufnr })
  vim.keymap.set("i", "<F2>", "<C-\\><C-o><Plug>(aibo-claude-mode)", { buffer = bufnr })
  vim.keymap.set("i", "<C-o>", "<C-\\><C-o><Plug>(aibo-claude-verbose)", { buffer = bufnr })
  vim.keymap.set("i", "<C-t>", "<C-\\><C-o><Plug>(aibo-claude-todo)", { buffer = bufnr })
  vim.keymap.set("i", "<C-_>", "<C-\\><C-o><Plug>(aibo-claude-undo)", { buffer = bufnr })
  vim.keymap.set("i", "<C-->", "<C-\\><C-o><Plug>(aibo-claude-undo)", { buffer = bufnr })
  vim.keymap.set("i", "<C-z>", "<C-\\><C-o><Plug>(aibo-claude-suspend)", { buffer = bufnr })
  vim.keymap.set("i", "<C-v>", "<C-\\><C-o><Plug>(aibo-claude-paste)", { buffer = bufnr })
end
