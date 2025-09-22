-- Simple test runner for aibo.nvim
-- Run with: nvim --headless -c "luafile tests/test_runner.lua" -c "qa!"

local M = {}

-- Get test directory
local test_dir = debug.getinfo(1, "S").source:sub(2):match("(.*/)") or "./"
local project_root = vim.fn.fnamemodify(test_dir, ":h")

-- Add project root to runtimepath
vim.opt.runtimepath:prepend(project_root)

-- Bootstrap mini.nvim if not installed
local mini_path = vim.fn.stdpath("data") .. "/site/pack/deps/start/mini.nvim"
if not vim.loop.fs_stat(mini_path) then
  print("Installing mini.nvim...")
  vim.fn.system({
    "git",
    "clone",
    "--filter=blob:none",
    "https://github.com/echasnovski/mini.nvim",
    mini_path,
  })
end
vim.cmd("packadd mini.nvim")

-- Load mini.test
local ok, mini_test = pcall(require, "mini.test")
if not ok then
  print("Failed to load mini.test: " .. tostring(mini_test))
  vim.cmd("cquit 1")
  return
end

-- Initialize mini.test
mini_test.setup()

-- List of test files
local test_files = {
  "test_aibo",
  "test_plugin",
  "test_send",
  "test_integration_send",
  "test_integration_claude",
  "test_integration_ollama",
  "test_integration_codex",
}

-- Results tracking
local total_tests = 0
local passed_tests = 0
local failed_tests = 0
local errors = {}

-- Simple test runner
for _, file in ipairs(test_files) do
  local test_path = test_dir .. file .. ".lua"
  local ok, test_set = pcall(dofile, test_path)

  if ok and test_set then
    print("\nRunning " .. file .. "...")

    -- Run each test in the set
    for test_name, test_fn in pairs(test_set) do
      if type(test_fn) == "function" and test_name ~= "hooks" then
        total_tests = total_tests + 1

        -- Run pre_case hook for each test
        if test_set.hooks and test_set.hooks.pre_case then
          pcall(test_set.hooks.pre_case)
        end

        -- Run the test
        local test_ok, test_err = pcall(test_fn)

        -- Run post_case hook for each test
        if test_set.hooks and test_set.hooks.post_case then
          pcall(test_set.hooks.post_case)
        end

        if test_ok then
          passed_tests = passed_tests + 1
          print("  ✓ " .. test_name)
        else
          failed_tests = failed_tests + 1
          print("  ✗ " .. test_name)
          table.insert(errors, {
            file = file,
            test = test_name,
            error = test_err,
          })
        end
      end
    end
  else
    print("Failed to load " .. file .. ": " .. tostring(test_set))
  end
end

-- Print summary
print("\n" .. string.rep("=", 50))
print("Test Summary:")
print("  Total: " .. total_tests)
print("  Passed: " .. passed_tests)
print("  Failed: " .. failed_tests)

-- Print errors if any
if #errors > 0 then
  print("\nErrors:")
  for _, err in ipairs(errors) do
    print("\n  " .. err.file .. " - " .. err.test .. ":")
    print("    " .. tostring(err.error))
  end
  vim.cmd("cquit 1")
else
  print("\nAll tests passed!")
end

-- Function to run a specific test file
function M.run_file(test_file)
  local ok, test_set = pcall(dofile, test_file)
  if ok and test_set then
    require("mini.test").run(test_set)
  else
    print("Failed to load test file: " .. tostring(test_set))
  end
end

return M
