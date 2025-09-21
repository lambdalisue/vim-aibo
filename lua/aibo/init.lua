local M = {}

-- Expose actions for users
M.actions = require("aibo.actions")

---@class AiboBufferConfig
---@field keymaps? table<string, string|string[]|false> Key mappings for buffer actions (string for single, array for multiple, false to disable)
---@field on_attach? fun(bufnr: integer, info: table) Callback for buffer attachment
---@field buffer_options? table<string, any> Buffer-local options (vim.bo)
---@field window_options? table<string, any> Window-local options (vim.wo)

---@class AiboConfig
---@field prompt? AiboBufferConfig Configuration for prompt buffers
---@field console? AiboBufferConfig Configuration for console buffers
---@field agents? table<string, AiboBufferConfig> Agent-specific configurations
---@field submit_delay? integer Delay before submit in ms (default: 100)
---@field prompt_height? integer Height of prompt window (default: 10)

---@type AiboConfig
local defaults = {
  prompt = {
    keymaps = {
      submit = "<CR>",
      submit_close = { "<C-Enter>", "<F5>" },
      esc = "<Esc>",
      interrupt = "<C-c>",
      clear = "<C-l>",
      next = "<C-n>",
      prev = "<C-p>",
      down = "<Down>",
      up = "<Up>",
    },
    buffer_options = {},
    window_options = {
      number = false,
      relativenumber = false,
      signcolumn = "no",
    },
    on_attach = nil,
  },
  console = {
    keymaps = {
      -- Console had these in the original ftplugin
      submit = "<CR>",
      esc = "<Esc>",
      interrupt = "<C-c>",
      clear = "<C-l>",
      next = "<C-n>",
      prev = "<C-p>",
      down = "<Down>",
      up = "<Up>",
    },
    buffer_options = {},
    window_options = {
      number = false,
      relativenumber = false,
      signcolumn = "no",
    },
    on_attach = nil,
  },
  -- Agent-specific configurations (matching the original ftplugin files)
  agents = {
    -- Claude agent with special Claude-specific commands
    claude = {
      on_attach = function(bufnr, info)
        -- Get Claude-specific actions
        local claude_actions = require("aibo.actions").claude(bufnr)

        -- Map Claude specific commands (from original ftplugin/aibo-agent-claude.lua)
        vim.keymap.set({ "n", "v" }, "<S-Tab>", claude_actions.mode, { buffer = bufnr })
        vim.keymap.set({ "n", "v" }, "<F2>", claude_actions.mode, { buffer = bufnr })
        vim.keymap.set({ "n", "v" }, "<C-o>", claude_actions.verbose, { buffer = bufnr })
        vim.keymap.set({ "n", "v" }, "<C-t>", claude_actions.todo, { buffer = bufnr })
        vim.keymap.set({ "n", "v" }, "<C-_>", claude_actions.undo, { buffer = bufnr })
        vim.keymap.set({ "n", "v" }, "<C-->", claude_actions.undo, { buffer = bufnr })
        vim.keymap.set({ "n", "v" }, "<C-z>", claude_actions.suspend, { buffer = bufnr })
        vim.keymap.set({ "n", "v" }, "<C-v>", claude_actions.paste, { buffer = bufnr })

        -- Insert mode mappings (use <C-\><C-o> to execute normal mode command)
        vim.keymap.set(
          "i",
          "<S-Tab>",
          "<C-\\><C-o>:lua require('aibo.actions').claude(" .. bufnr .. ").mode()<CR>",
          { buffer = bufnr }
        )
        vim.keymap.set(
          "i",
          "<F2>",
          "<C-\\><C-o>:lua require('aibo.actions').claude(" .. bufnr .. ").mode()<CR>",
          { buffer = bufnr }
        )
        vim.keymap.set(
          "i",
          "<C-o>",
          "<C-\\><C-o>:lua require('aibo.actions').claude(" .. bufnr .. ").verbose()<CR>",
          { buffer = bufnr }
        )
        vim.keymap.set(
          "i",
          "<C-t>",
          "<C-\\><C-o>:lua require('aibo.actions').claude(" .. bufnr .. ").todo()<CR>",
          { buffer = bufnr }
        )
        vim.keymap.set(
          "i",
          "<C-_>",
          "<C-\\><C-o>:lua require('aibo.actions').claude(" .. bufnr .. ").undo()<CR>",
          { buffer = bufnr }
        )
        vim.keymap.set(
          "i",
          "<C-->",
          "<C-\\><C-o>:lua require('aibo.actions').claude(" .. bufnr .. ").undo()<CR>",
          { buffer = bufnr }
        )
        vim.keymap.set(
          "i",
          "<C-z>",
          "<C-\\><C-o>:lua require('aibo.actions').claude(" .. bufnr .. ").suspend()<CR>",
          { buffer = bufnr }
        )
        vim.keymap.set(
          "i",
          "<C-v>",
          "<C-\\><C-o>:lua require('aibo.actions').claude(" .. bufnr .. ").paste()<CR>",
          { buffer = bufnr }
        )
      end,
    },
    -- Codex agent with special Codex-specific commands
    codex = {
      on_attach = function(bufnr, info)
        -- Get Codex-specific actions
        local codex_actions = require("aibo.actions").codex(bufnr)

        -- Map Codex specific commands (from original ftplugin/aibo-agent-codex.lua)
        vim.keymap.set({ "n", "v" }, "<C-t>", codex_actions.transcript, { buffer = bufnr })
        vim.keymap.set({ "n", "v" }, "<Home>", codex_actions.home, { buffer = bufnr })
        vim.keymap.set({ "n", "v" }, "<End>", codex_actions.end_key, { buffer = bufnr })
        vim.keymap.set({ "n", "v" }, "<PageUp>", codex_actions.page_up, { buffer = bufnr })
        vim.keymap.set({ "n", "v" }, "<PageDown>", codex_actions.page_down, { buffer = bufnr })
        vim.keymap.set({ "n", "v" }, "q", codex_actions.quit, { buffer = bufnr })
      end,
    },
  },
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
  local cfg = vim.deepcopy(config[buftype] or {})

  -- Merge agent-specific configuration if it exists
  if agent and config.agents and config.agents[agent] then
    -- Merge keymaps
    if config.agents[agent].keymaps then
      cfg.keymaps = vim.tbl_deep_extend("force", cfg.keymaps or {}, config.agents[agent].keymaps)
    end

    -- Merge buffer options
    if config.agents[agent].buffer_options then
      cfg.buffer_options = vim.tbl_deep_extend("force", cfg.buffer_options or {}, config.agents[agent].buffer_options)
    end

    -- Merge window options
    if config.agents[agent].window_options then
      cfg.window_options = vim.tbl_deep_extend("force", cfg.window_options or {}, config.agents[agent].window_options)
    end

    -- Chain on_attach functions
    local base_on_attach = cfg.on_attach
    local agent_on_attach = config.agents[agent].on_attach

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

  -- Convert submit key to terminal codes if needed
  local submit_key = "<CR>"
  local prompt_cfg = M.get_buffer_config("prompt", aibo.cmd)
  if prompt_cfg.keymaps and prompt_cfg.keymaps.submit then
    submit_key = prompt_cfg.keymaps.submit
  end
  submit_key = vim.api.nvim_replace_termcodes(submit_key, true, false, true)

  vim.defer_fn(function()
    aibo.controller.send(submit_key)
  end, config.submit_delay)

  vim.defer_fn(function()
    aibo.follow()
  end, config.submit_delay)
end

return M
