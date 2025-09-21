local M = {}

---Find the console buffer number from prompt buffer
---@param bufnr integer Prompt buffer number
---@return integer Console buffer number
local function find_console_bufnr(bufnr)
  local bufname = vim.api.nvim_buf_get_name(bufnr)
  local winid = bufname:match("^aiboprompt://(%d+)$")

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
  vim.bo[bufnr].modified = false
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
  submit_content(vim.api.nvim_get_current_buf())
  vim.bo.modified = false
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

---Apply keymaps from configuration
---@param bufnr integer Buffer number
---@param keymaps table<string, string|string[]|false> Keymap configuration
---@param actions table<string, function> Action functions
---@return nil
local function apply_keymaps(bufnr, keymaps, actions)
  if not keymaps then
    return
  end

  for action, lhs_config in pairs(keymaps) do
    if lhs_config and lhs_config ~= false and actions[action] then
      -- Convert single string to array for uniform handling
      local lhs_list = type(lhs_config) == "table" and lhs_config or { lhs_config }

      -- Apply mapping for each key in the list
      for _, lhs in ipairs(lhs_list) do
        -- Handle different actions with appropriate modes
        if action == "submit" then
          vim.keymap.set("n", lhs, actions[action], { buffer = bufnr, silent = true })
          -- Also map in insert mode, temporarily leave insert mode to execute
          vim.keymap.set("i", lhs, function()
            vim.cmd("stopinsert")
            actions[action]()
            vim.cmd("startinsert!")
          end, { buffer = bufnr, silent = true })
        elseif action == "submit_close" then
          vim.keymap.set("n", lhs, actions[action], { buffer = bufnr, silent = true })
          -- For insert mode, leave insert mode first to ensure :wq works
          vim.keymap.set("i", lhs, function()
            vim.cmd("stopinsert")
            actions[action]()
          end, { buffer = bufnr, silent = true })
        elseif action == "esc" then
          vim.keymap.set("n", lhs, actions[action], { buffer = bufnr, silent = true })
        elseif vim.tbl_contains({ "interrupt", "clear", "next", "prev", "down", "up" }, action) then
          vim.keymap.set({ "n", "v" }, lhs, actions[action], { buffer = bufnr, silent = true })
        else
          -- Default to normal mode for unknown actions
          vim.keymap.set("n", lhs, actions[action], { buffer = bufnr, silent = true })
        end
      end
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

  -- Get configuration for this buffer type and agent
  local aibo_module = require("aibo")
  local cfg = aibo_module.get_buffer_config("prompt", aibo.cmd)

  -- Apply buffer options from configuration
  if cfg.buffer_options then
    for option, value in pairs(cfg.buffer_options) do
      vim.bo[prompt_bufnr][option] = value
    end
  end

  -- Apply window options from configuration
  local winid = vim.api.nvim_get_current_win()
  if cfg.window_options then
    for option, value in pairs(cfg.window_options) do
      vim.wo[winid][option] = value
    end
  end

  -- Get action functions for this buffer
  local actions = require("aibo.actions").prompt(prompt_bufnr)

  -- Apply keymaps from configuration
  if cfg.keymaps then
    apply_keymaps(prompt_bufnr, cfg.keymaps, actions)
  end

  -- Finally, call on_attach if provided
  if cfg.on_attach then
    cfg.on_attach(prompt_bufnr, {
      type = "prompt",
      agent = aibo.cmd,
      aibo = aibo,
      actions = actions,
    })
  end

  -- Set filetype
  vim.bo[prompt_bufnr].filetype = string.format("aibo-prompt.aibo-agent-%s", aibo.cmd)
end

-- Global autocmd for QuitPre
local global_augroup = vim.api.nvim_create_augroup("aibo_prompt_global", { clear = true })
vim.api.nvim_create_autocmd("QuitPre", {
  group = global_augroup,
  pattern = "*",
  nested = true,
  callback = QuitPre,
})

return M
