-- Tests for prompt_window module (lua/aibo/internal/prompt_window.lua)

local helpers = require("tests.helpers")
local T = require("mini.test")

-- Test set
-- Load modules first to ensure autocmd groups exist
local _console = require("aibo.internal.console_window")
local _prompt = require("aibo.internal.prompt_window")

local test_set = T.new_set({
  hooks = {
    pre_case = function()
      helpers.setup()
      -- Disable all aibo autocmds that interfere with tests
      pcall(vim.api.nvim_clear_autocmds, { group = "aibo_plugin" })
      pcall(vim.api.nvim_clear_autocmds, { group = "aibo_console_internal" })
      pcall(vim.api.nvim_clear_autocmds, { group = "aibo_prompt_internal" })
      -- Clear any existing windows
      for _, buf in ipairs(vim.api.nvim_list_bufs()) do
        local name = vim.api.nvim_buf_get_name(buf)
        if name:match("^aiboprompt://") or name:match("^aiboconsole://") then
          pcall(vim.api.nvim_buf_delete, buf, { force = true })
        end
      end
    end,
    post_case = function()
      helpers.cleanup()
      -- Clean up any created buffers/windows
      for _, buf in ipairs(vim.api.nvim_list_bufs()) do
        local name = vim.api.nvim_buf_get_name(buf)
        if name:match("^aiboprompt://") or name:match("^aiboconsole://") then
          pcall(vim.api.nvim_buf_delete, buf, { force = true })
        end
      end
    end,
  },
})

-- Parse bufname tests
test_set["parse_bufname parses valid prompt buffer names"] = function()
  local prompt = require("aibo.internal.prompt_window")

  local bufname = "aiboprompt://1234"
  local bufnr = vim.fn.bufadd(bufname)
  local info = prompt.get_info_by_bufnr(bufnr)

  T.expect.equality(info ~= nil, true, "Should parse prompt buffer name")
  T.expect.equality(info.bufnr, bufnr, "Should have correct bufnr")
  T.expect.equality(info.bufname, bufname, "Should have correct bufname")
end

test_set["parse_bufname returns nil for non-prompt buffer"] = function()
  local prompt = require("aibo.internal.prompt_window")

  local bufname = "somefile.txt"
  local bufnr = vim.fn.bufadd(bufname)
  local info = prompt.get_info_by_bufnr(bufnr)

  T.expect.equality(info, nil, "Should return nil for non-prompt buffer")
end

-- get_info_by_bufnr tests
test_set["get_info_by_bufnr returns nil for invalid buffer"] = function()
  local prompt = require("aibo.internal.prompt_window")

  local info = prompt.get_info_by_bufnr(99999)
  T.expect.equality(info, nil, "Should return nil for invalid buffer")
end

test_set["get_info_by_bufnr returns info for valid prompt buffer"] = function()
  local prompt = require("aibo.internal.prompt_window")

  local bufname = "aiboprompt://1234"
  local bufnr = vim.fn.bufadd(bufname)
  local info = prompt.get_info_by_bufnr(bufnr)

  T.expect.equality(info ~= nil, true, "Should return info for prompt buffer")
  T.expect.equality(info.bufnr, bufnr, "Should have correct bufnr")
  T.expect.equality(info.bufname, bufname, "Should have correct bufname")
  T.expect.equality(info.winid, -1, "Should have -1 winid when not displayed")
end

-- get_info_by_winid tests
test_set["get_info_by_winid returns nil for invalid window"] = function()
  local prompt = require("aibo.internal.prompt_window")

  local info = prompt.get_info_by_winid(99999)
  T.expect.equality(info, nil, "Should return nil for invalid window")
end

-- get_info_by_console_winid tests
test_set["get_info_by_console_winid finds prompt for console"] = function()
  local prompt = require("aibo.internal.prompt_window")

  local console_winid = 1234
  local bufname = "aiboprompt://" .. console_winid
  local bufnr = vim.fn.bufadd(bufname)

  local info = prompt.get_info_by_console_winid(console_winid)
  T.expect.equality(info ~= nil, true, "Should find prompt for console")
  T.expect.equality(info.bufnr, bufnr, "Should have correct bufnr")
  T.expect.equality(info.bufname, bufname, "Should have correct bufname")
end

test_set["get_info_by_console_winid returns nil when no prompt"] = function()
  local prompt = require("aibo.internal.prompt_window")

  local info = prompt.get_info_by_console_winid(9999)
  T.expect.equality(info, nil, "Should return nil when no prompt exists")
end

return test_set
