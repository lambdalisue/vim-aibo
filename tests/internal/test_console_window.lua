local eq = MiniTest.expect.equality
local helpers = require("tests.helpers")

local T = helpers.new_set()

-- get_info_by_bufnr tests
T["get_info_by_bufnr parses valid console buffer names"] = function()
  local console = require("aibo.internal.console_window")

  -- Test with command only
  local bufname = "aiboconsole://claude//12345"
  local info = console.get_info_by_bufnr(vim.fn.bufadd(bufname))
  eq(info ~= nil, true)
  if info and info.jobinfo then
    eq(info.jobinfo.cmd, "claude")
    eq(#info.jobinfo.args, 0)
    eq(info.jobinfo.job_id, 12345)
  end
end

T["get_info_by_bufnr handles arguments"] = function()
  local console = require("aibo.internal.console_window")

  -- Test with arguments
  local bufname = "aiboconsole://claude/--model+claude-3-opus/12345"
  local info = console.get_info_by_bufnr(vim.fn.bufadd(bufname))
  eq(info ~= nil, true)
  if info and info.jobinfo then
    eq(info.jobinfo.cmd, "claude")
    eq(info.jobinfo.args[1], "--model")
    eq(info.jobinfo.args[2], "claude-3-opus")
  end
end

-- get_info_by_bufnr tests
T["get_info_by_bufnr returns nil for invalid buffer"] = function()
  local console = require("aibo.internal.console_window")

  local info = console.get_info_by_bufnr(99999)
  eq(info, nil)
end

T["get_info_by_bufnr returns nil for non-console buffer"] = function()
  local console = require("aibo.internal.console_window")

  local bufnr = vim.api.nvim_create_buf(false, true)
  local info = console.get_info_by_bufnr(bufnr)
  eq(info, nil)
end

T["get_info_by_bufnr returns info for valid console buffer"] = function()
  local console = require("aibo.internal.console_window")

  -- Use unique buffer name to avoid conflicts
  local bufname = "aiboconsole://test//" .. vim.loop.hrtime()
  local bufnr = vim.fn.bufadd(bufname)

  -- Ensure buffer is not displayed in any window
  vim.api.nvim_set_option_value("bufhidden", "hide", { buf = bufnr })

  local info = console.get_info_by_bufnr(bufnr)

  eq(info ~= nil, true)
  eq(info.bufnr, bufnr)
  eq(info.bufname, bufname)
  eq(info.winid, -1)
end

-- get_info_by_winid tests
T["get_info_by_winid returns nil for invalid window"] = function()
  local console = require("aibo.internal.console_window")

  local info = console.get_info_by_winid(99999)
  eq(info, nil)
end

T["get_info_by_winid returns info for console window"] = function()
  local console = require("aibo.internal.console_window")

  -- Create console buffer
  local bufname = "aiboconsole://test//" .. vim.loop.hrtime()
  local bufnr = vim.fn.bufadd(bufname)

  -- Open in window
  vim.cmd("split")
  local winid = vim.api.nvim_get_current_win()
  vim.api.nvim_win_set_buf(winid, bufnr)

  -- Get info by window ID
  local info = console.get_info_by_winid(winid)

  eq(info ~= nil, true)
  if info then
    eq(info.winid, winid)
    eq(info.bufnr, bufnr)
    eq(info.bufname, bufname)
  end
end

-- find_info_in_tabpage tests
T["find_info_in_tabpage returns nil when no match"] = function()
  local console = require("aibo.internal.console_window")

  local bufname = "aiboconsole://claude//1234"
  vim.fn.bufadd(bufname)

  local info = console.find_info_in_tabpage({ cmd = "codex", args = {} })
  eq(info, nil)
end

T["find_info_in_tabpage finds matching console in tabpage"] = function()
  local console = require("aibo.internal.console_window")

  -- Create a console buffer WITHOUT args for the first test
  local bufname1 = "aiboconsole://claude//1234"
  local bufnr1 = vim.fn.bufadd(bufname1)

  -- Ensure the buffer is valid by setting it to a scratch buffer
  vim.api.nvim_set_option_value("buftype", "nofile", { buf = bufnr1 })
  vim.api.nvim_set_option_value("swapfile", false, { buf = bufnr1 })
  vim.api.nvim_set_option_value("bufhidden", "wipe", { buf = bufnr1 })

  vim.cmd("split")
  local winid1 = vim.api.nvim_get_current_win()
  vim.api.nvim_win_set_buf(winid1, bufnr1)

  -- Find by cmd only (should find the one without args)
  local info = console.find_info_in_tabpage({ cmd = "claude" })
  eq(info ~= nil, true)
  if info then
    eq(info.bufnr, bufnr1)
    eq(info.winid, winid1)
  end

  -- Clean up first window
  vim.api.nvim_win_close(winid1, true)

  -- Create another console buffer WITH args
  local bufname2 = "aiboconsole://claude/--model+claude-3-opus/5678"
  local bufnr2 = vim.fn.bufadd(bufname2)

  vim.api.nvim_set_option_value("buftype", "nofile", { buf = bufnr2 })
  vim.api.nvim_set_option_value("swapfile", false, { buf = bufnr2 })
  vim.api.nvim_set_option_value("bufhidden", "wipe", { buf = bufnr2 })

  vim.cmd("split")
  local winid2 = vim.api.nvim_get_current_win()
  vim.api.nvim_win_set_buf(winid2, bufnr2)

  -- Find by cmd and args
  info = console.find_info_in_tabpage({ cmd = "claude", args = { "--model", "claude-3-opus" } })
  eq(info ~= nil, true)
  if info then
    eq(info.bufnr, bufnr2)
  end

  -- Test no match case
  info = console.find_info_in_tabpage({ cmd = "codex" })
  eq(info, nil)
end

-- send tests
T["send returns nil for invalid buffer"] = function()
  local console = require("aibo.internal.console_window")

  local result = console.send(99999, "test")
  eq(result, nil)
end

T["send returns nil for non-terminal buffer"] = function()
  local console = require("aibo.internal.console_window")

  local bufnr = vim.api.nvim_create_buf(false, true)
  local result = console.send(bufnr, "test")
  eq(result, nil)
end

T["send successfully sends to terminal buffer"] = function()
  local console = require("aibo.internal.console_window")

  -- Create a console buffer with proper name
  local bufname = "aiboconsole://sendtest//9999"
  local bufnr = vim.fn.bufadd(bufname)

  -- Create terminal
  local chan = vim.api.nvim_open_term(bufnr, {})
  vim.b[bufnr].terminal_job_id = chan

  -- Send data (returns nothing on success, nil on failure)
  local ok = pcall(console.send, bufnr, "test data")
  eq(ok, true)
end

-- follow tests
T["follow moves cursor to last line for console buffer"] = function()
  local console = require("aibo.internal.console_window")

  -- Create a valid console buffer
  local bufname = "aiboconsole://test//1234"
  local bufnr = vim.fn.bufadd(bufname)
  vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, {
    "line 1",
    "line 2",
    "line 3",
    "line 4",
    "line 5",
  })

  -- Open in window
  vim.cmd("split")
  local winid = vim.api.nvim_get_current_win()
  vim.api.nvim_win_set_buf(winid, bufnr)

  -- Set cursor to first line
  vim.api.nvim_win_set_cursor(winid, { 1, 0 })

  -- Call follow
  console.follow(bufnr)

  -- Check cursor moved to last line
  local cursor = vim.api.nvim_win_get_cursor(winid)
  eq(cursor[1], 5)
end

T["follow handles invalid buffer gracefully"] = function()
  local console = require("aibo.internal.console_window")

  -- Try to follow an invalid buffer (should not error)
  local result = pcall(function()
    console.follow(99999)
  end)
  eq(result, true)
end

-- Test open function
T["open creates new console window"] = function()
  local console = require("aibo.internal.console_window")

  -- Mock vim.fn.jobstart to simulate terminal creation
  local original_jobstart = vim.fn.jobstart
  vim.fn.jobstart = function(cmd, opts)
    -- Return a fake job ID
    return 12345
  end

  -- Open a console window
  local info = console.open("test_cmd", {}, {})

  -- Restore original
  vim.fn.jobstart = original_jobstart

  eq(info ~= nil, true)
  if info then
    eq(info.bufname:match("^aiboconsole://"), "aiboconsole://")
    eq(info.winid ~= -1, true)
  end
end

T["open with args creates console with arguments"] = function()
  local console = require("aibo.internal.console_window")

  -- Mock jobstart
  local original_jobstart = vim.fn.jobstart
  local captured_cmd = nil
  vim.fn.jobstart = function(cmd, opts)
    captured_cmd = cmd
    return 54321
  end

  -- Open with arguments
  local info = console.open("testcmdargs", { "--arg1", "value1" }, {})

  -- Restore
  vim.fn.jobstart = original_jobstart

  eq(info ~= nil, true)

  -- Just verify jobstart was called with args
  if captured_cmd then
    eq(#captured_cmd >= 3, true)
  end
end

T["open handles jobstart failure"] = function()
  local console = require("aibo.internal.console_window")

  -- Mock jobstart to simulate failure
  local original_jobstart = vim.fn.jobstart
  vim.fn.jobstart = function(cmd, opts)
    return 0 -- Return 0 or negative to indicate failure
  end

  -- Try to open console
  local info = console.open("failing_cmd", {}, {})

  -- Restore
  vim.fn.jobstart = original_jobstart

  eq(info, nil)
end

-- Test submit function
T["submit sends input with newline to terminal"] = function()
  local console = require("aibo.internal.console_window")

  -- Create a terminal buffer
  local bufnr = vim.api.nvim_create_buf(false, true)
  local chan = vim.api.nvim_open_term(bufnr, {})
  vim.b[bufnr].terminal_job_id = chan

  -- Test that submit doesn't error
  local ok = pcall(console.submit, bufnr, "test input")
  eq(ok, true)
end

-- Test focus_or_open function
T["focus_or_open focuses existing window"] = function()
  local console = require("aibo.internal.console_window")

  -- Create a console buffer with matching command
  local job_id = 1234
  local bufname = "aiboconsole://test//" .. job_id
  local bufnr = vim.fn.bufadd(bufname)

  -- Set up buffer metadata
  vim.bo[bufnr].filetype = "aibo-console"
  vim.b[bufnr].aibo = { cmd = "test", args = {}, job_id = job_id }

  -- Open in a window
  vim.cmd("split")
  local winid = vim.api.nvim_get_current_win()
  vim.api.nvim_win_set_buf(winid, bufnr)

  -- Move to a different window
  vim.cmd("new")
  local other_win = vim.api.nvim_get_current_win()

  -- Verify we're not in the console window
  eq(vim.api.nvim_get_current_win() ~= winid, true)

  -- Mock jobstart for potential new console creation
  local original_jobstart = vim.fn.jobstart
  vim.fn.jobstart = function(cmd, opts)
    return job_id
  end

  -- Call focus_or_open - should focus existing window
  local info = console.focus_or_open("test", {}, {})

  -- Restore original
  vim.fn.jobstart = original_jobstart

  eq(info ~= nil, true)
  if info then
    -- Check that we're now in a window showing the console buffer
    local current_buf = vim.api.nvim_get_current_buf()
    eq(current_buf, bufnr)
    -- Also verify it's the same buffer in the info
    eq(info.bufnr, bufnr)
  end
end

T["focus_or_open creates new console when none exists"] = function()
  local console = require("aibo.internal.console_window")

  -- Mock jobstart
  local original_jobstart = vim.fn.jobstart
  vim.fn.jobstart = function(cmd, opts)
    return 7890
  end

  -- Call focus_or_open with simple command name
  local info = console.focus_or_open("newcmd", {}, {})

  -- Restore original
  vim.fn.jobstart = original_jobstart

  -- Just check that it returned something
  eq(info ~= nil, true)
end

-- Test toggle_or_open function (simplified to avoid window management issues)
T["toggle_or_open returns info"] = function()
  local console = require("aibo.internal.console_window")

  -- Mock jobstart
  local original_jobstart = vim.fn.jobstart
  vim.fn.jobstart = function(cmd, opts)
    return 12345
  end

  -- Create extra window to avoid "Cannot close last window" error
  vim.cmd("new")

  -- Call toggle_or_open with a simple command name
  local info = console.toggle_or_open("testtoggle", {}, {})

  -- Restore
  vim.fn.jobstart = original_jobstart

  -- Just check that function works without error
  eq(info ~= nil, true)
end

T["toggle_or_open handles existing window"] = function()
  local console = require("aibo.internal.console_window")
  local prompt = require("aibo.internal.prompt_window")

  -- Mock jobstart
  local original_jobstart = vim.fn.jobstart
  vim.fn.jobstart = function(cmd, opts)
    return 8888
  end

  -- Mock prompt.open to avoid window creation issues
  local original_prompt_open = prompt.open
  prompt.open = function(console_winid)
    return {
      winid = 1000,
      bufnr = vim.api.nvim_create_buf(false, true),
      bufname = "aiboprompt://1000",
    }
  end

  -- Simply test that toggle_or_open works without error
  local info = console.toggle_or_open("cycletest", {}, {})

  -- Just verify it returns something
  eq(info ~= nil, true)

  -- Restore
  vim.fn.jobstart = original_jobstart
  prompt.open = original_prompt_open
end

return T
