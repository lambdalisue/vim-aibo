local eq = MiniTest.expect.equality
local helpers = require("tests.helpers")

local T = helpers.new_set()

-- Test Claude command availability
T["Claude is_available"] = function()
  local claude = require("aibo.integration.claude")

  -- Mock executable
  local original_executable = vim.fn.executable
  vim.fn.executable = function(cmd)
    if cmd == "claude" then
      return 1
    end
    return 0
  end

  eq(claude.is_available(), true)

  -- Test when not available
  vim.fn.executable = function()
    return 0
  end
  eq(claude.is_available(), false)

  -- Restore
  vim.fn.executable = original_executable
end

-- Test Claude command completions
T["Claude argument completions"] = function()
  local claude = require("aibo.integration.claude")

  -- Test completing arguments at the start
  local completions = claude.get_command_completions("", "claude ", 7)
  eq(vim.tbl_contains(completions, "--continue"), true)
  eq(vim.tbl_contains(completions, "--model"), true)
  eq(vim.tbl_contains(completions, "--permission-mode"), true)

  -- Test completing partial argument
  completions = claude.get_command_completions("--con", "claude --con", 12)
  eq(vim.tbl_contains(completions, "--continue"), true)
  eq(vim.tbl_contains(completions, "--model"), false)

  -- Test completing short form
  completions = claude.get_command_completions("-c", "claude -c", 9)
  eq(vim.tbl_contains(completions, "-c"), true)
  eq(vim.tbl_contains(completions, "--continue"), false)
end

-- Test Claude model completions
T["Claude model value completions"] = function()
  local claude = require("aibo.integration.claude")

  -- Test completing model values
  local completions = claude.get_command_completions("", "claude --model ", 15)
  eq(vim.tbl_contains(completions, "sonnet"), true)
  eq(vim.tbl_contains(completions, "opus"), true)
  eq(vim.tbl_contains(completions, "haiku"), true)
  eq(vim.tbl_contains(completions, "claude-3-5-sonnet-latest"), true)

  -- Test partial model completion
  completions = claude.get_command_completions("son", "claude --model son", 18)
  eq(vim.tbl_contains(completions, "sonnet"), true)
  eq(vim.tbl_contains(completions, "opus"), false)

  -- Test with short form
  completions = claude.get_command_completions("", "claude -m ", 10)
  eq(#completions == 0, true) -- Short form not recognized for --model
end

-- Test Claude check_health function
T["Claude check_health"] = function()
  local claude = require("aibo.integration.claude")

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
    if cmd == "claude" then
      return 1
    end
    return 0
  end

  -- Run health check
  claude.check_health(reporter)

  -- Check that appropriate messages were reported
  eq(reports[1].type, "start")
  eq(reports[1].msg:find("Claude") ~= nil, true)

  -- Should report that claude is found
  local has_ok_report = false
  for _, report in ipairs(reports) do
    if report.type == "ok" and report.msg:find("claude") then
      has_ok_report = true
      break
    end
  end
  eq(has_ok_report, true)

  -- Restore
  vim.fn.executable = original_executable
end

-- Test Claude permission mode completions
T["Claude permission-mode value completions"] = function()
  local claude = require("aibo.integration.claude")

  -- Test completing permission modes
  local completions = claude.get_command_completions("", "claude --permission-mode ", 26)
  eq(vim.tbl_contains(completions, "default"), true)
  eq(vim.tbl_contains(completions, "acceptEdits"), true)
  eq(vim.tbl_contains(completions, "bypassPermissions"), true)
  eq(vim.tbl_contains(completions, "plan"), true)

  -- Test partial completion
  completions = claude.get_command_completions("acc", "claude --permission-mode acc", 29)
  eq(vim.tbl_contains(completions, "acceptEdits"), true)
  eq(vim.tbl_contains(completions, "default"), false)
end

-- Test Claude file/directory completions
T["Claude file and directory completions"] = function()
  local claude = require("aibo.integration.claude")

  -- Mock getcompletion for directories
  local original_getcompletion = vim.fn.getcompletion
  vim.fn.getcompletion = function(arg, type)
    if type == "dir" then
      return { "/home/user/", "/tmp/", "/var/" }
    elseif type == "file" then
      return { "config.json", "settings.json" }
    end
    return {}
  end

  -- Test --add-dir completion
  local completions = claude.get_command_completions("", "claude --add-dir ", 17)
  eq(vim.tbl_contains(completions, "/home/user/"), true)
  eq(vim.tbl_contains(completions, "/tmp/"), true)

  -- Test --settings completion
  completions = claude.get_command_completions("", "claude --settings ", 18)
  eq(vim.tbl_contains(completions, "config.json"), true)
  eq(vim.tbl_contains(completions, "settings.json"), true)

  vim.fn.getcompletion = original_getcompletion
end

return T
