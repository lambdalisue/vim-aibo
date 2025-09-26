local M = {}

---@class AiboBufferConfig
---@field on_attach? fun(bufnr: integer, info: table) Callback for buffer attachment
---@field no_default_mappings? boolean Disable default key mappings

---@class AiboConfig
---@field prompt? AiboBufferConfig Configuration for prompt buffers
---@field console? AiboBufferConfig Configuration for console buffers
---@field agents? table<string, AiboBufferConfig> Agent-specific configurations
---@field submit_delay? integer Delay before submit in ms (default: 100)
---@field prompt_height? integer Height of prompt window (default: 10)

---@type AiboConfig
local defaults = {
  prompt = {
    on_attach = nil,
    no_default_mappings = false,
  },
  console = {
    on_attach = nil,
    no_default_mappings = false,
  },
  -- Agent-specific configurations can be added here
  agents = {},
  submit_delay = 100,
  prompt_height = 10,
}

---@type AiboConfig
local config = vim.deepcopy(defaults)

---Setup function to configure aibo
---@param opts? AiboConfig Configuration options
function M.setup(opts)
  -- Check Neovim version (silently skip if not satisfied)
  if vim.fn.has("nvim-0.10.0") ~= 1 then
    return
  end
  config = vim.tbl_deep_extend("force", config, opts or {})
end

---Get the configuration
---@return AiboConfig Current configuration (cloned)
function M.get_config()
  -- Return a deep copy to prevent accidental modification
  return vim.deepcopy(config)
end

---Get configuration for a specific buffer type
---@param buftype "prompt"|"console" Buffer type
---@return AiboBufferConfig Buffer type configuration
function M.get_buffer_config(buftype)
  return vim.deepcopy(config[buftype] or {})
end

---Get configuration for a specific agent
---@param agent string Agent name (e.g., "claude", "codex")
---@return AiboBufferConfig Configuration for the agent (cloned)
function M.get_agent_config(agent)
  -- Start with base configuration for buffer type
  if agent and config.agents and config.agents[agent] then
    return vim.deepcopy(config.agents[agent])
  end
  return {}
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
    vim.notify(("No aibo instance found in buffer %d"):format(bufnr), vim.log.levels.ERROR, { title = "Aibo" })
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

  -- Convert submit key to terminal codes
  local submit_key = M.termcode.resolve("<CR>")

  vim.defer_fn(function()
    aibo.controller.send(submit_key)
  end, config.submit_delay)

  vim.defer_fn(function()
    aibo.follow()
  end, config.submit_delay)
end

-- Expose termcode as part of the public API
M.termcode = require("aibo.termcode")

return M
