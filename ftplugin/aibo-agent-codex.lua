if vim.b.loaded_aibo_agent_codex_ftplugin then
  return
end
vim.b.loaded_aibo_agent_codex_ftplugin = true

local bufnr = vim.api.nvim_get_current_buf()
local aibo = require("aibo")

local CODEX_CODES = {
  transcript = "\020",
}

vim.keymap.set({ "n", "i" }, "<Plug>(aibo-codex-transcript)", function()
  aibo.send(CODEX_CODES.transcript, bufnr)
end, { buffer = bufnr, desc = "Transcript (Ctrl+T)" })

vim.keymap.set({ "n", "i" }, "<Plug>(aibo-codex-home)", function()
  aibo.send(vim.api.nvim_replace_termcodes("<Home>", true, false, true), bufnr)
end, { buffer = bufnr, desc = "Home" })

vim.keymap.set({ "n", "i" }, "<Plug>(aibo-codex-end)", function()
  aibo.send(vim.api.nvim_replace_termcodes("<End>", true, false, true), bufnr)
end, { buffer = bufnr, desc = "End" })

vim.keymap.set({ "n", "i" }, "<Plug>(aibo-codex-page-up)", function()
  aibo.send(vim.api.nvim_replace_termcodes("<PageUp>", true, false, true), bufnr)
end, { buffer = bufnr, desc = "Page up" })

vim.keymap.set({ "n", "i" }, "<Plug>(aibo-codex-page-down)", function()
  aibo.send(vim.api.nvim_replace_termcodes("<PageDown>", true, false, true), bufnr)
end, { buffer = bufnr, desc = "Page down" })

vim.keymap.set({ "n", "i" }, "<Plug>(aibo-codex-quit)", function()
  aibo.send("q", bufnr)
end, { buffer = bufnr, desc = "Quit" })

-- Default mappings (unless disabled in config)
local cfg = aibo.get_agent_config("codex")
if not (cfg and cfg.no_default_mappings) then
  vim.keymap.set({ "n" }, "<C-t>", "<Plug>(aibo-codex-transcript)", { buffer = bufnr })
  vim.keymap.set({ "n" }, "<Home>", "<Plug>(aibo-codex-home)", { buffer = bufnr })
  vim.keymap.set({ "n" }, "<End>", "<Plug>(aibo-codex-end)", { buffer = bufnr })
  vim.keymap.set({ "n" }, "<PageUp>", "<Plug>(aibo-codex-page-up)", { buffer = bufnr })
  vim.keymap.set({ "n" }, "<PageDown>", "<Plug>(aibo-codex-page-down)", { buffer = bufnr })
  vim.keymap.set({ "n" }, "q", "<Plug>(aibo-codex-quit)", { buffer = bufnr })

  -- Insert mode mappings
  vim.keymap.set("i", "<C-t>", "<C-\\><C-o><Plug>(aibo-codex-transcript)", { buffer = bufnr })
  vim.keymap.set("i", "<Home>", "<C-\\><C-o><Plug>(aibo-codex-home)", { buffer = bufnr })
  vim.keymap.set("i", "<End>", "<C-\\><C-o><Plug>(aibo-codex-end)", { buffer = bufnr })
  vim.keymap.set("i", "<PageUp>", "<C-\\><C-o><Plug>(aibo-codex-page-up)", { buffer = bufnr })
  vim.keymap.set("i", "<PageDown>", "<C-\\><C-o><Plug>(aibo-codex-page-down)", { buffer = bufnr })
end
