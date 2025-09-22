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
local config = nil

-- Track if setup has been called
local setup_called = false

---Setup function to configure aibo
---@param opts? AiboConfig Configuration options
function M.setup(opts)
  if setup_called then
    vim.notify("Aibo setup() has already been called", vim.log.levels.WARN, { title = "Aibo" })
    return
  end
  setup_called = true

  -- Check Neovim version
  if vim.fn.has("nvim-0.10.0") ~= 1 then
    vim.api.nvim_err_writeln("nvim-aibo requires Neovim 0.10.0 or later")
    return
  end

  opts = opts or {}
  config = vim.tbl_deep_extend("force", defaults, opts)

  -- Setup autocommands
  local augroup = vim.api.nvim_create_augroup("aibo_plugin", { clear = true })
  vim.api.nvim_create_autocmd("BufReadCmd", {
    group = augroup,
    pattern = "aiboprompt://*",
    nested = true,
    callback = function()
      local bufnr = vim.fn.expand("<abuf>")
      require("aibo.internal.prompt").init(tonumber(bufnr))
    end,
  })

  -- Create user command
  vim.api.nvim_create_user_command("Aibo", function(cmd_opts)
    local args = vim.split(cmd_opts.args, "%s+")
    local cmd = table.remove(args, 1)
    require("aibo.internal.console").open(cmd, args)
  end, {
    nargs = "+",
    desc = "Open Aibo console with specified command",
  })
end

---Get the configuration
---@return AiboConfig Current configuration
function M.get_config()
  if not setup_called then
    vim.notify("Aibo setup() must be called before using the plugin", vim.log.levels.ERROR, { title = "Aibo" })
    return defaults
  end
  return config
end

---Get configuration for a specific agent
---@param agent string Agent name (e.g., "claude", "codex")
---@return AiboBufferConfig Configuration for the agent
function M.get_agent_config(agent)
  if not setup_called then
    vim.notify("Aibo setup() must be called before using the plugin", vim.log.levels.ERROR, { title = "Aibo" })
    return {}
  end

  -- Start with base configuration for buffer type
  if agent and config.agents and config.agents[agent] then
    return config.agents[agent]
  end
  return {}
end

---Get configuration for a specific buffer type and agent
---@param buftype "prompt"|"console" Buffer type
---@param agent? string Agent name (e.g., "claude", "codex")
---@return AiboBufferConfig Configuration for the buffer
function M.get_buffer_config(buftype, agent)
  if not setup_called then
    vim.notify("Aibo setup() must be called before using the plugin", vim.log.levels.ERROR, { title = "Aibo" })
    return {}
  end

  -- Start with base configuration for buffer type
  local cfg = config[buftype] or {}

  -- Merge agent-specific configuration if it exists
  if agent and config.agents and config.agents[agent] then
    -- Chain on_attach functions
    local base_on_attach = cfg.on_attach
    local agent_on_attach = config.agents[agent].on_attach

    --- Deep copy to avoid mutating original configs
    cfg = vim.deepcopy(cfg)
    if base_on_attach and agent_on_attach then
      cfg.on_attach = function(bufnr, info)
        base_on_attach(bufnr, info)
        agent_on_attach(bufnr, info)
      end
    elseif agent_on_attach then
      cfg.on_attach = agent_on_attach
    end
  end

  return cfg
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
  if not setup_called then
    vim.notify("Aibo setup() must be called before using the plugin", vim.log.levels.ERROR, { title = "Aibo" })
    return nil
  end
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
  local submit_key = vim.api.nvim_replace_termcodes("<CR>", true, false, true)

  vim.defer_fn(function()
    aibo.controller.send(submit_key)
  end, config.submit_delay)

  vim.defer_fn(function()
    aibo.follow()
  end, config.submit_delay)
end

return M
