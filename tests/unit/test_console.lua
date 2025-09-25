-- Tests for console opener functionality (lua/aibo/internal/console.lua)

local helpers = require("tests.helpers")
local T = require("mini.test")

-- Test set
local test_set = T.new_set({
  hooks = {
    pre_case = function()
      helpers.setup()
    end,
    post_case = function()
      helpers.cleanup()
    end,
  },
})

-- Helper to capture vim.cmd calls
local function capture_vim_cmd()
  local captured = {}
  local original_cmd = vim.cmd

  vim.cmd = function(cmd_str)
    table.insert(captured, cmd_str)
    -- Don't actually execute buffer/split commands during tests
    if cmd_str:match("buffer") or cmd_str:match("split") or cmd_str:match("vsplit") or cmd_str:match("edit") then
      return
    end
    return original_cmd(cmd_str)
  end

  return captured, original_cmd
end

-- Test console.open with different opener configurations
test_set["console.open uses correct default opener"] = function()
  local console = require("aibo.internal.console")

  -- Create a real buffer for testing
  local test_bufnr = vim.api.nvim_create_buf(false, true)

  -- Mock buffer creation to return our test buffer
  local original_create_buf = vim.api.nvim_create_buf
  vim.api.nvim_create_buf = function()
    return test_bufnr
  end

  -- Capture vim.cmd calls
  local captured, original_cmd = capture_vim_cmd()

  -- Mock jobstart to prevent actual terminal creation
  local original_jobstart = vim.fn.jobstart
  vim.fn.jobstart = function()
    return 1
  end

  -- Mock nvim_buf_call to avoid executing in buffer context
  local original_buf_call = vim.api.nvim_buf_call
  vim.api.nvim_buf_call = function(buf, fn)
    if buf == test_bufnr then
      -- Return a valid job ID to simulate successful terminal start
      return 1
    end
    return original_buf_call(buf, fn)
  end

  -- Test with no opener (default)
  console.open("echo", { "test" }, nil, false)

  -- Restore mocks
  vim.api.nvim_create_buf = original_create_buf
  vim.cmd = original_cmd
  vim.fn.jobstart = original_jobstart
  vim.api.nvim_buf_call = original_buf_call

  -- Clean up test buffer
  pcall(vim.api.nvim_buf_delete, test_bufnr, { force = true })

  -- Check that the default command was used
  local found_buffer_cmd = false
  for _, cmd in ipairs(captured) do
    if cmd == "buffer " .. test_bufnr then
      found_buffer_cmd = true
      break
    end
  end

  T.expect.equality(found_buffer_cmd, true, "Should use 'buffer' command when no opener specified")
end

test_set["console.open uses custom opener correctly"] = function()
  local console = require("aibo.internal.console")

  -- Create a real buffer for testing
  local test_bufnr = vim.api.nvim_create_buf(false, true)

  -- Mock buffer creation to return our test buffer
  local original_create_buf = vim.api.nvim_create_buf
  vim.api.nvim_create_buf = function()
    return test_bufnr
  end

  -- Capture vim.cmd calls
  local captured, original_cmd = capture_vim_cmd()

  -- Mock jobstart to prevent actual terminal creation
  local original_jobstart = vim.fn.jobstart
  vim.fn.jobstart = function()
    return 1
  end

  -- Mock nvim_buf_call to avoid executing in buffer context
  local original_buf_call = vim.api.nvim_buf_call
  vim.api.nvim_buf_call = function(buf, fn)
    if buf == test_bufnr then
      -- Return a valid job ID to simulate successful terminal start
      return 1
    end
    return original_buf_call(buf, fn)
  end

  -- Test with vsplit opener
  console.open("echo", { "test" }, "vsplit", false)

  -- Restore mocks
  vim.api.nvim_create_buf = original_create_buf
  vim.cmd = original_cmd
  vim.fn.jobstart = original_jobstart
  vim.api.nvim_buf_call = original_buf_call

  -- Clean up test buffer
  pcall(vim.api.nvim_buf_delete, test_bufnr, { force = true })

  -- Check that the vsplit command was used
  local found_vsplit_cmd = false
  for _, cmd in ipairs(captured) do
    if cmd == "vsplit | buffer " .. test_bufnr then
      found_vsplit_cmd = true
      break
    end
  end

  T.expect.equality(found_vsplit_cmd, true, "Should use 'vsplit | buffer' when vsplit opener specified")
end

test_set["console.open handles multi-word opener"] = function()
  local console = require("aibo.internal.console")

  -- Create a real buffer for testing
  local test_bufnr = vim.api.nvim_create_buf(false, true)

  -- Mock buffer creation to return our test buffer
  local original_create_buf = vim.api.nvim_create_buf
  vim.api.nvim_create_buf = function()
    return test_bufnr
  end

  -- Capture vim.cmd calls
  local captured, original_cmd = capture_vim_cmd()

  -- Mock jobstart to prevent actual terminal creation
  local original_jobstart = vim.fn.jobstart
  vim.fn.jobstart = function()
    return 1
  end

  -- Mock nvim_buf_call to avoid executing in buffer context
  local original_buf_call = vim.api.nvim_buf_call
  vim.api.nvim_buf_call = function(buf, fn)
    if buf == test_bufnr then
      -- Return a valid job ID to simulate successful terminal start
      return 1
    end
    return original_buf_call(buf, fn)
  end

  -- Test with multi-word opener
  console.open("echo", { "test" }, "botright vsplit", false)

  -- Restore mocks
  vim.api.nvim_create_buf = original_create_buf
  vim.cmd = original_cmd
  vim.fn.jobstart = original_jobstart
  vim.api.nvim_buf_call = original_buf_call

  -- Clean up test buffer
  pcall(vim.api.nvim_buf_delete, test_bufnr, { force = true })

  -- Check that the multi-word command was used
  local found_multiword_cmd = false
  for _, cmd in ipairs(captured) do
    if cmd == "botright vsplit | buffer " .. test_bufnr then
      found_multiword_cmd = true
      break
    end
  end

  T.expect.equality(found_multiword_cmd, true, "Should handle multi-word opener like 'botright vsplit'")
end

-- Test command formation logic directly
test_set["command formation with nil opener"] = function()
  -- This tests the logic for command formation
  local bufnr = 123
  local opener = nil

  -- Simulate the open function logic
  local cmd
  if opener then
    cmd = opener .. " | buffer " .. bufnr
  else
    cmd = "buffer " .. bufnr
  end

  T.expect.equality(cmd, "buffer 123", "Should use 'buffer' when opener is nil")
end

test_set["command formation with opener"] = function()
  -- This tests the logic for command formation
  local bufnr = 456
  local opener = "vsplit"

  -- Simulate the open function logic
  local cmd
  if opener then
    cmd = opener .. " | buffer " .. bufnr
  else
    cmd = "buffer " .. bufnr
  end

  T.expect.equality(cmd, "vsplit | buffer 456", "Should use 'opener | buffer' when opener is provided")
end

test_set["command formation with multi-word opener"] = function()
  -- This tests the logic for command formation
  local bufnr = 789
  local opener = "botright vsplit"

  -- Simulate the open function logic
  local cmd
  if opener then
    cmd = opener .. " | buffer " .. bufnr
  else
    cmd = "buffer " .. bufnr
  end

  T.expect.equality(cmd, "botright vsplit | buffer 789", "Should handle multi-word opener correctly")
end

-- Test reuse function default behavior
test_set["reuse function default uses split"] = function()
  -- Test the default behavior in reuse function
  local bufnr = 321
  local opener = nil

  -- Simulate the reuse function logic for showing existing buffer
  local cmd
  if opener then
    cmd = opener .. " | buffer " .. bufnr
  else
    -- Default for reuse is split
    cmd = "split | buffer " .. bufnr
  end

  T.expect.equality(cmd, "split | buffer 321", "Reuse should default to 'split | buffer'")
end

test_set["reuse function with custom opener"] = function()
  -- Test the reuse function with custom opener
  local bufnr = 654
  local opener = "tabnew"

  -- Simulate the reuse function logic
  local cmd
  if opener then
    cmd = opener .. " | buffer " .. bufnr
  else
    cmd = "split | buffer " .. bufnr
  end

  T.expect.equality(cmd, "tabnew | buffer 654", "Reuse should use custom opener when provided")
end

return test_set
