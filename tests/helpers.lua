-- Test helpers for aibo.nvim

local M = {}

-- Create a clean test environment
function M.setup()
  -- Clear any existing aibo configuration but keep integration modules
  package.loaded["aibo"] = nil
  package.loaded["aibo.internal.console"] = nil
  package.loaded["aibo.internal.prompt"] = nil
  package.loaded["aibo.internal.utils"] = nil
  -- Don't clear integration modules as they are stateless and tests need them

  -- Reset global variables
  vim.g.loaded_aibo = nil
  _G._aibo_complete = nil

  -- Clear autocommands
  pcall(vim.api.nvim_clear_autocmds, { group = "aibo_plugin" })
end

-- Clean up after tests
function M.cleanup()
  -- Close all buffers
  for _, buf in ipairs(vim.api.nvim_list_bufs()) do
    if vim.api.nvim_buf_is_valid(buf) then
      pcall(vim.api.nvim_buf_delete, buf, { force = true })
    end
  end

  -- Clear all windows except the current one
  local current_win = vim.api.nvim_get_current_win()
  for _, win in ipairs(vim.api.nvim_list_wins()) do
    if win ~= current_win then
      pcall(vim.api.nvim_win_close, win, true)
    end
  end
end

-- Mock vim.fn.executable to simulate command availability
function M.mock_executable(commands)
  local original = vim.fn.executable
  vim.fn.executable = function(cmd)
    if commands[cmd] ~= nil then
      return commands[cmd] and 1 or 0
    end
    return original(cmd)
  end
  return function()
    vim.fn.executable = original
  end
end

-- Mock vim.fn.system to simulate command output
function M.mock_system(outputs)
  local original = vim.fn.system
  vim.fn.system = function(cmd)
    local cmd_str = type(cmd) == "table" and table.concat(cmd, " ") or cmd
    for pattern, output in pairs(outputs) do
      if cmd_str:match(pattern) then
        -- vim.v.shell_error is read-only, skip setting it
        return output.result or ""
      end
    end
    return original(cmd)
  end
  return function()
    vim.fn.system = original
  end
end

-- Create a test buffer with specific options
function M.create_test_buffer(opts)
  opts = opts or {}
  local buf = vim.api.nvim_create_buf(false, true)

  if opts.filetype then
    vim.api.nvim_buf_set_option(buf, "filetype", opts.filetype)
  end

  if opts.content then
    vim.api.nvim_buf_set_lines(buf, 0, -1, false, opts.content)
  end

  if opts.name then
    vim.api.nvim_buf_set_name(buf, opts.name)
  end

  return buf
end

-- Wait for a condition to be true
function M.wait_for(condition, timeout)
  timeout = timeout or 1000
  local start = vim.loop.now()
  while not condition() and (vim.loop.now() - start) < timeout do
    vim.wait(10)
  end
  return condition()
end

-- Capture output from a function
function M.capture_output(fn)
  local output = {}
  local original_notify = vim.notify
  vim.notify = function(msg)
    table.insert(output, msg)
  end

  local ok, result = pcall(fn)

  vim.notify = original_notify
  return ok, result, output
end

return M
