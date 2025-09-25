-- Tests for :Aibo command functionality (lua/aibo/command/aibo.lua)

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

-- Test command completion for tool names
test_set["Tool name completion"] = function()
  -- Get the completion function
  local complete_fn = require("aibo.command.aibo")._internal.complete

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
  -- Get the completion function
  local complete_fn = require("aibo.command.aibo")._internal.complete

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
  local complete_fn = require("aibo.command.aibo")._internal.complete

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
  local complete_fn = require("aibo.command.aibo")._internal.complete

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

return test_set
