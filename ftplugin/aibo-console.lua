if vim.b.did_ftplugin_aibo_console then
	return
end
vim.b.did_ftplugin_aibo_console = 1

local aibo = require("aibo")

vim.keymap.set("n", "<CR>", "<Plug>(aibo-submit)", { buffer = true })
vim.keymap.set("n", "<Esc>", "<Plug>(aibo-esc)", { buffer = true })

vim.keymap.set({ "n", "v" }, "<C-c>", "<Plug>(aibo-interrupt)", { buffer = true })
vim.keymap.set({ "n", "v" }, "<C-l>", "<Plug>(aibo-clear)", { buffer = true })
vim.keymap.set({ "n", "v" }, "<C-n>", "<Plug>(aibo-next)", { buffer = true })
vim.keymap.set({ "n", "v" }, "<C-p>", "<Plug>(aibo-prev)", { buffer = true })
vim.keymap.set({ "n", "v" }, "<Down>", "<Plug>(aibo-down)", { buffer = true })
vim.keymap.set({ "n", "v" }, "<Up>", "<Plug>(aibo-up)", { buffer = true })

local undo_commands = {
	"silent! nunmap <buffer> <CR>",
	"silent! nunmap <buffer> <Esc>",
	"silent! nunmap <buffer> <C-c>",
	"silent! vunmap <buffer> <C-c>",
	"silent! nunmap <buffer> <C-l>",
	"silent! vunmap <buffer> <C-l>",
	"silent! nunmap <buffer> <C-n>",
	"silent! vunmap <buffer> <C-n>",
	"silent! nunmap <buffer> <C-p>",
	"silent! vunmap <buffer> <C-p>",
	"silent! nunmap <buffer> <Down>",
	"silent! vunmap <buffer> <Down>",
	"silent! nunmap <buffer> <Up>",
	"silent! vunmap <buffer> <Up>",
}

local existing_undo = vim.b.undo_ftplugin or ""
if existing_undo ~= "" then
	existing_undo = existing_undo .. " | "
end
vim.b.undo_ftplugin = existing_undo .. table.concat(undo_commands, " | ")
