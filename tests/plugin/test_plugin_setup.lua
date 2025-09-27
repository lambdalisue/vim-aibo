-- Tests for plugin setup and loading (plugin/aibo.lua)

local helpers = require("tests.helpers")
local T = require("mini.test")

-- Test set
local test_set = T.new_set({
  hooks = {
    pre_case = function()
      helpers.setup()
      -- Reload the plugin to ensure commands are created
      vim.cmd("runtime plugin/aibo.lua")
    end,
    post_case = function()
      -- Clear any mocked modules to avoid interfering with other tests
      package.loaded["aibo.integration.claude"] = nil
      package.loaded["aibo.integration.codex"] = nil
      package.loaded["aibo.integration.ollama"] = nil
      helpers.cleanup()
    end,
  },
})

-- Test plugin loading guard
test_set["Plugin loading guard"] = function()
  -- First load should work
  vim.g.loaded_aibo = nil
  vim.cmd("runtime plugin/aibo.lua")
  T.expect.equality(vim.g.loaded_aibo, 1)

  -- Second load should be blocked
  local before_cmds = vim.api.nvim_get_commands({})
  vim.cmd("runtime plugin/aibo.lua")
  local after_cmds = vim.api.nvim_get_commands({})

  -- Command count should remain the same
  T.expect.equality(vim.tbl_count(before_cmds), vim.tbl_count(after_cmds))
end

-- Test Aibo command existence
test_set["Aibo command exists"] = function()
  vim.g.loaded_aibo = nil
  vim.cmd("runtime plugin/aibo.lua")

  local commands = vim.api.nvim_get_commands({})
  T.expect.equality(commands["Aibo"] ~= nil, true)
  T.expect.equality(commands["Aibo"].nargs, "+")
end

-- Test aiboprompt autocmd
test_set["aiboprompt autocmd"] = function()
  vim.g.loaded_aibo = nil
  vim.cmd("runtime plugin/aibo.lua")

  -- Force reload the prompt_window module to ensure autocmds are created
  package.loaded["aibo.internal.prompt_window"] = nil
  require("aibo.internal.prompt_window")

  -- Check that autocmd is created
  local autocmds = vim.api.nvim_get_autocmds({
    group = "aibo_prompt_internal",
    event = "BufWriteCmd",
  })

  T.expect.equality(#autocmds > 0, true)

  -- Find the aiboprompt autocmd
  local found = false
  for _, autocmd in ipairs(autocmds) do
    if autocmd.pattern == "aiboprompt://*" then
      found = true
      break
    end
  end
  T.expect.equality(found, true)
end

return test_set
