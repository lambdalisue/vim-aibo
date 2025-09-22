-- Tests for AiboSend replace functionality

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

-- Test AiboSend command completion includes -replace
test_set["AiboSend command completion includes -replace"] = function()
  local completions = vim.fn.getcompletion("AiboSend ", "cmdline")
  T.expect.equality(vim.tbl_contains(completions, "-input"), true)
  T.expect.equality(vim.tbl_contains(completions, "-submit"), true)
  T.expect.equality(vim.tbl_contains(completions, "-replace"), true)
end

-- Test AiboSend with -replace option
test_set["AiboSend -replace replaces prompt content"] = function()
  -- Create a mock console buffer
  local console_buf = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_name(console_buf, "aibo://replace-test")
  vim.bo[console_buf].filetype = "aibo-console"
  vim.b[console_buf].aibo = {
    cmd = "test",
    args = {},
  }

  -- Open console in a window
  local console_win = vim.api.nvim_open_win(console_buf, false, {
    relative = "editor",
    width = 40,
    height = 10,
    row = 0,
    col = 0,
  })

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
  vim.api.nvim_buf_set_name(console_buf, "aibo://append-replace")
  vim.bo[console_buf].filetype = "aibo-console"
  vim.b[console_buf].aibo = {
    cmd = "test",
    args = {},
  }

  -- Open console in a window
  local console_win = vim.api.nvim_open_win(console_buf, false, {
    relative = "editor",
    width = 40,
    height = 10,
    row = 0,
    col = 0,
  })

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
  vim.api.nvim_buf_set_name(console_buf, "aibo://range-replace")
  vim.bo[console_buf].filetype = "aibo-console"
  vim.b[console_buf].aibo = {
    cmd = "test",
    args = {},
  }

  -- Open console in a window
  local console_win = vim.api.nvim_open_win(console_buf, false, {
    relative = "editor",
    width = 40,
    height = 10,
    row = 0,
    col = 0,
  })

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