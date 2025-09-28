local eq = MiniTest.expect.equality
local helpers = require("tests.helpers")

local T = helpers.new_set()

-- Tests removed: parse_cmdline function has been removed from production code
-- These tests were only testing string splitting which Neovim already handles via fargs

-- Test parse function without known_options (parses all options)
T["parse handles flags"] = function()
  local argparse = require("aibo.internal.argparse")

  local known_options = { flag1 = true, flag2 = true }
  local options, remaining = argparse.parse({ "-flag1", "-flag2", "arg1" }, { known_options = known_options })
  eq(options.flag1, true)
  eq(options.flag2, true)
  eq(#remaining, 1)
  eq(remaining[1], "arg1")
end

T["parse handles key-value pairs"] = function()
  local argparse = require("aibo.internal.argparse")

  local known_options = { key = true }
  local options, remaining = argparse.parse({ "-key=value", "arg1" }, { known_options = known_options })
  eq(options.key, "value")
  eq(#remaining, 1)
  eq(remaining[1], "arg1")
end

T["parse handles double quoted values"] = function()
  local argparse = require("aibo.internal.argparse")

  -- Simulate what Neovim's fargs would provide
  local args = { '-prefix="Question:', '"', '-suffix="', "Please", 'explain."', "cmd" }
  local known_options = { prefix = true, suffix = true }
  local options, remaining = argparse.parse(args, { known_options = known_options })

  eq(options.prefix, "Question: ")
  eq(options.suffix, " Please explain.")
  eq(#remaining, 1)
  eq(remaining[1], "cmd")
end

T["parse handles single quoted values"] = function()
  local argparse = require("aibo.internal.argparse")

  -- Simulate what Neovim's fargs would provide
  local args = { "-prefix='Question:", "'", "-suffix='", "Please", "explain.'", "cmd" }
  local known_options = { prefix = true, suffix = true }
  local options, remaining = argparse.parse(args, { known_options = known_options })

  eq(options.prefix, "Question: ")
  eq(options.suffix, " Please explain.")
  eq(#remaining, 1)
  eq(remaining[1], "cmd")
end

T["parse handles values with newlines"] = function()
  local argparse = require("aibo.internal.argparse")

  -- Test with actual newline characters (as Neovim would provide after processing escape sequences)
  local args1 = { "-prefix=```python\n", "-suffix=\n```", "cmd" }
  local known_options = { prefix = true, suffix = true }
  local options1, remaining1 = argparse.parse(args1, { known_options = known_options })
  eq(options1.prefix, "```python\n")
  eq(options1.suffix, "\n```")

  -- Test with literal backslash-n (not interpreted as newline)
  local args2 = { "-prefix=```python\\n", "-suffix=\\n```", "cmd" }
  local options2, remaining2 = argparse.parse(args2, { known_options = known_options })
  eq(options2.prefix, "```python\\n")
  eq(options2.suffix, "\\n```")
end

-- Test parse function with known_options
T["parse with known_options handles simple args"] = function()
  local argparse = require("aibo.internal.argparse")

  local known_options = {
    stay = true,
    opener = true,
  }
  -- Options must come before positional arguments
  local options, remaining = argparse.parse(
    { "-stay", "-opener=vsplit", "cmd", "arg" },
    { known_options = known_options }
  )
  eq(options.stay, true)
  eq(options.opener, "vsplit")
  eq(#remaining, 2)
  eq(remaining[1], "cmd")
  eq(remaining[2], "arg")
end

T["parse with known_options handles quoted args"] = function()
  local argparse = require("aibo.internal.argparse")

  -- Simulate what Vim might pass when quotes are used with opener option
  local known_options = {
    opener = true,
    stay = true,
  }
  -- Options come before the command
  local fargs = { '-opener="botright', 'split"', "-stay", "cmd" }
  local options, remaining = argparse.parse(fargs, { known_options = known_options })

  eq(options.opener, "botright split")
  eq(options.stay, true)
  eq(#remaining, 1)
  eq(remaining[1], "cmd")
end

-- New tests for the quote handling fixes
T["parse handles broken single-quoted values"] = function()
  local argparse = require("aibo.internal.argparse")

  -- This simulates how Neovim splits: -opener='botright vsplit'
  local known_options = {
    opener = true,
    stay = true,
  }
  local fargs = { "-opener='botright", "vsplit'", "-stay", "claude" }
  local options, remaining = argparse.parse(fargs, { known_options = known_options })

  eq(options.opener, "botright vsplit")
  eq(options.stay, true)
  eq(#remaining, 1)
  eq(remaining[1], "claude")
end

T["parse handles broken double-quoted values"] = function()
  local argparse = require("aibo.internal.argparse")

  -- This simulates how Neovim splits: -opener="botright vsplit"
  local known_options = {
    opener = true,
    stay = true,
  }
  local fargs = { '-opener="botright', 'vsplit"', "-stay", "claude" }
  local options, remaining = argparse.parse(fargs, { known_options = known_options })

  eq(options.opener, "botright vsplit")
  eq(options.stay, true)
  eq(#remaining, 1)
  eq(remaining[1], "claude")
end

T["parse handles complete quoted values"] = function()
  local argparse = require("aibo.internal.argparse")

  local known_options = { opener = true }

  -- Complete single-quoted value
  local fargs1 = { "-opener='edit'", "claude" }
  local options1, remaining1 = argparse.parse(fargs1, { known_options = known_options })
  eq(options1.opener, "edit")
  eq(#remaining1, 1)
  eq(remaining1[1], "claude")

  -- Complete double-quoted value
  local fargs2 = { '-opener="vsplit"', "claude" }
  local options2, remaining2 = argparse.parse(fargs2, { known_options = known_options })
  eq(options2.opener, "vsplit")
  eq(#remaining2, 1)
  eq(remaining2[1], "claude")
end

T["parse handles unquoted multi-word values"] = function()
  local argparse = require("aibo.internal.argparse")

  local known_options = {
    opener = true,
    stay = true,
  }
  -- Properly escaped multi-word value (using backslash)
  local fargs = { "-opener=botright vsplit", "-stay", "claude" }
  local options, remaining = argparse.parse(fargs, { known_options = known_options })

  eq(options.opener, "botright vsplit")
  eq(options.stay, true)
  eq(#remaining, 1)
  eq(remaining[1], "claude")
end

T["parse stops at first unknown option"] = function()
  local argparse = require("aibo.internal.argparse")

  local known_options = { opener = true } -- Only opener is known
  -- Parsing stops at first unknown option
  local fargs = { "-opener=vsplit", "-unknown=value", "claude", "--permission-mode", "bypassPermission" }
  local options, remaining = argparse.parse(fargs, { known_options = known_options })

  eq(options.opener, "vsplit")
  eq(options.unknown, nil) -- Unknown option not parsed
  eq(#remaining, 4)
  eq(remaining[1], "-unknown=value")
  eq(remaining[2], "claude")
  eq(remaining[3], "--permission-mode")
  eq(remaining[4], "bypassPermission")
end

T["parse stops at first non-option argument"] = function()
  local argparse = require("aibo.internal.argparse")

  local known_options = { opener = true, stay = true }
  -- Parsing stops at first non-option argument
  local fargs = { "-opener=vsplit", "claude", "-stay", "--permission-mode", "bypassPermission" }
  local options, remaining = argparse.parse(fargs, { known_options = known_options })

  eq(options.opener, "vsplit")
  eq(options.stay, nil) -- -stay comes after "claude", so not parsed
  eq(#remaining, 4)
  eq(remaining[1], "claude")
  eq(remaining[2], "-stay")
  eq(remaining[3], "--permission-mode")
  eq(remaining[4], "bypassPermission")
end

T["parse handles -- separator"] = function()
  local argparse = require("aibo.internal.argparse")

  local known_options = { opener = true, stay = true }
  -- -- stops option parsing
  local fargs = { "-opener=vsplit", "--", "-stay", "claude" }
  local options, remaining = argparse.parse(fargs, { known_options = known_options })

  eq(options.opener, "vsplit")
  eq(options.stay, nil) -- -stay comes after --, so not parsed
  eq(#remaining, 2)
  eq(remaining[1], "-stay")
  eq(remaining[2], "claude")
end

T["parse with empty known_options passes all through"] = function()
  local argparse = require("aibo.internal.argparse")

  -- When known_options is empty table, all options should be passed through
  local fargs = { "-any=value", "-flag", "cmd", "arg" }
  local options, remaining = argparse.parse(fargs, { known_options = {} }) -- Empty known_options

  eq(options.any, nil)
  eq(options.flag, nil)
  eq(#remaining, 4)
  eq(remaining[1], "-any=value")
  eq(remaining[2], "-flag")
  eq(remaining[3], "cmd")
  eq(remaining[4], "arg")
end

T["parse strips quotes from values"] = function()
  local argparse = require("aibo.internal.argparse")

  local known_options = { key = true }
  -- Single quotes
  local options1, _ = argparse.parse({ "-key='value with spaces'" }, { known_options = known_options })
  eq(options1.key, "value with spaces")

  -- Double quotes
  local options2, _ = argparse.parse({ '-key="value with spaces"' }, { known_options = known_options })
  eq(options2.key, "value with spaces")

  -- No quotes
  local options3, _ = argparse.parse({ "-key=value" }, { known_options = known_options })
  eq(options3.key, "value")
end

-- Test removed: options_to_args function has been removed from production code
-- This function was only used for testing and not needed in production

-- Test for boolean flags with false value in known_options
T["parse handles boolean flags correctly"] = function()
  local argparse = require("aibo.internal.argparse")

  -- This tests the fix for the bug where boolean flags (value=false) were treated as unknown
  local known_options = {
    opener = true, -- -opener=value (takes a value)
    stay = false, -- -stay flag (boolean flag)
    toggle = false, -- -toggle flag (boolean flag)
    focus = false, -- -focus flag (boolean flag)
  }

  -- Test individual boolean flags
  local options1, remaining1 = argparse.parse({ "-stay" }, { known_options = known_options })
  eq(options1.stay, true)
  eq(#remaining1, 0)

  local options2, remaining2 = argparse.parse({ "-toggle" }, { known_options = known_options })
  eq(options2.toggle, true)
  eq(#remaining2, 0)

  local options3, remaining3 = argparse.parse({ "-focus" }, { known_options = known_options })
  eq(options3.focus, true)
  eq(#remaining3, 0)

  -- Test combination of flags and key-value options
  local options4, remaining4 = argparse.parse(
    { "-opener=split", "-focus", "claude" },
    { known_options = known_options }
  )
  eq(options4.opener, "split")
  eq(options4.focus, true)
  eq(#remaining4, 1)
  eq(remaining4[1], "claude")
end

return T
