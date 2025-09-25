local M = {}

---Find the console buffer number from prompt buffer
---@param bufnr integer Prompt buffer number
---@return integer Console buffer number
local function find_console_bufnr(bufnr)
  local bufname = vim.api.nvim_buf_get_name(bufnr)
  local winid = string.match(bufname, "^aiboprompt://(%d+)$")

  if not winid then
    vim.notify(('Invalid aibo-prompt buffer "%s"'):format(bufname), vim.log.levels.ERROR, { title = "Aibo" })
    return -1
  end

  local console_bufnr = vim.fn.winbufnr(tonumber(winid))
  if console_bufnr == -1 then
    vim.notify(("No console window found for window ID %s"):format(winid), vim.log.levels.ERROR, { title = "Aibo" })
    return -1
  end

  return console_bufnr
end

---Submit content from prompt buffer
---@param bufnr integer Buffer number
---@return nil
local function submit_content(bufnr)
  local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
  local content = table.concat(lines, "\n")

  local aibo = require("aibo")
  aibo.submit(content, bufnr)

  vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, {})
  vim.api.nvim_win_set_cursor(0, { 1, 0 })
end

---Handle WinLeave event
---@return nil
local function WinLeave()
  local winnr = vim.fn.winnr()
  vim.cmd(string.format("noautocmd %dhide", winnr))
end

---Handle BufWritePre event
---@return nil
local function BufWritePre()
  vim.bo.modified = true
end

---Handle BufWriteCmd event
---@return nil
local function BufWriteCmd()
  local bufnr = vim.api.nvim_get_current_buf()
  submit_content(bufnr)
  vim.bo[bufnr].modified = false
end

---Handle QuitPre event
---@return nil
local function QuitPre()
  local bufinfos = vim.fn.getbufinfo({ bufloaded = 1 })
  for _, bufinfo in ipairs(bufinfos) do
    local ft = vim.bo[bufinfo.bufnr].filetype
    if ft:match("aibo%-prompt") then
      vim.bo[bufinfo.bufnr].modified = false
    end
  end
end

---Initialize prompt buffer
---@param prompt_bufnr integer Prompt buffer number
---@return nil
function M.init(prompt_bufnr)
  local console_bufnr = find_console_bufnr(prompt_bufnr)
  if console_bufnr == -1 then
    return
  end

  local aibo = vim.b[console_bufnr].aibo
  if not aibo then
    vim.notify(
      ("No aibo instance found in console buffer %d"):format(console_bufnr),
      vim.log.levels.ERROR,
      { title = "Aibo" }
    )
    return
  end

  vim.b[prompt_bufnr].aibo = aibo

  -- Setup buffer autocmds
  local augroup = vim.api.nvim_create_augroup("aibo_prompt_" .. prompt_bufnr, { clear = true })

  vim.api.nvim_create_autocmd("WinLeave", {
    group = augroup,
    buffer = prompt_bufnr,
    nested = true,
    callback = WinLeave,
  })

  vim.api.nvim_create_autocmd("BufWritePre", {
    group = augroup,
    buffer = prompt_bufnr,
    nested = true,
    callback = BufWritePre,
  })

  vim.api.nvim_create_autocmd("BufWriteCmd", {
    group = augroup,
    buffer = prompt_bufnr,
    nested = true,
    callback = BufWriteCmd,
  })

  -- Set filetype (this triggers ftplugin files)
  vim.bo[prompt_bufnr].filetype = string.format("aibo-prompt.aibo-agent-%s", aibo.cmd)

  -- Call on_attach callbacks AFTER ftplugin files have run
  local aibo_module = require("aibo")
  local info = {
    type = "prompt",
    agent = aibo.cmd,
    aibo = aibo,
  }

  -- Call buffer type on_attach
  local buffer_cfg = aibo_module.get_buffer_config("prompt")
  if buffer_cfg.on_attach then
    buffer_cfg.on_attach(prompt_bufnr, info)
  end

  -- Call agent-specific on_attach
  local agent_cfg = aibo_module.get_agent_config(aibo.cmd)
  if agent_cfg.on_attach then
    agent_cfg.on_attach(prompt_bufnr, info)
  end
end

-- Global autocmd for QuitPre
local global_augroup = vim.api.nvim_create_augroup("aibo_prompt_global", { clear = true })
vim.api.nvim_create_autocmd("QuitPre", {
  group = global_augroup,
  pattern = "*",
  nested = false,
  callback = QuitPre,
})

---Setup prompt <Plug> mappings
---@param bufnr number Buffer number to set mappings for
function M.setup_plug_mappings(bufnr)
  local aibo = require("aibo")

  -- Define <Plug> mappings for prompt functionality
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
  end, { buffer = bufnr, desc = "Send interrupt signal (original <C-c>)" })

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
end

return M
