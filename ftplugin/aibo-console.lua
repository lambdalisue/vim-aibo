if vim.b.did_ftplugin_aibo_console then
	return
end
vim.b.did_ftplugin_aibo_console = 1

local aibo = require("aibo")

vim.keymap.set("n", "<CR>", "<Plug>(aibo-submit)", { buffer = true })
vim.keymap.set("n", "<Esc>", "<Plug>(aibo-esc)", { buffer = true })

vim.keymap.set("", "<C-c>", "<Plug>(aibo-interrupt)", { buffer = true })
vim.keymap.set("", "<C-l>", "<Plug>(aibo-clear)", { buffer = true })
vim.keymap.set("", "<C-n>", "<Plug>(aibo-next)", { buffer = true })
vim.keymap.set("", "<C-p>", "<Plug>(aibo-prev)", { buffer = true })
vim.keymap.set("", "<Down>", "<Plug>(aibo-down)", { buffer = true })
vim.keymap.set("", "<Up>", "<Plug>(aibo-up)", { buffer = true })

local undo_commands = {
	"silent! unmap <buffer> <CR>",
	"silent! unmap <buffer> <Esc>",
	"silent! unmap <buffer> <C-c>",
	"silent! unmap <buffer> <C-l>",
	"silent! unmap <buffer> <C-n>",
	"silent! unmap <buffer> <C-p>",
	"silent! unmap <buffer> <Down>",
	"silent! unmap <buffer> <Up>",
}

local existing_undo = vim.b.undo_ftplugin or ""
if existing_undo ~= "" then
	existing_undo = existing_undo .. " | "
end
vim.b.undo_ftplugin = existing_undo .. table.concat(undo_commands, " | ")
