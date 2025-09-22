-- Tests for plugin command and completions

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

-- Test command completion for tool names
test_set["Tool name completion"] = function()
  vim.g.loaded_aibo = nil
  vim.cmd("runtime plugin/aibo.lua")

  -- Get the completion function
  local complete_fn = _G._aibo_complete

  -- Test completing tool names
  local completions = complete_fn("", "Aibo ", 5)
  T.expect.equality(vim.tbl_contains(completions, "claude"), true)
  T.expect.equality(vim.tbl_contains(completions, "codex"), true)
  T.expect.equality(vim.tbl_contains(completions, "ollama"), true)

  -- Test partial completion
  completions = complete_fn("cl", "Aibo cl", 7)
  T.expect.equality(vim.tbl_contains(completions, "claude"), true)
  T.expect.equality(vim.tbl_contains(completions, "codex"), false)
  T.expect.equality(vim.tbl_contains(completions, "ollama"), false)

  -- Test with "co"
  completions = complete_fn("co", "Aibo co", 7)
  T.expect.equality(vim.tbl_contains(completions, "claude"), false)
  T.expect.equality(vim.tbl_contains(completions, "codex"), true)
  T.expect.equality(vim.tbl_contains(completions, "ollama"), false)
end

-- Test command completion delegation to integration modules
test_set["Integration module delegation"] = function()
  vim.g.loaded_aibo = nil
  vim.cmd("runtime plugin/aibo.lua")

  -- Get the completion function
  local complete_fn = _G._aibo_complete

  -- Save original modules
  local orig_claude = package.loaded["aibo.integration.claude"]
  local orig_codex = package.loaded["aibo.integration.codex"]
  local orig_ollama = package.loaded["aibo.integration.ollama"]

  -- Mock claude integration module
  package.loaded["aibo.integration.claude"] = {
    get_command_completions = function(arglead, cmdline, cursorpos)
      return { "--test-claude-arg" }
    end,
  }

  -- Test Claude delegation
  local completions = complete_fn("", "Aibo claude ", 12)
  T.expect.equality(vim.tbl_contains(completions, "--test-claude-arg"), true)

  -- Mock codex integration module
  package.loaded["aibo.integration.codex"] = {
    get_command_completions = function(arglead, cmdline, cursorpos)
      return { "--test-codex-arg" }
    end,
  }

  -- Test Codex delegation
  completions = complete_fn("", "Aibo codex ", 11)
  T.expect.equality(vim.tbl_contains(completions, "--test-codex-arg"), true)

  -- Mock ollama integration module
  package.loaded["aibo.integration.ollama"] = {
    get_command_completions = function(arglead, cmdline, cursorpos)
      return { "test-model" }
    end,
  }

  -- Test Ollama delegation
  completions = complete_fn("", "Aibo ollama ", 12)
  T.expect.equality(vim.tbl_contains(completions, "test-model"), true)

  -- Restore original modules
  package.loaded["aibo.integration.claude"] = orig_claude
  package.loaded["aibo.integration.codex"] = orig_codex
  package.loaded["aibo.integration.ollama"] = orig_ollama
end

-- Test known tool detection
test_set["Known tool detection"] = function()
  vim.g.loaded_aibo = nil
  vim.cmd("runtime plugin/aibo.lua")

  local complete_fn = _G._aibo_complete

  -- Save original module
  local orig_claude = package.loaded["aibo.integration.claude"]

  -- When tool is "claude", it should delegate to claude module
  package.loaded["aibo.integration.claude"] = {
    get_command_completions = function(arglead, cmdline, cursorpos)
      return { "--claude-specific" }
    end,
  }

  local completions = complete_fn("--cl", "Aibo claude --cl", 16)
  T.expect.equality(vim.tbl_contains(completions, "--claude-specific"), true)

  -- Unknown tool should not delegate
  completions = complete_fn("", "Aibo unknown ", 13)
  T.expect.equality(#completions, 0)

  -- Restore original module
  package.loaded["aibo.integration.claude"] = orig_claude
end

-- Test error handling in completion
test_set["Completion error handling"] = function()
  vim.g.loaded_aibo = nil
  vim.cmd("runtime plugin/aibo.lua")

  local complete_fn = _G._aibo_complete

  -- Save original module
  local orig_claude = package.loaded["aibo.integration.claude"]

  -- Mock integration module that throws error
  package.loaded["aibo.integration.claude"] = {
    get_command_completions = function(arglead, cmdline, cursorpos)
      error("Test error")
    end,
  }

  -- Should not throw, just return empty
  local ok, completions = pcall(complete_fn, "", "Aibo claude ", 12)
  T.expect.equality(ok, true)
  T.expect.equality(#completions, 0)

  -- Restore original module
  package.loaded["aibo.integration.claude"] = orig_claude
end

-- Test aiboprompt autocmd
test_set["aiboprompt autocmd"] = function()
  vim.g.loaded_aibo = nil
  vim.cmd("runtime plugin/aibo.lua")

  -- Check that autocmd is created
  local autocmds = vim.api.nvim_get_autocmds({
    group = "aibo_plugin",
    event = "BufReadCmd",
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
