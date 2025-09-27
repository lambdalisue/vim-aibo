local eq = MiniTest.expect.equality
local helpers = require("tests.helpers")

local T = helpers.new_set()

-- Test Codex is_available
T["Codex is_available"] = function()
  local codex = require("aibo.integration.codex")

  -- Mock executable
  local original_executable = vim.fn.executable
  vim.fn.executable = function(cmd)
    if cmd == "codex" then
      return 1
    end
    return 0
  end

  eq(codex.is_available(), true)

  -- Test when not available
  vim.fn.executable = function()
    return 0
  end
  eq(codex.is_available(), false)

  -- Restore
  vim.fn.executable = original_executable
end

-- Test Codex argument completions
T["Codex argument completions"] = function()
  local codex = require("aibo.integration.codex")

  -- Test completing arguments at the start
  local completions = codex.get_command_completions("", "codex ", 6)
  eq(vim.tbl_contains(completions, "--model"), true)
  eq(vim.tbl_contains(completions, "--ask-for-approval"), true)
  eq(vim.tbl_contains(completions, "--cd"), true)
  eq(vim.tbl_contains(completions, "--full-auto"), true)
  eq(vim.tbl_contains(completions, "--image"), true)
  eq(vim.tbl_contains(completions, "resume"), true)

  -- Test things that should NOT be in the new implementation
  eq(vim.tbl_contains(completions, "--config"), false)
  eq(vim.tbl_contains(completions, "--profile"), false)
  eq(vim.tbl_contains(completions, "--sandbox"), false)
  eq(vim.tbl_contains(completions, "--oss"), false)
  eq(vim.tbl_contains(completions, "exec"), false) -- Non-interactive

  -- Test completing partial argument
  completions = codex.get_command_completions("--mod", "codex --mod", 11)
  eq(vim.tbl_contains(completions, "--model"), true)
  eq(vim.tbl_contains(completions, "--ask-for-approval"), false)

  -- Test completing short forms
  completions = codex.get_command_completions("-m", "codex -m", 8)
  eq(vim.tbl_contains(completions, "-m"), true)
  eq(vim.tbl_contains(completions, "--model"), false)

  completions = codex.get_command_completions("-a", "codex -a", 8)
  eq(vim.tbl_contains(completions, "-a"), true)

  completions = codex.get_command_completions("-C", "codex -C", 8)
  eq(vim.tbl_contains(completions, "-C"), true)

  completions = codex.get_command_completions("-i", "codex -i", 8)
  eq(vim.tbl_contains(completions, "-i"), true)
end

-- Test Codex subcommand completions
T["Codex subcommand completions"] = function()
  local codex = require("aibo.integration.codex")

  -- Test completing "resume"
  local completions = codex.get_command_completions("res", "codex res", 9)
  eq(vim.tbl_contains(completions, "resume"), true)

  -- Test that non-interactive subcommands are NOT there
  eq(vim.tbl_contains(completions, "exec"), false)
  eq(vim.tbl_contains(completions, "completion"), false)

  -- Test completing full "resume" - when already typed, should offer other options or be empty
  completions = codex.get_command_completions("resume", "codex resume", 12)
  -- When "resume" is fully typed, it's recognized as a complete subcommand
  -- The completion list might be empty or contain other valid options
  eq(type(completions), "table")

  -- Test with space after resume - should show --last option
  completions = codex.get_command_completions("", "codex resume ", 13)
  eq(vim.tbl_contains(completions, "--last"), true)
  -- Should also show regular arguments
  eq(vim.tbl_contains(completions, "--model"), true)

  -- Test completing --last after resume
  completions = codex.get_command_completions("--l", "codex resume --l", 17)
  eq(vim.tbl_contains(completions, "--last"), true)
end

-- Test Codex model completions
T["Codex model value completions"] = function()
  local codex = require("aibo.integration.codex")

  -- Test completing model values - OpenAI Codex doesn't have predefined model list
  local completions = codex.get_command_completions("", "codex --model ", 14)
  eq(#completions, 0) -- No predefined values

  -- Test with short form
  completions = codex.get_command_completions("", "codex -m ", 9)
  eq(#completions, 0) -- No predefined values
end

-- Test Codex working directory completions
T["Codex cd directory completions"] = function()
  local codex = require("aibo.integration.codex")

  -- Mock getcompletion for directories
  local original_getcompletion = vim.fn.getcompletion
  vim.fn.getcompletion = function(arg, type)
    if type == "dir" then
      return { "/home/user/projects/", "/home/user/documents/", "/tmp/" }
    end
    return {}
  end

  -- Test --cd completion
  local completions = codex.get_command_completions("", "codex --cd ", 11)
  eq(vim.tbl_contains(completions, "/home/user/projects/"), true)
  eq(vim.tbl_contains(completions, "/home/user/documents/"), true)
  eq(vim.tbl_contains(completions, "/tmp/"), true)

  -- Test with short form -C
  completions = codex.get_command_completions("", "codex -C ", 9)
  eq(vim.tbl_contains(completions, "/home/user/projects/"), true)

  vim.fn.getcompletion = original_getcompletion
end

-- Test Codex image file completions
T["Codex image file completions"] = function()
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
  eq(vim.tbl_contains(completions, "image1.png"), true)
  eq(vim.tbl_contains(completions, "image2.jpg"), true)
  eq(vim.tbl_contains(completions, "document.pdf"), true)

  -- Test with short form -i
  completions = codex.get_command_completions("", "codex -i ", 9)
  eq(vim.tbl_contains(completions, "image1.png"), true)

  vim.fn.getcompletion = original_getcompletion
end

-- Test Codex flags without values
T["Codex flags without values"] = function()
  local codex = require("aibo.integration.codex")

  -- Test --ask-for-approval flag which doesn't take a value
  local completions = codex.get_command_completions("--as", "codex --as", 10)
  eq(vim.tbl_contains(completions, "--ask-for-approval"), true)

  -- Test --full-auto flag which doesn't take a value
  completions = codex.get_command_completions("--fu", "codex --fu", 10)
  eq(vim.tbl_contains(completions, "--full-auto"), true)

  -- After --full-auto, should still complete other arguments
  completions = codex.get_command_completions("", "codex --full-auto ", 18)
  eq(vim.tbl_contains(completions, "--model"), true)
  eq(vim.tbl_contains(completions, "--image"), true)
end

-- Test Codex mixed arguments
T["Codex mixed arguments"] = function()
  local codex = require("aibo.integration.codex")

  -- Test completion after model is specified
  local completions = codex.get_command_completions("", "codex --model gpt-4 ", 20)
  eq(vim.tbl_contains(completions, "--ask-for-approval"), true)
  eq(vim.tbl_contains(completions, "--full-auto"), true)
  eq(vim.tbl_contains(completions, "--image"), true)

  -- Test completion after multiple arguments
  completions = codex.get_command_completions("", "codex --model gpt-4 --full-auto ", 33)
  eq(vim.tbl_contains(completions, "--image"), true)
  eq(vim.tbl_contains(completions, "--cd"), true)
end

-- Test check_health function
T["Codex check_health"] = function()
  local codex = require("aibo.integration.codex")

  -- Mock reporter
  local reports = {}
  local reporter = {
    start = function(msg)
      table.insert(reports, { type = "start", msg = msg })
    end,
    ok = function(msg)
      table.insert(reports, { type = "ok", msg = msg })
    end,
    warn = function(msg)
      table.insert(reports, { type = "warn", msg = msg })
    end,
    info = function(msg)
      table.insert(reports, { type = "info", msg = msg })
    end,
  }

  -- Mock executable
  local original_executable = vim.fn.executable
  vim.fn.executable = function(cmd)
    if cmd == "codex" or cmd == "node" then
      return 1
    end
    return 0
  end

  -- Mock env variable
  local original_env = vim.env.OPENAI_API_KEY
  vim.env.OPENAI_API_KEY = "test-key"

  -- Run health check
  codex.check_health(reporter)

  -- Check that appropriate messages were reported
  eq(reports[1].type, "start")
  eq(reports[1].msg:find("Codex") ~= nil, true)

  -- Should report that codex is found
  local has_ok_report = false
  for _, report in ipairs(reports) do
    if report.type == "ok" and report.msg:find("codex CLI found") then
      has_ok_report = true
      break
    end
  end
  eq(has_ok_report, true)

  -- Restore
  vim.env.OPENAI_API_KEY = original_env
  vim.fn.executable = original_executable
end

return T
