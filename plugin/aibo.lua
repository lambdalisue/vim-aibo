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
    local bufnr = tonumber(vim.fn.expand("<abuf>"))
    if bufnr then
      require("aibo.internal.prompt").init(bufnr)
    end
  end,
})


-- Initialize command modules
require("aibo.command.aibo").setup()
require("aibo.command.aibo_send").setup()
