-- Tests for argument parsing functionality

local helpers = require("tests.helpers")
local T = require("mini.test")

-- Test set
local test_set = T.new_set({
  hooks = {
    pre_case = function()
      helpers.setup()
    end,
    post_case = function()
      helpers.cleanup()
    end,
  },
})

-- Test parse_cmdline function
test_set["parse_cmdline handles simple arguments"] = function()
  local argparse = require("aibo.internal.argparse")

  local result = argparse.parse_cmdline("arg1 arg2 arg3")
  T.expect.equality(#result, 3)
  T.expect.equality(result[1], "arg1")
  T.expect.equality(result[2], "arg2")
  T.expect.equality(result[3], "arg3")
end

test_set["parse_cmdline handles double quoted strings"] = function()
  local argparse = require("aibo.internal.argparse")

  local result = argparse.parse_cmdline('arg1 "arg with spaces" arg3')
  T.expect.equality(#result, 3)
  T.expect.equality(result[1], "arg1")
  T.expect.equality(result[2], "arg with spaces")
  T.expect.equality(result[3], "arg3")
end

test_set["parse_cmdline handles single quoted strings"] = function()
  local argparse = require("aibo.internal.argparse")

  local result = argparse.parse_cmdline("arg1 'arg with spaces' arg3")
  T.expect.equality(#result, 3)
  T.expect.equality(result[1], "arg1")
  T.expect.equality(result[2], "arg with spaces")
  T.expect.equality(result[3], "arg3")
end

test_set["parse_cmdline handles escaped quotes"] = function()
  local argparse = require("aibo.internal.argparse")

  local result = argparse.parse_cmdline('arg1 "arg with \\"quotes\\"" arg3')
  T.expect.equality(#result, 3)
  T.expect.equality(result[1], "arg1")
  T.expect.equality(result[2], 'arg with "quotes"')
  T.expect.equality(result[3], "arg3")
end

test_set["parse_cmdline handles escape sequences in double quotes"] = function()
  local argparse = require("aibo.internal.argparse")

  local result = argparse.parse_cmdline('"line1\\nline2" "tab\\there" "quote\\"test"')
  T.expect.equality(#result, 3)
  T.expect.equality(result[1], "line1\nline2")
  T.expect.equality(result[2], "tab\there")
  T.expect.equality(result[3], 'quote"test')
end

test_set["parse_cmdline treats escape sequences as literal in single quotes"] = function()
  local argparse = require("aibo.internal.argparse")

  local result = argparse.parse_cmdline("'line1\\nline2' 'tab\\there' 'quote\\'test'")
  T.expect.equality(#result, 3)
  T.expect.equality(result[1], "line1\\nline2")
  T.expect.equality(result[2], "tab\\there")
  T.expect.equality(result[3], "quote'test")
end

test_set["parse_cmdline handles mixed quotes"] = function()
  local argparse = require("aibo.internal.argparse")

  local result = argparse.parse_cmdline("\"double\" 'single' \"another \\\"double\\\"\" 'another \\'single\\''")
  T.expect.equality(#result, 4)
  T.expect.equality(result[1], "double")
  T.expect.equality(result[2], "single")
  T.expect.equality(result[3], 'another "double"')
  T.expect.equality(result[4], "another 'single'")
end

-- Test parse_options function
test_set["parse_options handles flags"] = function()
  local argparse = require("aibo.internal.argparse")

  local options, remaining = argparse.parse_options({ "-flag1", "-flag2", "arg1" })
  T.expect.equality(options.flag1, true)
  T.expect.equality(options.flag2, true)
  T.expect.equality(#remaining, 1)
  T.expect.equality(remaining[1], "arg1")
end

test_set["parse_options handles key-value pairs"] = function()
  local argparse = require("aibo.internal.argparse")

  local options, remaining = argparse.parse_options({ "-key=value", "arg1" })
  T.expect.equality(options.key, "value")
  T.expect.equality(#remaining, 1)
  T.expect.equality(remaining[1], "arg1")
end

test_set["parse_options handles double quoted values"] = function()
  local argparse = require("aibo.internal.argparse")

  local args = argparse.parse_cmdline('-prefix="Question: " -suffix=" Please explain." cmd')
  local options, remaining = argparse.parse_options(args)

  T.expect.equality(options.prefix, "Question: ")
  T.expect.equality(options.suffix, " Please explain.")
  T.expect.equality(#remaining, 1)
  T.expect.equality(remaining[1], "cmd")
end

test_set["parse_options handles single quoted values"] = function()
  local argparse = require("aibo.internal.argparse")

  local args = argparse.parse_cmdline("-prefix='Question: ' -suffix=' Please explain.' cmd")
  local options, remaining = argparse.parse_options(args)

  T.expect.equality(options.prefix, "Question: ")
  T.expect.equality(options.suffix, " Please explain.")
  T.expect.equality(#remaining, 1)
  T.expect.equality(remaining[1], "cmd")
end

test_set["parse_options with escape sequences"] = function()
  local argparse = require("aibo.internal.argparse")

  -- Double quotes interpret escape sequences
  local args1 = argparse.parse_cmdline('-prefix="```python\\n" -suffix="\\n```" cmd')
  local options1, remaining1 = argparse.parse_options(args1)
  T.expect.equality(options1.prefix, "```python\n")
  T.expect.equality(options1.suffix, "\n```")

  -- Single quotes treat them literally
  local args2 = argparse.parse_cmdline("-prefix='```python\\n' -suffix='\\n```' cmd")
  local options2, remaining2 = argparse.parse_options(args2)
  T.expect.equality(options2.prefix, "```python\\n")
  T.expect.equality(options2.suffix, "\\n```")
end

-- Test parse_fargs function
test_set["parse_fargs handles simple fargs"] = function()
  local argparse = require("aibo.internal.argparse")

  local options, remaining = argparse.parse_fargs({ "-flag", "-key=value", "cmd", "arg" })
  T.expect.equality(options.flag, true)
  T.expect.equality(options.key, "value")
  T.expect.equality(#remaining, 2)
  T.expect.equality(remaining[1], "cmd")
  T.expect.equality(remaining[2], "arg")
end

test_set["parse_fargs handles quoted fargs"] = function()
  local argparse = require("aibo.internal.argparse")

  -- Simulate what Vim might pass when quotes are used
  local fargs = { '-prefix="Question:', '"', '-suffix="', "Please", 'explain."', "cmd" }
  local options, remaining = argparse.parse_fargs(fargs)

  T.expect.equality(options.prefix, "Question: ")
  T.expect.equality(options.suffix, " Please explain.")
  T.expect.equality(#remaining, 1)
  T.expect.equality(remaining[1], "cmd")
end

-- Test options_to_args function
test_set["options_to_args converts back to args"] = function()
  local argparse = require("aibo.internal.argparse")

  local options = {
    flag = true,
    key = "value",
    multiword = "value with spaces",
  }
  local remaining = { "cmd", "arg" }

  local args = argparse.options_to_args(options, remaining)

  -- Check that all components are present (order may vary for options)
  local has_flag = false
  local has_key = false
  local has_multiword = false
  local has_cmd = false
  local has_arg = false

  for _, arg in ipairs(args) do
    if arg == "-flag" then
      has_flag = true
    end
    if arg == "-key=value" then
      has_key = true
    end
    if arg == '-multiword="value with spaces"' then
      has_multiword = true
    end
    if arg == "cmd" then
      has_cmd = true
    end
    if arg == "arg" then
      has_arg = true
    end
  end

  T.expect.equality(has_flag, true)
  T.expect.equality(has_key, true)
  T.expect.equality(has_multiword, true)
  T.expect.equality(has_cmd, true)
  T.expect.equality(has_arg, true)
end

return test_set
