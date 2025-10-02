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
vim.wo.winfixheight = true

-- Default key mappings (unless disabled in config)
local cfg = aibo.get_buffer_config("prompt")
if not (cfg and cfg.no_default_mappings) then
  local opts = { buffer = bufnr, nowait = true, silent = true }
  vim.keymap.set({ "n", "i" }, "<C-g><C-o>", "<Plug>(aibo-send)", { buffer = bufnr, nowait = true })
  vim.keymap.set("n", "<CR>", "<Plug>(aibo-submit)", opts)
  vim.keymap.set("n", "<C-Enter>", "<Plug>(aibo-submit)", opts)
  vim.keymap.set("n", "<F5>", "<Plug>(aibo-submit)", opts)
  vim.keymap.set("i", "<C-Enter>", "<Esc><Plug>(aibo-submit)", opts)
  vim.keymap.set("i", "<F5>", "<Esc><Plug>(aibo-submit)", opts)
  vim.keymap.set({ "n", "i" }, "<C-c>", "<Plug>(aibo-send)<Esc>", opts)
  vim.keymap.set({ "n", "i" }, "g<C-c>", "<Plug>(aibo-send)<C-c>", opts)
  vim.keymap.set({ "n", "i" }, "<C-l>", "<Plug>(aibo-send)<C-l>", opts)
  vim.keymap.set({ "n", "i" }, "<C-n>", "<Plug>(aibo-send)<C-n>", opts)
  vim.keymap.set({ "n", "i" }, "<C-p>", "<Plug>(aibo-send)<C-p>", opts)
  vim.keymap.set({ "n", "i" }, "<Down>", "<Plug>(aibo-send)<Down>", opts)
  vim.keymap.set({ "n", "i" }, "<Up>", "<Plug>(aibo-send)<Up>", opts)

  vim.keymap.set("n", "<C-w>k", function()
    local prompt = require("aibo.internal.prompt_floating")
    local info = prompt.get_info_by_bufnr(bufnr)
    if info and info.console_info and vim.api.nvim_win_is_valid(info.console_info.winid) then
      vim.api.nvim_set_current_win(info.console_info.winid)
    end
  end, opts)

  -- <C-w>k以外の<C-w>系マッピング: コンソールに移動してから実行
  local function execute_in_console(key)
    return function()
      local prompt = require("aibo.internal.prompt_floating")
      local info = prompt.get_info_by_bufnr(bufnr)
      if info and info.console_info and vim.api.nvim_win_is_valid(info.console_info.winid) then
        vim.api.nvim_set_current_win(info.console_info.winid)
        vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes(key, true, false, true), "n", false)
      end
    end
  end

  local window_keys = {
    "h", "j", "l", "w", "W", "p", "t", "b", "c", "q", "o", "s", "v", "n", "r", "x",
    "=", "+", "-", "<", ">", "|", "_",
    "H", "J", "K", "L", "T" -- 大文字のウィンドウ移動コマンド
  }
  for _, k in ipairs(window_keys) do
    vim.keymap.set("n", "<C-w>" .. k, execute_in_console("<C-w>" .. k), opts)
  end
end
