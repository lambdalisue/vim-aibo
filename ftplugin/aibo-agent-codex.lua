if vim.b.did_ftplugin_aibo_agent_codex then
	return
end
vim.b.did_ftplugin_aibo_agent_codex = 1

local aibo = require("aibo")

-- Codex specific plug mappings
vim.keymap.set({ "n", "v" }, "<Plug>(aibo-codex-transcript)", function()
	aibo.send("\020")
end, { buffer = true, silent = true })

-- Key mappings
vim.keymap.set({ "n", "v" }, "<C-t>", "<Plug>(aibo-codex-transcript)", { buffer = true })
vim.keymap.set({ "n", "v" }, "<Home>", function()
	aibo.send(vim.api.nvim_replace_termcodes("<Home>", true, false, true))
end, { buffer = true })
vim.keymap.set({ "n", "v" }, "<End>", function()
	aibo.send(vim.api.nvim_replace_termcodes("<End>", true, false, true))
end, { buffer = true })
vim.keymap.set({ "n", "v" }, "<PageUp>", function()
	aibo.send(vim.api.nvim_replace_termcodes("<PageUp>", true, false, true))
end, { buffer = true })
vim.keymap.set({ "n", "v" }, "<PageDown>", function()
	aibo.send(vim.api.nvim_replace_termcodes("<PageDown>", true, false, true))
end, { buffer = true })
vim.keymap.set({ "n", "v" }, "q", function()
	aibo.send("q")
end, { buffer = true })

-- Setup undo_ftplugin
local undo_commands = {
	"silent! nunmap <buffer> <C-t>",
	"silent! vunmap <buffer> <C-t>",
	"silent! nunmap <buffer> <Home>",
	"silent! vunmap <buffer> <Home>",
	"silent! nunmap <buffer> <End>",
	"silent! vunmap <buffer> <End>",
	"silent! nunmap <buffer> <PageUp>",
	"silent! vunmap <buffer> <PageUp>",
	"silent! nunmap <buffer> <PageDown>",
	"silent! vunmap <buffer> <PageDown>",
	"silent! nunmap <buffer> q",
	"silent! vunmap <buffer> q",
}

local existing_undo = vim.b.undo_ftplugin or ""
if existing_undo ~= "" then
	existing_undo = existing_undo .. " | "
end
vim.b.undo_ftplugin = existing_undo .. table.concat(undo_commands, " | ")
