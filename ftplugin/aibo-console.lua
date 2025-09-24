if vim.b.loaded_aibo_console_ftplugin then
  return
end
vim.b.loaded_aibo_console_ftplugin = true

local bufnr = vim.api.nvim_get_current_buf()
local aibo = require("aibo")

-- Window settings (these apply to the current window)
vim.wo.number = false
vim.wo.relativenumber = false
vim.wo.signcolumn = "no"

-- Avoid "Cannot make changes, 'modifiable' is off" errors on o/O
vim.keymap.set("n", "o", "i", { buffer = bufnr, desc = "Enter insert mode" })
vim.keymap.set("n", "O", "i", { buffer = bufnr, desc = "Enter insert mode" })

vim.keymap.set("n", "<Plug>(aibo-console-submit)", function()
  aibo.submit("", bufnr)
end, { buffer = bufnr, desc = "Submit empty message" })

vim.keymap.set("n", "<Plug>(aibo-console-close)", function()
  vim.cmd("quit")
end, { buffer = bufnr, desc = "Close console" })

vim.keymap.set("n", "<Plug>(aibo-console-esc)", function()
  aibo.send(vim.api.nvim_replace_termcodes("<Esc>", true, false, true), bufnr)
end, { buffer = bufnr, desc = "Send ESC to agent" })

vim.keymap.set("n", "<Plug>(aibo-console-interrupt)", function()
  aibo.send(vim.api.nvim_replace_termcodes("<C-c>", true, false, true), bufnr)
end, { buffer = bufnr, desc = "Send interrupt signal (original <C-c>)" })

vim.keymap.set("n", "<Plug>(aibo-console-clear)", function()
  aibo.send(vim.api.nvim_replace_termcodes("<C-l>", true, false, true), bufnr)
end, { buffer = bufnr, desc = "Clear screen" })

vim.keymap.set("n", "<Plug>(aibo-console-next)", function()
  aibo.send(vim.api.nvim_replace_termcodes("<C-n>", true, false, true), bufnr)
end, { buffer = bufnr, desc = "Next history" })

vim.keymap.set("n", "<Plug>(aibo-console-prev)", function()
  aibo.send(vim.api.nvim_replace_termcodes("<C-p>", true, false, true), bufnr)
end, { buffer = bufnr, desc = "Previous history" })

vim.keymap.set("n", "<Plug>(aibo-console-down)", function()
  aibo.send(vim.api.nvim_replace_termcodes("<Down>", true, false, true), bufnr)
end, { buffer = bufnr, desc = "Move down" })

vim.keymap.set("n", "<Plug>(aibo-console-up)", function()
  aibo.send(vim.api.nvim_replace_termcodes("<Up>", true, false, true), bufnr)
end, { buffer = bufnr, desc = "Move up" })

-- Default mappings (unless disabled in config)
local cfg = aibo.get_buffer_config("console")
if not (cfg and cfg.no_default_mappings) then
  vim.keymap.set("n", "<CR>", "<Plug>(aibo-console-submit)", { buffer = bufnr })
  -- Don't map <Esc> to prevent unintended interrupts from Vimmer's habit of hitting Esc repeatedly
  -- Map <C-c> to send <Esc> instead
  vim.keymap.set({ "n", "i" }, "<C-c>", "<Plug>(aibo-console-esc)", { buffer = bufnr })
  -- g<C-c> sends the original <C-c> (interrupt signal)
  vim.keymap.set("n", "g<C-c>", "<Plug>(aibo-console-interrupt)", { buffer = bufnr })
  vim.keymap.set("n", "<C-l>", "<Plug>(aibo-console-clear)", { buffer = bufnr })
  vim.keymap.set("n", "<C-n>", "<Plug>(aibo-console-next)", { buffer = bufnr })
  vim.keymap.set("n", "<C-p>", "<Plug>(aibo-console-prev)", { buffer = bufnr })
  vim.keymap.set("n", "<Down>", "<Plug>(aibo-console-down)", { buffer = bufnr })
  vim.keymap.set("n", "<Up>", "<Plug>(aibo-console-up)", { buffer = bufnr })
end
