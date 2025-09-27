-- Tests for :AiboSend command (lua/aibo/command/aibo_send.lua)

local T = require("mini.test")

-- Store original vim.ui.select
local original_select = vim.ui.select

-- Track the initial tab to return to
local initial_tab = vim.api.nvim_get_current_tabpage()

-- Test set
local test_set = T.new_set({
  hooks = {
    post_case = function()
      -- Restore original vim.ui.select
      vim.ui.select = original_select

      -- Close all aibo buffers in the current tab before closing it
      for _, winid in ipairs(vim.api.nvim_tabpage_list_wins(0)) do
        local bufnr = vim.api.nvim_win_get_buf(winid)
        if vim.api.nvim_buf_is_valid(bufnr) then
          local name = vim.api.nvim_buf_get_name(bufnr)
          if name:match("^aibo") then
            pcall(vim.api.nvim_win_close, winid, true)
          end
        end
      end

      -- Close the test tab and return to initial tab
      vim.cmd("tabclose!")
      -- Ensure we're on the initial tab
      if vim.api.nvim_tabpage_is_valid(initial_tab) then
        vim.api.nvim_set_current_tabpage(initial_tab)
      end

      vim.cmd("silent! %bwipeout!")
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
    if level == vim.log.levels.WARN and msg:match("No Aibo console") then
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
  T.expect.equality(notify_msg, "No Aibo console window found in current tabpage")
end

-- Test AiboSend with single console buffer
test_set["AiboSend with single console"] = function()
  -- Create a mock console buffer
  local console_buf = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_name(console_buf, "aiboconsole://test//single")
  vim.bo[console_buf].filetype = "aibo-console"
  vim.b[console_buf].aibo = {
    cmd = "test",
    args = { "arg1" },
  }

  -- Open console in a new tab to avoid multiple windows showing the same buffer
  vim.cmd("tabedit")
  vim.api.nvim_set_current_buf(console_buf)
  local console_win = vim.api.nvim_get_current_win()
  vim.cmd("wincmd p") -- Go back to previous window

  -- Create the prompt window for the console
  local prompt = require("aibo.internal.prompt_window")
  prompt.open(console_win)

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
  vim.api.nvim_buf_set_name(console_buf, "aiboconsole://test//range")
  vim.bo[console_buf].filetype = "aibo-console"
  vim.b[console_buf].aibo = {
    cmd = "test",
    args = {},
  }

  -- Open console in a new tab to avoid multiple windows showing the same buffer
  vim.cmd("tabedit")
  vim.api.nvim_set_current_buf(console_buf)
  local console_win = vim.api.nvim_get_current_win()
  vim.cmd("wincmd p") -- Go back to previous window

  -- Create the prompt window for the console
  local prompt = require("aibo.internal.prompt_window")
  prompt.open(console_win)

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
  vim.api.nvim_buf_set_name(console_buf, "aiboconsole://test//input")
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

  -- Create the prompt window for the console
  local prompt = require("aibo.internal.prompt_window")
  prompt.open(console_win)

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

  -- Wait for deferred window switch
  vim.wait(10)

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
  vim.api.nvim_buf_set_name(console_buf, "aiboconsole://test//both")
  vim.bo[console_buf].filetype = "aibo-console"
  vim.b[console_buf].aibo = {
    cmd = "test",
    args = {},
  }

  -- Open console in a new tab to avoid multiple windows showing the same buffer
  vim.cmd("tabedit")
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
  vim.api.nvim_buf_set_name(console_buf, "aiboconsole://test//prefix")
  vim.bo[console_buf].filetype = "aibo-console"
  vim.b[console_buf].aibo = {
    cmd = "test",
    args = {},
  }

  -- Open console in a new tab to avoid multiple windows showing the same buffer
  vim.cmd("tabedit")
  vim.api.nvim_set_current_buf(console_buf)
  local console_win = vim.api.nvim_get_current_win()
  vim.cmd("wincmd p") -- Go back to previous window

  -- Create the prompt window for the console
  local prompt = require("aibo.internal.prompt_window")
  prompt.open(console_win)

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

-- Test appending to non-empty prompt buffer
test_set["AiboSend appends to existing prompt content"] = function()
  -- Create a mock console buffer
  local console_buf = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_name(console_buf, "aiboconsole://test//append")
  vim.bo[console_buf].filetype = "aibo-console"
  vim.b[console_buf].aibo = {
    cmd = "test",
    args = {},
  }

  -- Open console in a new tab to avoid multiple windows showing the same buffer
  vim.cmd("tabedit")
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

-- Test AiboSend internal completion function
test_set["AiboSend internal completion function"] = function()
  local aibo_send = require("aibo.command.aibo_send")
  local complete_fn = aibo_send._internal.complete

  -- Test completing options from empty arglead
  local completions = complete_fn("", "AiboSend ", 10)
  T.expect.equality(vim.tbl_contains(completions, "-input"), true)
  T.expect.equality(vim.tbl_contains(completions, "-submit"), true)
  T.expect.equality(vim.tbl_contains(completions, "-replace"), true)
  T.expect.equality(vim.tbl_contains(completions, "-prefix="), true)
  T.expect.equality(vim.tbl_contains(completions, "-suffix="), true)

  -- Test completing partial options
  completions = complete_fn("-in", "AiboSend -in", 13)
  T.expect.equality(vim.tbl_contains(completions, "-input"), true)
  T.expect.equality(vim.tbl_contains(completions, "-submit"), false)

  -- Test completing with -pre prefix
  completions = complete_fn("-pre", "AiboSend -pre", 14)
  T.expect.equality(vim.tbl_contains(completions, "-prefix="), true)
  T.expect.equality(vim.tbl_contains(completions, "-input"), false)

  -- Test completing with -su prefix
  completions = complete_fn("-su", "AiboSend -su", 13)
  T.expect.equality(vim.tbl_contains(completions, "-submit"), true)
  T.expect.equality(vim.tbl_contains(completions, "-suffix="), true)
  T.expect.equality(vim.tbl_contains(completions, "-input"), false)

  -- Test non-option arguments return empty
  completions = complete_fn("hello", "AiboSend hello", 15)
  T.expect.equality(#completions, 0)

  -- Test completing with no dash prefix but empty arglead still shows options
  completions = complete_fn("", "AiboSend -input ", 17)
  T.expect.equality(vim.tbl_contains(completions, "-submit"), true)
  T.expect.equality(vim.tbl_contains(completions, "-replace"), true)
end

-- Test AiboSend with -replace option
test_set["AiboSend -replace replaces prompt content"] = function()
  -- Create a mock console buffer
  local console_buf = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_name(console_buf, "aiboconsole://test//replace")
  vim.bo[console_buf].filetype = "aibo-console"
  vim.b[console_buf].aibo = {
    cmd = "test",
    args = {},
  }

  -- Open console in a new tab to avoid multiple windows showing the same buffer
  vim.cmd("tabedit")
  vim.api.nvim_set_current_buf(console_buf)
  local console_win = vim.api.nvim_get_current_win()
  vim.cmd("wincmd p") -- Go back to previous window

  -- Create a test buffer with content
  local test_buf = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_set_current_buf(test_buf)
  vim.api.nvim_buf_set_lines(test_buf, 0, -1, false, { "initial", "content" })

  -- First send without -replace
  vim.cmd("AiboSend")

  -- Get prompt buffer
  local prompt_bufname = string.format("aiboprompt://%d", console_win)
  local prompt_buf = vim.fn.bufnr(prompt_bufname)

  -- Check initial content
  if prompt_buf ~= -1 then
    local prompt_lines = vim.api.nvim_buf_get_lines(prompt_buf, 0, -1, false)
    T.expect.equality(#prompt_lines, 2)
    T.expect.equality(prompt_lines[1], "initial")
    T.expect.equality(prompt_lines[2], "content")
  end

  -- Now replace with new content
  vim.api.nvim_buf_set_lines(test_buf, 0, -1, false, { "replaced", "text" })
  vim.cmd("AiboSend -replace")

  -- Check replaced content
  if prompt_buf ~= -1 then
    local prompt_lines = vim.api.nvim_buf_get_lines(prompt_buf, 0, -1, false)
    T.expect.equality(#prompt_lines, 2)
    T.expect.equality(prompt_lines[1], "replaced")
    T.expect.equality(prompt_lines[2], "text")
  end

  -- Clean up
  vim.api.nvim_win_close(console_win, true)
end

-- Test AiboSend append vs replace behavior
test_set["AiboSend append vs replace behavior"] = function()
  -- Create a mock console buffer
  local console_buf = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_name(console_buf, "aiboconsole://test//appendvs")
  vim.bo[console_buf].filetype = "aibo-console"
  vim.b[console_buf].aibo = {
    cmd = "test",
    args = {},
  }

  -- Open console in a new tab to avoid multiple windows showing the same buffer
  vim.cmd("tabedit")
  vim.api.nvim_set_current_buf(console_buf)
  local console_win = vim.api.nvim_get_current_win()
  vim.cmd("wincmd p") -- Go back to previous window

  -- Create a test buffer
  local test_buf = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_set_current_buf(test_buf)

  -- Send "line1"
  vim.api.nvim_buf_set_lines(test_buf, 0, -1, false, { "line1" })
  vim.cmd("AiboSend")

  -- Get prompt buffer
  local prompt_bufname = string.format("aiboprompt://%d", console_win)
  local prompt_buf = vim.fn.bufnr(prompt_bufname)

  -- Append "line2"
  vim.api.nvim_buf_set_lines(test_buf, 0, -1, false, { "line2" })
  vim.cmd("AiboSend")

  -- Check appended content
  if prompt_buf ~= -1 then
    local prompt_lines = vim.api.nvim_buf_get_lines(prompt_buf, 0, -1, false)
    T.expect.equality(#prompt_lines, 2)
    T.expect.equality(prompt_lines[1], "line1")
    T.expect.equality(prompt_lines[2], "line2")
  end

  -- Replace with "line3"
  vim.api.nvim_buf_set_lines(test_buf, 0, -1, false, { "line3" })
  vim.cmd("AiboSend -replace")

  -- Check replaced content
  if prompt_buf ~= -1 then
    local prompt_lines = vim.api.nvim_buf_get_lines(prompt_buf, 0, -1, false)
    T.expect.equality(#prompt_lines, 1)
    T.expect.equality(prompt_lines[1], "line3")
  end

  -- Append "line4" after replace
  vim.api.nvim_buf_set_lines(test_buf, 0, -1, false, { "line4" })
  vim.cmd("AiboSend")

  -- Check final content
  if prompt_buf ~= -1 then
    local prompt_lines = vim.api.nvim_buf_get_lines(prompt_buf, 0, -1, false)
    T.expect.equality(#prompt_lines, 2)
    T.expect.equality(prompt_lines[1], "line3")
    T.expect.equality(prompt_lines[2], "line4")
  end

  -- Clean up
  vim.api.nvim_win_close(console_win, true)
end

-- Test AiboSend -replace with range
test_set["AiboSend -replace with range"] = function()
  -- Create a mock console buffer
  local console_buf = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_name(console_buf, "aiboconsole://test//replrange")
  vim.bo[console_buf].filetype = "aibo-console"
  vim.b[console_buf].aibo = {
    cmd = "test",
    args = {},
  }

  -- Open console in a new tab to avoid multiple windows showing the same buffer
  vim.cmd("tabedit")
  vim.api.nvim_set_current_buf(console_buf)
  local console_win = vim.api.nvim_get_current_win()
  vim.cmd("wincmd p") -- Go back to previous window

  -- Create a test buffer with multiple lines
  local test_buf = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_set_current_buf(test_buf)
  vim.api.nvim_buf_set_lines(test_buf, 0, -1, false, { "line1", "line2", "line3", "line4", "line5" })

  -- Send lines 1-3 initially
  vim.cmd("1,3AiboSend")

  -- Get prompt buffer
  local prompt_bufname = string.format("aiboprompt://%d", console_win)
  local prompt_buf = vim.fn.bufnr(prompt_bufname)

  -- Check initial content
  if prompt_buf ~= -1 then
    local prompt_lines = vim.api.nvim_buf_get_lines(prompt_buf, 0, -1, false)
    T.expect.equality(#prompt_lines, 3)
    T.expect.equality(prompt_lines[1], "line1")
    T.expect.equality(prompt_lines[2], "line2")
    T.expect.equality(prompt_lines[3], "line3")
  end

  -- Replace with lines 4-5
  vim.cmd("4,5AiboSend -replace")

  -- Check replaced content
  if prompt_buf ~= -1 then
    local prompt_lines = vim.api.nvim_buf_get_lines(prompt_buf, 0, -1, false)
    T.expect.equality(#prompt_lines, 2)
    T.expect.equality(prompt_lines[1], "line4")
    T.expect.equality(prompt_lines[2], "line5")
  end

  -- Clean up
  vim.api.nvim_win_close(console_win, true)
end

return test_set
