local eq = MiniTest.expect.equality
local helpers = require("tests.helpers")

local T = helpers.new_set()

-- Test plugin loading guard
T["Plugin loading guard"] = function()
  -- First load should work
  vim.g.loaded_aibo = nil
  vim.cmd("runtime plugin/aibo.lua")
  eq(vim.g.loaded_aibo, 1)

  -- Second load should be blocked
  local before_cmds = vim.api.nvim_get_commands({})
  vim.cmd("runtime plugin/aibo.lua")
  local after_cmds = vim.api.nvim_get_commands({})

  -- Command count should remain the same
  eq(vim.tbl_count(before_cmds), vim.tbl_count(after_cmds))
end

-- Test Aibo command existence
T["Aibo command exists"] = function()
  vim.g.loaded_aibo = nil
  vim.cmd("runtime plugin/aibo.lua")

  local cmd = helpers.expect.command_exists("Aibo")
  eq(cmd.nargs, "+")
end

-- Test AiboSend command existence
T["AiboSend command exists"] = function()
  vim.g.loaded_aibo = nil
  vim.cmd("runtime plugin/aibo.lua")

  local cmd = helpers.expect.command_exists("AiboSend")
  eq(cmd.nargs, "*")
  eq(cmd.range ~= nil, true)
end

-- Test plugin does not error on load
T["Plugin loads without error"] = function()
  vim.g.loaded_aibo = nil
  local ok, err = pcall(vim.cmd, "runtime plugin/aibo.lua")
  eq(ok, true)
end

return T
