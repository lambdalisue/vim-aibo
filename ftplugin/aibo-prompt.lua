if vim.b.did_ftplugin_aibo_prompt then
	return
end
vim.b.did_ftplugin_aibo_prompt = 1

-- Display settings
vim.opt_local.number = false
vim.opt_local.relativenumber = false
vim.opt_local.signcolumn = "no"

vim.keymap.set("n", "<CR>", "<Plug>(aibo-submit)", { buffer = true })
vim.keymap.set("n", "<Esc>", "<Plug>(aibo-esc)", { buffer = true })
vim.keymap.set("i", "<C-Enter>", "<C-\><C-o><Plug>(aibo-submit-close)", { buffer = true })
vim.keymap.set("n", "<C-Enter>", "<Plug>(aibo-submit-close)", { buffer = true })
vim.keymap.set("i", "<C-S-Enter>", "<C-\><C-o><Plug>(aibo-submit)", { buffer = true })
vim.keymap.set("n", "<C-S-Enter>", "<Plug>(aibo-submit)", { buffer = true })

-- F5 key mappings (alternative submit keys)
vim.keymap.set("n", "<F5>", "<Plug>(aibo-submit-close)", { buffer = true })
vim.keymap.set("i", "<F5>", "<C-\><C-o><Plug>(aibo-submit-close)", { buffer = true })
vim.keymap.set("n", "<C-F5>", "<Plug>(aibo-submit)", { buffer = true })
vim.keymap.set("i", "<C-F5>", "<C-\><C-o><Plug>(aibo-submit)", { buffer = true })

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
	"silent! nunmap <buffer> <C-Enter>",
	"silent! iunmap <buffer> <C-Enter>",
	"silent! nunmap <buffer> <C-S-Enter>",
	"silent! iunmap <buffer> <C-S-Enter>",
	"silent! nunmap <buffer> <F5>",
	"silent! iunmap <buffer> <F5>",
	"silent! nunmap <buffer> <C-F5>",
	"silent! iunmap <buffer> <C-F5>",
}

local existing_undo = vim.b.undo_ftplugin or ""
if existing_undo ~= "" then
	existing_undo = existing_undo .. " | "
end
vim.b.undo_ftplugin = existing_undo .. table.concat(undo_commands, " | ")
