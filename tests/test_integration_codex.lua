-- Tests for Codex integration module

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

-- Test Codex command availability
test_set["Codex is_available"] = function()
  local codex = require("aibo.integration.codex")

  -- Mock executable
  local restore = helpers.mock_executable({
    codex = true,
  })

  T.expect.equality(codex.is_available(), true)

  -- Test when not available
  vim.fn.executable = function()
    return 0
  end
  T.expect.equality(codex.is_available(), false)

  restore()
end

-- Test Codex command completions
test_set["Codex argument completions"] = function()
  local codex = require("aibo.integration.codex")

  -- Test completing arguments at the start
  local completions = codex.get_command_completions("", "codex ", 6)
  T.expect.equality(vim.tbl_contains(completions, "--model"), true)
  T.expect.equality(vim.tbl_contains(completions, "--sandbox"), true)
  T.expect.equality(vim.tbl_contains(completions, "--oss"), true)
  T.expect.equality(vim.tbl_contains(completions, "resume"), true)

  -- Test completing partial argument
  completions = codex.get_command_completions("--mod", "codex --mod", 11)
  T.expect.equality(vim.tbl_contains(completions, "--model"), true)
  T.expect.equality(vim.tbl_contains(completions, "--sandbox"), false)

  -- Test completing short form
  completions = codex.get_command_completions("-m", "codex -m", 8)
  T.expect.equality(vim.tbl_contains(completions, "-m"), true)
  T.expect.equality(vim.tbl_contains(completions, "--model"), false)
end

-- Test Codex subcommand completions
test_set["Codex subcommand completions"] = function()
  local codex = require("aibo.integration.codex")

  -- Test completing "resume"
  local completions = codex.get_command_completions("res", "codex res", 9)
  T.expect.equality(vim.tbl_contains(completions, "resume"), true)
  T.expect.equality(vim.tbl_contains(completions, "resume --last"), true)

  -- Test completing full "resume"
  completions = codex.get_command_completions("resume", "codex resume", 12)
  T.expect.equality(vim.tbl_contains(completions, "resume"), true)
  T.expect.equality(vim.tbl_contains(completions, "resume --last"), true)

  -- Test with space after resume
  completions = codex.get_command_completions("", "codex resume ", 13)
  -- Should show regular arguments, not subcommands
  T.expect.equality(vim.tbl_contains(completions, "--model"), true)
end

-- Test Codex model completions
test_set["Codex model value completions"] = function()
  local codex = require("aibo.integration.codex")

  -- Test completing model values
  local completions = codex.get_command_completions("", "codex --model ", 14)
  T.expect.equality(vim.tbl_contains(completions, "o3"), true)
  T.expect.equality(vim.tbl_contains(completions, "claude-3.5-sonnet"), true)
  T.expect.equality(vim.tbl_contains(completions, "gpt-4-turbo"), true)
  T.expect.equality(vim.tbl_contains(completions, "gemini-pro"), true)

  -- Test partial model completion
  completions = codex.get_command_completions("claude", "codex --model claude", 21)
  T.expect.equality(vim.tbl_contains(completions, "claude-3.5-sonnet"), true)
  T.expect.equality(vim.tbl_contains(completions, "o3"), false)

  -- Test with short form
  completions = codex.get_command_completions("", "codex -m ", 9)
  T.expect.equality(vim.tbl_contains(completions, "o3"), true)
  T.expect.equality(vim.tbl_contains(completions, "claude-3.5-sonnet"), true)
end

-- Test Codex sandbox completions
test_set["Codex sandbox value completions"] = function()
  local codex = require("aibo.integration.codex")

  -- Test completing sandbox modes
  local completions = codex.get_command_completions("", "codex --sandbox ", 16)
  T.expect.equality(vim.tbl_contains(completions, "none"), true)
  T.expect.equality(vim.tbl_contains(completions, "read-only"), true)
  T.expect.equality(vim.tbl_contains(completions, "restricted"), true)
  T.expect.equality(vim.tbl_contains(completions, "full"), true)

  -- Test partial completion
  completions = codex.get_command_completions("re", "codex --sandbox re", 19)
  T.expect.equality(vim.tbl_contains(completions, "read-only"), true)
  T.expect.equality(vim.tbl_contains(completions, "restricted"), true)
  T.expect.equality(vim.tbl_contains(completions, "none"), false)

  -- Test with short form
  completions = codex.get_command_completions("", "codex -s ", 9)
  T.expect.equality(vim.tbl_contains(completions, "none"), true)
  T.expect.equality(vim.tbl_contains(completions, "full"), true)
end

-- Test Codex image file completions
test_set["Codex image file completions"] = function()
  local codex = require("aibo.integration.codex")

  -- Mock getcompletion for files
  local original_getcompletion = vim.fn.getcompletion
  vim.fn.getcompletion = function(arg, type)
    if type == "file" then
      return { "image1.png", "image2.jpg", "document.pdf" }
    end
    return {}
  end

  -- Test --image completion
  local completions = codex.get_command_completions("", "codex --image ", 14)
  T.expect.equality(vim.tbl_contains(completions, "image1.png"), true)
  T.expect.equality(vim.tbl_contains(completions, "image2.jpg"), true)
  T.expect.equality(vim.tbl_contains(completions, "document.pdf"), true)

  -- Test with short form -i
  completions = codex.get_command_completions("", "codex -i ", 9)
  T.expect.equality(vim.tbl_contains(completions, "image1.png"), true)

  vim.fn.getcompletion = original_getcompletion
end

-- Test Codex help text
test_set["Codex help text"] = function()
  local codex = require("aibo.integration.codex")

  local help = codex.get_help()
  T.expect.equality(#help > 0, true)

  -- Check for key content
  local help_text = table.concat(help, "\n")
  T.expect.equality(help_text:match("Codex arguments") ~= nil, true)
  T.expect.equality(help_text:match("--model") ~= nil, true)
  T.expect.equality(help_text:match("--sandbox") ~= nil, true)
  T.expect.equality(help_text:match("resume") ~= nil, true)
  T.expect.equality(help_text:match("Subcommands") ~= nil, true)
end

return test_set
