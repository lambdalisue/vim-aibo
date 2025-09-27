-- Tests for console_window module (lua/aibo/internal/console_window.lua)

local T = require("mini.test")

-- Test set
-- Load modules first to ensure autocmd groups exist
local _console = require("aibo.internal.console_window")

local test_set = T.new_set({
  hooks = {
    post_case = function()
      vim.cmd("silent! %bwipeout!")
      -- Clean up any created buffers/windows
      for _, buf in ipairs(vim.api.nvim_list_bufs()) do
        local name = vim.api.nvim_buf_get_name(buf)
        if name:match("^aiboconsole://") then
          pcall(vim.api.nvim_buf_delete, buf, { force = true })
        end
      end
    end,
  },
})

-- Parse bufname tests
test_set["parse_bufname parses valid console buffer names"] = function()
  local console = require("aibo.internal.console_window")

  -- Test with command only
  local bufname = "aiboconsole://claude//12345"
  local info = console.get_info_by_bufnr(vim.fn.bufadd(bufname))
  T.expect.equality(info ~= nil, true, "Should parse buffer name")
  if info and info.jobinfo then
    T.expect.equality(info.jobinfo.cmd, "claude", "Should extract command")
    T.expect.equality(#info.jobinfo.args, 0, "Should have no args")
    T.expect.equality(info.jobinfo.job_id, 12345, "Should extract job_id")
  end
end

test_set["parse_bufname handles arguments"] = function()
  local console = require("aibo.internal.console_window")

  -- Test with arguments
  local bufname = "aiboconsole://claude/--model+claude-3-opus/12345"
  local info = console.get_info_by_bufnr(vim.fn.bufadd(bufname))
  T.expect.equality(info ~= nil, true, "Should parse buffer with args")
  if info and info.jobinfo then
    T.expect.equality(info.jobinfo.cmd, "claude", "Should extract command")
    T.expect.equality(info.jobinfo.args[1], "--model", "Should extract first arg")
    T.expect.equality(info.jobinfo.args[2], "claude-3-opus", "Should extract second arg")
  end
end

-- get_info_by_bufnr tests
test_set["get_info_by_bufnr returns nil for invalid buffer"] = function()
  local console = require("aibo.internal.console_window")

  local info = console.get_info_by_bufnr(99999)
  T.expect.equality(info, nil, "Should return nil for invalid buffer")
end

test_set["get_info_by_bufnr returns nil for non-console buffer"] = function()
  local console = require("aibo.internal.console_window")

  local bufnr = vim.api.nvim_create_buf(false, true)
  local info = console.get_info_by_bufnr(bufnr)
  T.expect.equality(info, nil, "Should return nil for non-console buffer")
end

test_set["get_info_by_bufnr returns info for valid console buffer"] = function()
  local console = require("aibo.internal.console_window")

  local bufname = "aiboconsole://test//1234"
  local bufnr = vim.fn.bufadd(bufname)
  local info = console.get_info_by_bufnr(bufnr)

  T.expect.equality(info ~= nil, true, "Should return info for console buffer")
  T.expect.equality(info.bufnr, bufnr, "Should have correct bufnr")
  T.expect.equality(info.bufname, bufname, "Should have correct bufname")
  T.expect.equality(info.winid, -1, "Should have -1 winid when not displayed")
end

-- get_info_by_winid tests
test_set["get_info_by_winid returns nil for invalid window"] = function()
  local console = require("aibo.internal.console_window")

  local info = console.get_info_by_winid(99999)
  T.expect.equality(info, nil, "Should return nil for invalid window")
end

-- find_info_in_tabpage tests
test_set["find_info_in_tabpage returns nil when no match"] = function()
  local console = require("aibo.internal.console_window")

  local bufname = "aiboconsole://claude//1234"
  vim.fn.bufadd(bufname)

  local info = console.find_info_in_tabpage({ cmd = "codex", args = {} })
  T.expect.equality(info, nil, "Should return nil when no matching console")
end

test_set["find_info_in_tabpage finds matching console in tabpage"] = function()
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
  T.expect.equality(info ~= nil, true, "Should find console by command")
  if info then
    T.expect.equality(info.bufnr, bufnr1, "Should return correct buffer")
    T.expect.equality(info.winid, winid1, "Should return correct window")
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
  T.expect.equality(info ~= nil, true, "Should find console by command and args")
  if info then
    T.expect.equality(info.bufnr, bufnr2, "Should return correct buffer with args")
  end

  -- Test no match case
  info = console.find_info_in_tabpage({ cmd = "codex" })
  T.expect.equality(info, nil, "Should return nil when no matching console")

  -- Clean up
  vim.api.nvim_win_close(winid2, true)
end

-- send tests
test_set["send returns nil for invalid buffer"] = function()
  local console = require("aibo.internal.console_window")

  local result = console.send(99999, "test")
  T.expect.equality(result, nil, "Should return nil for invalid buffer")
end

test_set["send returns nil for non-terminal buffer"] = function()
  local console = require("aibo.internal.console_window")

  local bufnr = vim.api.nvim_create_buf(false, true)
  local result = console.send(bufnr, "test")
  T.expect.equality(result, nil, "Should return nil for non-terminal buffer")
end

-- follow tests
test_set["follow moves cursor to last line for console buffer"] = function()
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
  T.expect.equality(cursor[1], 5, "Should move cursor to last line")

  -- Clean up
  vim.api.nvim_win_close(winid, true)
end

test_set["follow handles invalid buffer gracefully"] = function()
  local console = require("aibo.internal.console_window")

  -- Try to follow an invalid buffer (should not error)
  local result = pcall(function()
    console.follow(99999)
  end)
  T.expect.equality(result, true, "Should handle invalid buffer without crashing")
end

return test_set
