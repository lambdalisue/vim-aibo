local M = {}

---@class AiboConfig
---@field submit_key? string Key to submit input (default: '<CR>')
---@field submit_delay? integer Delay before submit in ms (default: 100)
---@field prompt_height? integer Height of prompt window (default: 10)

---@type AiboConfig
local defaults = {
  submit_key = '<CR>',
  submit_delay = 100,
  prompt_height = 10,
}

---@type AiboConfig
local config = vim.deepcopy(defaults)

-- Track if setup has been called
local setup_called = false

---Setup function to configure aibo
---@param opts? AiboConfig Configuration options
function M.setup(opts)
  if setup_called then
    vim.notify('Aibo setup() has already been called', vim.log.levels.WARN, { title = 'Aibo' })
    return
  end
  setup_called = true

  opts = opts or {}
  config = vim.tbl_deep_extend('force', defaults, opts)

  -- Process submit_key - convert to terminal codes
  if type(config.submit_key) == 'string' then
    config.submit_key = vim.api.nvim_replace_termcodes(config.submit_key, true, false, true)
  end
end

---Get the configuration
---@return AiboConfig Current configuration
function M.get_config()
  return config
end

---@class AiboInstance
---@field cmd string Command name
---@field args string[] Command arguments
---@field controller table Controller instance
---@field follow function Function to follow terminal output

---Get aibo instance from buffer
---@param bufnr? integer Buffer number
---@return AiboInstance|nil Aibo instance or nil if not found
local function get_aibo(bufnr)
  bufnr = bufnr or vim.api.nvim_get_current_buf()
  local aibo = vim.b[bufnr].aibo
  if not aibo then
    vim.notify(('No aibo instance found in buffer %d'):format(bufnr), vim.log.levels.ERROR, { title = 'Aibo' })
    return nil
  end
  return aibo
end

---Send data to the terminal
---@param data string Data to send
---@param bufnr? integer Buffer number
---@return nil
function M.send(data, bufnr)
  local aibo = get_aibo(bufnr)
  if aibo then
    aibo.controller.send(data)
  end
end

---Submit data to the terminal with automatic return key
---@param data string Data to submit
---@param bufnr? integer Buffer number
---@return nil
function M.submit(data, bufnr)
  local aibo = get_aibo(bufnr)
  if not aibo then
    return
  end

  aibo.controller.send(data)

  vim.defer_fn(function()
    aibo.controller.send(config.submit_key)
  end, config.submit_delay)

  vim.defer_fn(function()
    aibo.follow()
  end, config.submit_delay)
end

return M