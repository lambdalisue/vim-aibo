if vim.b.loaded_aibo_prompt_ftplugin then
  return
end
vim.b.loaded_aibo_prompt_ftplugin = true

local bufnr = vim.api.nvim_get_current_buf()
local aibo = require("aibo")

-- Window settings (these apply to the current window)
vim.wo.number = false
vim.wo.relativenumber = false
vim.wo.signcolumn = "no"

vim.keymap.set({ "n", "i" }, "<Plug>(aibo-prompt-submit)", function()
  vim.cmd("write")
end, { buffer = bufnr, desc = "Submit prompt" })

vim.keymap.set({ "n", "i" }, "<Plug>(aibo-prompt-submit-close)", function()
  vim.cmd("wq")
end, { buffer = bufnr, desc = "Submit prompt and close" })

vim.keymap.set({ "n", "i" }, "<Plug>(aibo-prompt-esc)", function()
  aibo.send(vim.api.nvim_replace_termcodes("<Esc>", true, false, true), bufnr)
end, { buffer = bufnr, desc = "Send ESC to agent" })

vim.keymap.set({ "n", "i" }, "<Plug>(aibo-prompt-interrupt)", function()
  aibo.send(vim.api.nvim_replace_termcodes("<C-c>", true, false, true), bufnr)
end, { buffer = bufnr, desc = "Interrupt agent" })

vim.keymap.set({ "n", "i" }, "<Plug>(aibo-prompt-clear)", function()
  aibo.send(vim.api.nvim_replace_termcodes("<C-l>", true, false, true), bufnr)
end, { buffer = bufnr, desc = "Clear screen" })

vim.keymap.set({ "n", "i" }, "<Plug>(aibo-prompt-next)", function()
  aibo.send(vim.api.nvim_replace_termcodes("<C-n>", true, false, true), bufnr)
end, { buffer = bufnr, desc = "Next history" })

vim.keymap.set({ "n", "i" }, "<Plug>(aibo-prompt-prev)", function()
  aibo.send(vim.api.nvim_replace_termcodes("<C-p>", true, false, true), bufnr)
end, { buffer = bufnr, desc = "Previous history" })

vim.keymap.set({ "n", "i" }, "<Plug>(aibo-prompt-down)", function()
  aibo.send(vim.api.nvim_replace_termcodes("<Down>", true, false, true), bufnr)
end, { buffer = bufnr, desc = "Move down" })

vim.keymap.set({ "n", "i" }, "<Plug>(aibo-prompt-up)", function()
  aibo.send(vim.api.nvim_replace_termcodes("<Up>", true, false, true), bufnr)
end, { buffer = bufnr, desc = "Move up" })

-- Default mappings (unless disabled in config)
local cfg = aibo.get_buffer_config("prompt")
if not (cfg and cfg.no_default_mappings) then
  vim.keymap.set("n", "<CR>", "<Plug>(aibo-prompt-submit)", { buffer = bufnr })
  vim.keymap.set("n", "<C-Enter>", "<Plug>(aibo-prompt-submit-close)", { buffer = bufnr })
  vim.keymap.set("n", "<F5>", "<Plug>(aibo-prompt-submit-close)", { buffer = bufnr })
  vim.keymap.set("n", "<Esc>", "<Plug>(aibo-prompt-esc)", { buffer = bufnr })
  vim.keymap.set("n", "<C-c>", "<Plug>(aibo-prompt-interrupt)", { buffer = bufnr })
  vim.keymap.set("n", "<C-l>", "<Plug>(aibo-prompt-clear)", { buffer = bufnr })
  vim.keymap.set("n", "<C-n>", "<Plug>(aibo-prompt-next)", { buffer = bufnr })
  vim.keymap.set("n", "<C-p>", "<Plug>(aibo-prompt-prev)", { buffer = bufnr })
  vim.keymap.set("n", "<Down>", "<Plug>(aibo-prompt-down)", { buffer = bufnr })
  vim.keymap.set("n", "<Up>", "<Plug>(aibo-prompt-up)", { buffer = bufnr })
  -- It seems <Esc> is required to properly close after submit
  vim.keymap.set("i", "<C-Enter>", "<Esc><Plug>(aibo-prompt-submit-close)", { buffer = bufnr })
  vim.keymap.set("i", "<F5>", "<Esc><Plug>(aibo-prompt-submit-close)", { buffer = bufnr })
end
