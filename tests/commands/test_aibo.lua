local eq = MiniTest.expect.equality
local helpers = require("tests.helpers")

local T = helpers.new_set({
  hooks = {
    pre_case = function()
      -- Setup the Aibo command
      require("aibo.command.aibo").setup()
    end,
  },
})

-- Test command completion for tool names
T["Tool name completion"] = function()
  -- Get the completion function
  local complete_fn = require("aibo.command.aibo")._internal.complete

  -- Test completing tool names
  local completions = complete_fn("", "Aibo ", 5)
  eq(vim.tbl_contains(completions, "claude"), true)
  eq(vim.tbl_contains(completions, "codex"), true)
  eq(vim.tbl_contains(completions, "ollama"), true)

  -- Test partial completion
  completions = complete_fn("cl", "Aibo cl", 7)
  eq(vim.tbl_contains(completions, "claude"), true)
  eq(vim.tbl_contains(completions, "codex"), false)
  eq(vim.tbl_contains(completions, "ollama"), false)

  -- Test with "co"
  completions = complete_fn("co", "Aibo co", 7)
  eq(vim.tbl_contains(completions, "claude"), false)
  eq(vim.tbl_contains(completions, "codex"), true)
  eq(vim.tbl_contains(completions, "ollama"), false)
end

-- Test command completion delegation to integration modules
T["Integration module delegation"] = function()
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
  eq(vim.tbl_contains(completions, "--test-claude-arg"), true)

  -- Mock codex integration module
  package.loaded["aibo.integration.codex"] = {
    get_command_completions = function(arglead, cmdline, cursorpos)
      return { "--test-codex-arg" }
    end,
  }

  -- Test Codex delegation
  completions = complete_fn("", "Aibo codex ", 11)
  eq(vim.tbl_contains(completions, "--test-codex-arg"), true)

  -- Mock ollama integration module
  package.loaded["aibo.integration.ollama"] = {
    get_command_completions = function(arglead, cmdline, cursorpos)
      return { "test-model" }
    end,
  }

  -- Test Ollama delegation
  completions = complete_fn("", "Aibo ollama ", 12)
  eq(vim.tbl_contains(completions, "test-model"), true)

  -- Restore original modules
  package.loaded["aibo.integration.claude"] = orig_claude
  package.loaded["aibo.integration.codex"] = orig_codex
  package.loaded["aibo.integration.ollama"] = orig_ollama
end

-- Test known tool detection
T["Known tool detection"] = function()
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
  eq(vim.tbl_contains(completions, "--claude-specific"), true)

  -- Unknown tool should not delegate
  completions = complete_fn("", "Aibo unknown ", 13)
  eq(#completions, 0)

  -- Restore original module
  package.loaded["aibo.integration.claude"] = orig_claude
end

-- Test error handling in completion
T["Completion error handling"] = function()
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
  eq(ok, true)
  eq(#completions, 0)

  -- Restore original module
  package.loaded["aibo.integration.claude"] = orig_claude
end

-- Test M.call function with valid arguments
T["Call function with valid tool"] = function()
  local aibo_cmd = require("aibo.command.aibo")

  -- Mock console_window.open (default behavior without toggle/focus)
  local console_window = require("aibo.internal.console_window")
  local original_open = console_window.open
  local called_with = nil
  console_window.open = function(cmd, args, opts)
    called_with = { cmd = cmd, args = args, opts = opts }
    return { winid = 1000, bufnr = 1 }
  end

  -- Call with valid tool
  aibo_cmd.call({ "claude", "--model", "sonnet" }, {})

  -- Verify it was called
  eq(called_with ~= nil, true)
  if called_with then
    eq(called_with.cmd, "claude")
    eq(#called_with.args, 2)
  end

  -- Restore
  console_window.open = original_open
end

-- Test M.call with options
T["Call function with options"] = function()
  local aibo_cmd = require("aibo.command.aibo")

  -- Mock console functions
  local console_window = require("aibo.internal.console_window")
  local original_toggle = console_window.toggle_or_open
  local original_focus = console_window.focus_or_open
  local toggle_called = false
  local focus_called = false

  console_window.toggle_or_open = function(cmd, args, opts)
    toggle_called = true
    return { winid = 1000, bufnr = 1 }
  end

  console_window.focus_or_open = function(cmd, args, opts)
    focus_called = true
    return { winid = 1000, bufnr = 1 }
  end

  -- Call with toggle option
  aibo_cmd.call({ "claude" }, { toggle = true })
  eq(toggle_called, true)
  eq(focus_called, false)

  -- Reset flags
  toggle_called = false
  focus_called = false

  -- Call with focus option
  aibo_cmd.call({ "codex" }, { focus = true })
  eq(focus_called, true)
  eq(toggle_called, false)

  -- Restore
  console_window.toggle_or_open = original_toggle
  console_window.focus_or_open = original_focus
end

-- Test M.call with no arguments
T["Call function with no arguments"] = function()
  local aibo_cmd = require("aibo.command.aibo")

  -- Mock vim.notify to capture the message
  local original_notify = vim.notify
  local notify_called = false
  vim.notify = function(msg, level, opts)
    if msg:find("Usage:") then
      notify_called = true
    end
  end

  -- Call with no args
  aibo_cmd.call({}, {})

  eq(notify_called, true)

  -- Restore
  vim.notify = original_notify
end

-- Test M.setup creates command
T["Setup creates user command"] = function()
  local aibo_cmd = require("aibo.command.aibo")

  -- Clear any existing command
  pcall(vim.api.nvim_del_user_command, "Aibo")

  -- Setup should create the command
  aibo_cmd.setup()

  -- Check command exists using helper
  local cmd = helpers.expect.command_exists("Aibo")
  if cmd then
    eq(cmd.nargs, "+")
  end
end

-- Test opener option completion
T["Opener option completion"] = function()
  local complete_fn = require("aibo.command.aibo")._internal.complete

  -- Test completing -opener= prefix
  local completions = complete_fn("-opener=", "Aibo -opener=", 13)
  eq(vim.tbl_contains(completions, "-opener=split"), true)
  eq(vim.tbl_contains(completions, "-opener=vsplit"), true)
  eq(vim.tbl_contains(completions, "-opener=tabedit"), true)
  eq(vim.tbl_contains(completions, "-opener=edit"), true)

  -- Test partial completion
  completions = complete_fn("-opener=v", "Aibo -opener=v", 14)
  eq(vim.tbl_contains(completions, "-opener=vsplit"), true)
  eq(vim.tbl_contains(completions, "-opener=split"), false)

  -- Test with spaces in opener
  completions = complete_fn("-opener=top", "Aibo -opener=top", 16)
  eq(vim.tbl_contains(completions, "-opener=topleft\\ split"), true)
  eq(vim.tbl_contains(completions, "-opener=topleft\\ vsplit"), true)
end

-- Test other options completion (-stay, -toggle, -focus)
T["Other options completion"] = function()
  local complete_fn = require("aibo.command.aibo")._internal.complete

  -- Test completing options at the start
  local completions = complete_fn("-", "Aibo -", 6)
  eq(vim.tbl_contains(completions, "-stay"), true)
  eq(vim.tbl_contains(completions, "-toggle"), true)
  eq(vim.tbl_contains(completions, "-focus"), true)
  eq(vim.tbl_contains(completions, "-opener="), true)

  -- Test partial option completion
  completions = complete_fn("-s", "Aibo -s", 7)
  eq(vim.tbl_contains(completions, "-stay"), true)
  eq(vim.tbl_contains(completions, "-toggle"), false)

  completions = complete_fn("-t", "Aibo -t", 7)
  eq(vim.tbl_contains(completions, "-toggle"), true)
  eq(vim.tbl_contains(completions, "-stay"), false)

  completions = complete_fn("-f", "Aibo -f", 7)
  eq(vim.tbl_contains(completions, "-focus"), true)
  eq(vim.tbl_contains(completions, "-stay"), false)
end

-- Test M.call with stay option
T["Call function with stay option"] = function()
  local aibo_cmd = require("aibo.command.aibo")

  -- Mock console and window functions
  local console_window = require("aibo.internal.console_window")
  local original_open = console_window.open
  local original_winid = vim.api.nvim_get_current_win()
  local set_win_called = false

  -- Mock nvim_set_current_win to check it's called
  local original_set_win = vim.api.nvim_set_current_win
  vim.api.nvim_set_current_win = function(winid)
    if winid == original_winid then
      set_win_called = true
    end
    return original_set_win(winid)
  end

  console_window.open = function(cmd, args, opts)
    return { winid = 9999, bufnr = 1 }
  end

  -- Call with stay option
  aibo_cmd.call({ "claude" }, { stay = true })

  eq(set_win_called, true)

  -- Restore
  console_window.open = original_open
  vim.api.nvim_set_current_win = original_set_win
end

-- Test M.call with mutually exclusive options
T["Call function with mutually exclusive options"] = function()
  local aibo_cmd = require("aibo.command.aibo")

  -- Mock vim.notify to capture warning
  local original_notify = vim.notify
  local warning_shown = false
  vim.notify = function(msg, level, opts)
    if msg:find("toggle and %-focus cannot be used together") then
      warning_shown = true
    end
  end

  -- Call with both toggle and focus (should warn and return)
  aibo_cmd.call({ "claude" }, { toggle = true, focus = true })

  eq(warning_shown, true)

  -- Restore
  vim.notify = original_notify
end

-- Test M.call with opener option
T["Call function with opener option"] = function()
  local aibo_cmd = require("aibo.command.aibo")

  -- Mock console_window.open
  local console_window = require("aibo.internal.console_window")
  local original_open = console_window.open
  local called_with_opts = nil

  console_window.open = function(cmd, args, opts)
    called_with_opts = opts
    return { winid = 1000, bufnr = 1 }
  end

  -- Call with opener option
  aibo_cmd.call({ "claude" }, { opener = "vsplit" })

  eq(called_with_opts ~= nil, true)
  if called_with_opts then
    eq(called_with_opts.opener, "vsplit")
  end

  -- Restore
  console_window.open = original_open
end

-- Test M.call with invalid argument types
T["Call function with invalid arguments"] = function()
  local aibo_cmd = require("aibo.command.aibo")

  -- Mock vim.notify to capture message
  local original_notify = vim.notify
  local usage_shown = false
  vim.notify = function(msg, level, opts)
    if msg:find("Usage:") then
      usage_shown = true
    end
  end

  -- Test with nil
  aibo_cmd.call(nil, {})
  eq(usage_shown, true)

  -- Reset flag
  usage_shown = false

  -- Test with string instead of table
  aibo_cmd.call("claude", {})
  eq(usage_shown, true)

  -- Reset flag
  usage_shown = false

  -- Test with number
  aibo_cmd.call(123, {})
  eq(usage_shown, true)

  -- Restore
  vim.notify = original_notify
end

-- Test completion with mixed options and tools
T["Completion with mixed options and tools"] = function()
  local complete_fn = require("aibo.command.aibo")._internal.complete

  -- Test completing after -stay option
  local completions = complete_fn("", "Aibo -stay ", 11)
  -- Should still offer tool names after options
  eq(vim.tbl_contains(completions, "claude"), true)
  eq(vim.tbl_contains(completions, "codex"), true)
  eq(vim.tbl_contains(completions, "ollama"), true)

  -- Test completing after multiple options
  completions = complete_fn("", "Aibo -stay -toggle ", 19)
  eq(vim.tbl_contains(completions, "claude"), true)

  -- Test completing after opener option with value
  completions = complete_fn("", "Aibo -opener=vsplit ", 20)
  eq(vim.tbl_contains(completions, "claude"), true)
  eq(vim.tbl_contains(completions, "codex"), true)
end

-- Test completion returns empty for invalid states
T["Completion handles invalid states"] = function()
  local complete_fn = require("aibo.command.aibo")._internal.complete

  -- Test with unknown tool and more arguments
  local completions = complete_fn("", "Aibo unknown_tool arg1 arg2 ", 29)
  eq(#completions, 0)

  -- Test with partial unknown tool
  completions = complete_fn("xyz", "Aibo xyz", 8)
  eq(#completions, 0)
end

-- Test M.call with all options combined
T["Call function with all valid options"] = function()
  local aibo_cmd = require("aibo.command.aibo")

  -- Mock console functions
  local console_window = require("aibo.internal.console_window")
  local original_focus = console_window.focus_or_open
  local called_with = nil

  console_window.focus_or_open = function(cmd, args, opts)
    called_with = { cmd = cmd, args = args, opts = opts }
    return { winid = 1000, bufnr = 1 }
  end

  -- Mock window functions
  local original_get_win = vim.api.nvim_get_current_win
  local original_set_win = vim.api.nvim_set_current_win
  local original_winid = 100
  vim.api.nvim_get_current_win = function()
    return original_winid
  end
  local set_win_called_with = nil
  vim.api.nvim_set_current_win = function(winid)
    set_win_called_with = winid
  end

  -- Call with opener, stay, and focus options (valid combination)
  aibo_cmd.call({ "claude", "--model", "opus" }, {
    opener = "tabedit",
    stay = true,
    focus = true,
  })

  -- Verify correct function was called with correct options
  eq(called_with ~= nil, true)
  if called_with then
    eq(called_with.cmd, "claude")
    eq(#called_with.args, 2)
    eq(called_with.opts.opener, "tabedit")
  end

  eq(set_win_called_with, original_winid)

  -- Restore
  console_window.focus_or_open = original_focus
  vim.api.nvim_get_current_win = original_get_win
  vim.api.nvim_set_current_win = original_set_win
end

return T
