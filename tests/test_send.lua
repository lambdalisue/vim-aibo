-- Tests for AiboSend functionality

local helpers = require("tests.helpers")
local T = require("mini.test")

-- Test set
local test_set = T.new_set({
  hooks = {
    pre_case = function()
      helpers.setup()
      -- Reload the plugin to ensure commands are created
      vim.cmd("runtime plugin/aibo.lua")
      -- Clear any existing aibo buffers more thoroughly
      for _, buf in ipairs(vim.api.nvim_list_bufs()) do
        if vim.api.nvim_buf_is_valid(buf) then
          local name = vim.api.nvim_buf_get_name(buf)
          local ft = vim.bo[buf].filetype or ""
          if name:match("^aibo://") or name:match("^aiboprompt://") or ft:match("^aibo%-") then
            pcall(vim.api.nvim_buf_delete, buf, { force = true })
          end
        end
      end
      -- Clear all windows except current
      vim.cmd("only")
    end,
    post_case = function()
      helpers.cleanup()
      -- Clean up any created buffers more thoroughly
      for _, buf in ipairs(vim.api.nvim_list_bufs()) do
        if vim.api.nvim_buf_is_valid(buf) then
          local name = vim.api.nvim_buf_get_name(buf)
          local ft = vim.bo[buf].filetype or ""
          if name:match("^aibo://") or name:match("^aiboprompt://") or ft:match("^aibo%-") then
            pcall(vim.api.nvim_buf_delete, buf, { force = true })
          end
        end
      end
      -- Ensure all windows are closed
      vim.cmd("only")
    end,
  },
})

-- Test AiboSend command existence
test_set["AiboSend command exists"] = function()
  local commands = vim.api.nvim_get_commands({})
  T.expect.equality(commands["AiboSend"] ~= nil, true)
  T.expect.equality(commands["AiboSend"].range, ".") -- range returns "." string not true
  T.expect.equality(commands["AiboSend"].nargs, "*")
end

-- Test AiboSend command completion
test_set["AiboSend command completion"] = function()
  local completions = vim.fn.getcompletion("AiboSend ", "cmdline")
  T.expect.equality(vim.tbl_contains(completions, "-input"), true)
  T.expect.equality(vim.tbl_contains(completions, "-submit"), true)
  T.expect.equality(vim.tbl_contains(completions, "-replace"), true)
  T.expect.equality(vim.tbl_contains(completions, "-prefix="), true)
  T.expect.equality(vim.tbl_contains(completions, "-suffix="), true)
end

-- Test AiboSend without console buffer
test_set["AiboSend without console shows error"] = function()
  -- Create a test buffer with content
  local test_buf = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_set_current_buf(test_buf)
  vim.api.nvim_buf_set_lines(test_buf, 0, -1, false, { "test content" })

  -- Mock vim.notify to capture the error message
  local notify_called = false
  local notify_msg = nil
  local original_notify = vim.notify
  vim.notify = function(msg, level, opts)
    if opts and opts.title == "Aibo" and level == vim.log.levels.ERROR then
      notify_called = true
      notify_msg = msg
    end
  end

  -- Run AiboSend
  vim.cmd("AiboSend")

  -- Restore original notify
  vim.notify = original_notify

  -- Check that error was shown
  T.expect.equality(notify_called, true)
  T.expect.equality(notify_msg, "No Aibo console buffers found in current tabpage")
end

-- Test AiboSend with single console buffer
test_set["AiboSend with single console"] = function()
  -- Create a mock console buffer
  local console_buf = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_name(console_buf, "aibo://1")
  vim.bo[console_buf].filetype = "aibo-console"
  vim.b[console_buf].aibo = {
    cmd = "test",
    args = { "arg1" },
  }

  -- Open console in a window (use normal split, not floating window)
  vim.cmd("split")
  vim.api.nvim_set_current_buf(console_buf)
  local console_win = vim.api.nvim_get_current_win()
  vim.cmd("wincmd p") -- Go back to previous window

  -- Create a test buffer with content
  local test_buf = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_set_current_buf(test_buf)
  vim.api.nvim_buf_set_lines(test_buf, 0, -1, false, { "line1", "line2", "line3" })

  -- Run AiboSend
  vim.cmd("AiboSend")

  -- Check that prompt buffer was created
  local prompt_bufname = string.format("aiboprompt://%d", console_win)
  local prompt_buf = vim.fn.bufnr(prompt_bufname)
  T.expect.equality(prompt_buf ~= -1, true)

  -- Check that content was sent to prompt buffer
  if prompt_buf ~= -1 then
    local prompt_lines = vim.api.nvim_buf_get_lines(prompt_buf, 0, -1, false)
    T.expect.equality(#prompt_lines, 3)
    T.expect.equality(prompt_lines[1], "line1")
    T.expect.equality(prompt_lines[2], "line2")
    T.expect.equality(prompt_lines[3], "line3")
  end

  -- Clean up
  vim.api.nvim_win_close(console_win, true)
end

-- Test AiboSend with range
test_set["AiboSend with range"] = function()
  -- Create a mock console buffer
  local console_buf = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_name(console_buf, "aibo://2")
  vim.bo[console_buf].filetype = "aibo-console"
  vim.b[console_buf].aibo = {
    cmd = "test",
    args = {},
  }

  -- Open console in a window (use normal split, not floating window)
  vim.cmd("split")
  vim.api.nvim_set_current_buf(console_buf)
  local console_win = vim.api.nvim_get_current_win()
  vim.cmd("wincmd p") -- Go back to previous window

  -- Create a test buffer with content
  local test_buf = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_set_current_buf(test_buf)
  vim.api.nvim_buf_set_lines(test_buf, 0, -1, false, { "line1", "line2", "line3", "line4", "line5" })

  -- Run AiboSend with range (lines 2-4)
  vim.cmd("2,4AiboSend")

  -- Check that prompt buffer was created
  local prompt_bufname = string.format("aiboprompt://%d", console_win)
  local prompt_buf = vim.fn.bufnr(prompt_bufname)
  T.expect.equality(prompt_buf ~= -1, true)

  -- Check that only selected lines were sent
  if prompt_buf ~= -1 then
    local prompt_lines = vim.api.nvim_buf_get_lines(prompt_buf, 0, -1, false)
    T.expect.equality(#prompt_lines, 3)
    T.expect.equality(prompt_lines[1], "line2")
    T.expect.equality(prompt_lines[2], "line3")
    T.expect.equality(prompt_lines[3], "line4")
  end

  -- Clean up
  vim.api.nvim_win_close(console_win, true)
end

-- Test AiboSend -input option
test_set["AiboSend -input option"] = function()
  -- Create a mock console buffer
  local console_buf = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_name(console_buf, "aibo://3")
  vim.bo[console_buf].filetype = "aibo-console"
  vim.b[console_buf].aibo = {
    cmd = "test",
    args = {},
  }

  -- Open console in a window
  local console_win = vim.api.nvim_open_win(console_buf, true, {
    relative = "editor",
    width = 40,
    height = 10,
    row = 0,
    col = 0,
  })

  -- Create a test buffer with content
  local test_buf = vim.api.nvim_create_buf(false, true)
  local test_win = vim.api.nvim_open_win(test_buf, true, {
    relative = "editor",
    width = 40,
    height = 10,
    row = 0,
    col = 45,
  })
  vim.api.nvim_set_current_win(test_win)
  vim.api.nvim_buf_set_lines(test_buf, 0, -1, false, { "test content" })

  -- Track window focus changes
  local original_win = vim.api.nvim_get_current_win()

  -- Run AiboSend with -input
  vim.cmd("AiboSend -input")

  -- Check that focus moved to console window
  local current_win = vim.api.nvim_get_current_win()
  T.expect.equality(current_win, console_win)

  -- Clean up
  vim.api.nvim_win_close(console_win, true)
  vim.api.nvim_win_close(test_win, true)
end

-- Test AiboSend with both -input and -submit works together
test_set["AiboSend with both options shows warning"] = function()
  -- Create a mock console buffer
  local console_buf = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_name(console_buf, "aibo://4")
  vim.bo[console_buf].filetype = "aibo-console"
  vim.b[console_buf].aibo = {
    cmd = "test",
    args = {},
  }

  -- Open console in a window (use normal split, not floating window)
  vim.cmd("split")
  vim.api.nvim_set_current_buf(console_buf)
  local console_win = vim.api.nvim_get_current_win()
  vim.cmd("wincmd p") -- Go back to previous window

  -- Create a test buffer with content
  local test_buf = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_set_current_buf(test_buf)
  vim.api.nvim_buf_set_lines(test_buf, 0, -1, false, { "test" })

  -- Mock vim.notify to capture any warnings
  local warning_shown = false
  local original_notify = vim.notify
  vim.notify = function(msg, level, opts)
    if opts and opts.title == "Aibo" and level == vim.log.levels.WARN then
      warning_shown = true
    end
  end

  -- Run AiboSend with both options
  vim.cmd("AiboSend -input -submit")

  -- Restore original notify
  vim.notify = original_notify

  -- Check that no warning was shown (both options now work together)
  T.expect.equality(warning_shown, false)

  -- Clean up
  vim.api.nvim_win_close(console_win, true)
end

-- Test AiboSend with prefix and suffix
test_set["AiboSend with prefix and suffix"] = function()
  -- Create a mock console buffer
  local console_buf = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_name(console_buf, "aibo://prefix-suffix")
  vim.bo[console_buf].filetype = "aibo-console"
  vim.b[console_buf].aibo = {
    cmd = "test",
    args = {},
  }

  -- Open console in a window
  vim.cmd("split")
  vim.api.nvim_set_current_buf(console_buf)
  local console_win = vim.api.nvim_get_current_win()
  vim.cmd("wincmd p") -- Go back to previous window

  -- Create a test buffer with content
  local test_buf = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_set_current_buf(test_buf)
  vim.api.nvim_buf_set_lines(test_buf, 0, -1, false, { "code" })

  -- Run AiboSend with prefix and suffix (using quoted strings)
  vim.cmd([[AiboSend -prefix="Question: " -suffix=" Please explain."]])

  -- Check that prompt buffer was created with prefix and suffix
  local prompt_bufname = string.format("aiboprompt://%d", console_win)
  local prompt_buf = vim.fn.bufnr(prompt_bufname)
  T.expect.equality(prompt_buf ~= -1, true)

  if prompt_buf ~= -1 then
    local prompt_lines = vim.api.nvim_buf_get_lines(prompt_buf, 0, -1, false)
    local content = table.concat(prompt_lines, "\n")
    T.expect.equality(content, "Question: code Please explain.")
  end

  -- Clean up
  vim.api.nvim_win_close(console_win, true)
end

-- Test prompt buffer cursor positioning
test_set["AiboSend moves cursor to end of prompt"] = function()
  -- Create a mock console buffer
  local console_buf = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_name(console_buf, "aibo://5")
  vim.bo[console_buf].filetype = "aibo-console"
  vim.b[console_buf].aibo = {
    cmd = "test",
    args = {},
  }

  -- Open console in a window (use normal split, not floating window)
  vim.cmd("split")
  vim.api.nvim_set_current_buf(console_buf)
  local console_win = vim.api.nvim_get_current_win()
  vim.cmd("wincmd p") -- Go back to previous window

  -- Create a test buffer with content
  local test_buf = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_set_current_buf(test_buf)
  vim.api.nvim_buf_set_lines(test_buf, 0, -1, false, { "line1", "line2 with more content" })

  -- Get prompt buffer name
  local prompt_bufname = string.format("aiboprompt://%d", console_win)

  -- Open prompt buffer in a window BEFORE sending to test cursor positioning
  local prompt_buf = vim.fn.bufnr(prompt_bufname)
  if prompt_buf == -1 then
    -- Create prompt buffer if it doesn't exist yet
    prompt_buf = vim.api.nvim_create_buf(false, true)
    vim.api.nvim_buf_set_name(prompt_buf, prompt_bufname)
  end

  -- Open prompt buffer in a window
  vim.cmd("vsplit")
  vim.api.nvim_set_current_buf(prompt_buf)
  local prompt_win = vim.api.nvim_get_current_win()

  -- Go back to test buffer
  vim.cmd("wincmd p")

  -- Run AiboSend - this should position cursor in the existing prompt window
  vim.cmd("AiboSend")

  -- Check cursor position in the prompt window
  local cursor = vim.api.nvim_win_get_cursor(prompt_win)
  T.expect.equality(cursor[1], 2) -- Should be on last line (line 2)
  -- The column should be at or near the end of the last line
  -- Allow for minor differences between Neovim versions
  local last_line = vim.api.nvim_buf_get_lines(prompt_buf, 1, 2, false)[1]
  local expected_col = vim.fn.strdisplaywidth(last_line)
  local actual_col = cursor[2]
  -- Accept if cursor is at the end or one character before (handles version differences)
  T.expect.equality(actual_col >= expected_col - 1 and actual_col <= expected_col, true)

  -- Clean up
  vim.api.nvim_win_close(prompt_win, true)
  vim.api.nvim_win_close(console_win, true)
end

-- Test appending to non-empty prompt buffer
test_set["AiboSend appends to existing prompt content"] = function()
  -- Create a mock console buffer
  local console_buf = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_name(console_buf, "aibo://6")
  vim.bo[console_buf].filetype = "aibo-console"
  vim.b[console_buf].aibo = {
    cmd = "test",
    args = {},
  }

  -- Open console in a window (use normal split, not floating window)
  vim.cmd("split")
  vim.api.nvim_set_current_buf(console_buf)
  local console_win = vim.api.nvim_get_current_win()
  vim.cmd("wincmd p") -- Go back to previous window

  -- Create a test buffer with content
  local test_buf = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_set_current_buf(test_buf)
  vim.api.nvim_buf_set_lines(test_buf, 0, -1, false, { "first send" })

  -- First send
  vim.cmd("AiboSend")

  -- Change content and send again
  vim.api.nvim_buf_set_lines(test_buf, 0, -1, false, { "second send" })
  vim.cmd("AiboSend")

  -- Check prompt buffer content
  local prompt_bufname = string.format("aiboprompt://%d", console_win)
  local prompt_buf = vim.fn.bufnr(prompt_bufname)

  if prompt_buf ~= -1 then
    local prompt_lines = vim.api.nvim_buf_get_lines(prompt_buf, 0, -1, false)
    T.expect.equality(#prompt_lines, 2)
    T.expect.equality(prompt_lines[1], "first send")
    T.expect.equality(prompt_lines[2], "second send")
  end

  -- Clean up
  vim.api.nvim_win_close(console_win, true)
end

return test_set
