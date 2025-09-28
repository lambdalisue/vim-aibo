local eq = MiniTest.expect.equality
local helpers = require("tests.helpers")

local T = helpers.new_set()

-- Mode options for tests
local OPTS_XTERM = { mode = "xterm" }
local OPTS_CSI_N = { mode = "csi-n" }

-- Test basic key resolution
T["resolves basic navigation keys"] = function()
  local termcode = require("aibo.internal.termcode")

  -- Arrow keys
  eq(termcode.resolve("<Up>"), "\27[A")
  eq(termcode.resolve("<Down>"), "\27[B")
  eq(termcode.resolve("<Left>"), "\27[D")
  eq(termcode.resolve("<Right>"), "\27[C")

  -- Home/End
  eq(termcode.resolve("<Home>"), "\27[H")
  eq(termcode.resolve("<End>"), "\27[F")

  -- Page keys
  eq(termcode.resolve("<PageUp>"), "\27[5~")
  eq(termcode.resolve("<PageDown>"), "\27[6~")

  -- Basic keys should work the same in all modes
  eq(termcode.resolve("<Up>", OPTS_XTERM), "\27[A")
  eq(termcode.resolve("<Up>", OPTS_CSI_N), "\27[A")
  eq(termcode.resolve("<Home>", OPTS_XTERM), "\27[H")
  eq(termcode.resolve("<Home>", OPTS_CSI_N), "\27[H")
end

-- Test control characters
T["resolves control characters"] = function()
  local termcode = require("aibo.internal.termcode")

  eq(termcode.resolve("<CR>"), "\13")
  eq(termcode.resolve("<Enter>"), "\13")
  eq(termcode.resolve("<Tab>"), "\9")
  eq(termcode.resolve("<Esc>"), "\27")
  eq(termcode.resolve("<Space>"), " ")
  eq(termcode.resolve("<BS>"), "\127")

  -- Control characters without modifiers should work the same in all modes
  eq(termcode.resolve("<CR>", OPTS_XTERM), "\13")
  eq(termcode.resolve("<CR>", OPTS_CSI_N), "\13")
  eq(termcode.resolve("<Tab>", OPTS_XTERM), "\9")
  eq(termcode.resolve("<Tab>", OPTS_CSI_N), "\9")
end

-- Test control characters with modifiers (hybrid mode - default)
T["resolves control characters with modifier - hybrid mode"] = function()
  local termcode = require("aibo.internal.termcode")

  -- Control+key combinations (hybrid uses xterm where available, csi-n for others)
  eq(termcode.resolve("<C-CR>"), "\27[13;5u") -- CSI 13;5u (no xterm equivalent)
  eq(termcode.resolve("<C-Enter>"), "\27[13;5u") -- CSI 13;5u (no xterm equivalent)
  eq(termcode.resolve("<C-Tab>"), "\27[9;5u") -- CSI 9;5u (no xterm equivalent)
  eq(termcode.resolve("<C-Esc>"), "\27[27;5u") -- CSI 27;5u (no xterm equivalent)
  eq(termcode.resolve("<C-Space>"), "\0") -- C-Space is NUL (xterm)
  eq(termcode.resolve("<C-BS>"), "\8") -- C-BS is BS (xterm)

  -- Shift+key combinations
  eq(termcode.resolve("<S-CR>"), "\27[13;2u") -- CSI 13;2u (no xterm equivalent)
  eq(termcode.resolve("<S-Enter>"), "\27[13;2u") -- CSI 13;2u (no xterm equivalent)
  eq(termcode.resolve("<S-Tab>"), "\27[Z") -- S-Tab is CSI Z (xterm)
  eq(termcode.resolve("<S-Esc>"), "\27[27;2u") -- CSI 27;2u (no xterm equivalent)
  eq(termcode.resolve("<S-Space>"), "\27[32;2u") -- CSI 32;2u (no xterm equivalent)
  eq(termcode.resolve("<S-BS>"), "\27[127;2u") -- CSI 127;2u (no xterm equivalent)

  -- Control+Shift+key combinations (all use csi-n as no xterm equivalents)
  eq(termcode.resolve("<C-S-CR>"), "\27[13;6u") -- CSI 13;6u
  eq(termcode.resolve("<C-S-Enter>"), "\27[13;6u") -- CSI 13;6u
  eq(termcode.resolve("<C-S-Tab>"), "\27[9;6u") -- CSI 9;6u
  eq(termcode.resolve("<C-S-Esc>"), "\27[27;6u") -- CSI 27;6u
  eq(termcode.resolve("<C-S-Space>"), "\27[32;6u") -- CSI 32;6u
  eq(termcode.resolve("<C-S-BS>"), "\27[127;6u") -- CSI 127;6u
end

-- Test control characters with modifiers (xterm mode)
T["resolves control characters with modifier - xterm mode"] = function()
  local termcode = require("aibo.internal.termcode")

  -- Control+key combinations
  eq(termcode.resolve("<C-CR>", OPTS_XTERM), nil) -- Not representable in xterm
  eq(termcode.resolve("<C-Enter>", OPTS_XTERM), nil) -- Not representable in xterm
  eq(termcode.resolve("<C-Tab>", OPTS_XTERM), nil) -- Not representable in xterm
  eq(termcode.resolve("<C-Esc>", OPTS_XTERM), nil) -- Not representable in xterm
  eq(termcode.resolve("<C-Space>", OPTS_XTERM), "\0") -- C-Space is NUL
  eq(termcode.resolve("<C-BS>", OPTS_XTERM), "\8") -- C-BS is BS (ASCII 8)

  -- Shift+key combinations
  eq(termcode.resolve("<S-CR>", OPTS_XTERM), nil) -- Not representable in traditional xterm
  eq(termcode.resolve("<S-Enter>", OPTS_XTERM), nil) -- Some terminals use \27OM, but not standard
  eq(termcode.resolve("<S-Tab>", OPTS_XTERM), "\27[Z") -- S-Tab is CSI Z (widely supported)
  eq(termcode.resolve("<S-Esc>", OPTS_XTERM), nil) -- Not representable in xterm
  eq(termcode.resolve("<S-Space>", OPTS_XTERM), nil) -- Not representable in xterm
  eq(termcode.resolve("<S-BS>", OPTS_XTERM), nil) -- Not representable in xterm

  -- Control+Shift+key combinations - all nil in xterm
  eq(termcode.resolve("<C-S-CR>", OPTS_XTERM), nil)
  eq(termcode.resolve("<C-S-Enter>", OPTS_XTERM), nil)
  eq(termcode.resolve("<C-S-Tab>", OPTS_XTERM), nil)
  eq(termcode.resolve("<C-S-Esc>", OPTS_XTERM), nil)
  eq(termcode.resolve("<C-S-Space>", OPTS_XTERM), nil)
  eq(termcode.resolve("<C-S-BS>", OPTS_XTERM), nil)
end

-- Test control characters with modifiers (csi-n mode)
T["resolves control characters with modifier - csi-n mode"] = function()
  local termcode = require("aibo.internal.termcode")

  -- Control+key combinations
  eq(termcode.resolve("<C-CR>", OPTS_CSI_N), "\27[13;5u") -- CSI 13;5u
  eq(termcode.resolve("<C-Enter>", OPTS_CSI_N), "\27[13;5u") -- CSI 13;5u
  eq(termcode.resolve("<C-Tab>", OPTS_CSI_N), "\27[9;5u") -- CSI 9;5u
  eq(termcode.resolve("<C-Esc>", OPTS_CSI_N), "\27[27;5u") -- CSI 27;5u
  eq(termcode.resolve("<C-Space>", OPTS_CSI_N), "\27[32;5u") -- CSI 32;5u
  eq(termcode.resolve("<C-BS>", OPTS_CSI_N), "\27[127;5u") -- CSI 127;5u

  -- Shift+key combinations
  eq(termcode.resolve("<S-CR>", OPTS_CSI_N), "\27[13;2u") -- CSI 13;2u
  eq(termcode.resolve("<S-Enter>", OPTS_CSI_N), "\27[13;2u") -- CSI 13;2u
  eq(termcode.resolve("<S-Tab>", OPTS_CSI_N), "\27[9;2u") -- CSI 9;2u
  eq(termcode.resolve("<S-Esc>", OPTS_CSI_N), "\27[27;2u") -- CSI 27;2u
  eq(termcode.resolve("<S-Space>", OPTS_CSI_N), "\27[32;2u") -- CSI 32;2u
  eq(termcode.resolve("<S-BS>", OPTS_CSI_N), "\27[127;2u") -- CSI 127;2u

  -- Control+Shift+key combinations
  eq(termcode.resolve("<C-S-CR>", OPTS_CSI_N), "\27[13;6u") -- CSI 13;6u
  eq(termcode.resolve("<C-S-Enter>", OPTS_CSI_N), "\27[13;6u") -- CSI 13;6u
  eq(termcode.resolve("<C-S-Tab>", OPTS_CSI_N), "\27[9;6u") -- CSI 9;6u
  eq(termcode.resolve("<C-S-Esc>", OPTS_CSI_N), "\27[27;6u") -- CSI 27;6u
  eq(termcode.resolve("<C-S-Space>", OPTS_CSI_N), "\27[32;6u") -- CSI 32;6u
  eq(termcode.resolve("<C-S-BS>", OPTS_CSI_N), "\27[127;6u") -- CSI 127;6u
end

-- Test Ctrl combinations
T["resolves Ctrl+letter combinations"] = function()
  local termcode = require("aibo.internal.termcode")

  -- Ctrl+A through Ctrl+Z
  eq(termcode.resolve("<C-A>"), "\1")
  eq(termcode.resolve("<C-B>"), "\2")
  eq(termcode.resolve("<C-C>"), "\3")
  eq(termcode.resolve("<C-L>"), "\12")
  eq(termcode.resolve("<C-Z>"), "\26")

  -- Case insensitive
  eq(termcode.resolve("<C-a>"), "\1")

  -- Ctrl+letter should work the same in all modes
  eq(termcode.resolve("<C-A>", OPTS_XTERM), "\1")
  eq(termcode.resolve("<C-A>", OPTS_CSI_N), "\1")
  eq(termcode.resolve("<C-Z>", OPTS_XTERM), "\26")
  eq(termcode.resolve("<C-Z>", OPTS_CSI_N), "\26")
end

-- Test modified keys
T["resolves modified navigation keys"] = function()
  local termcode = require("aibo.internal.termcode")

  -- Shift combinations
  eq(termcode.resolve("<S-Up>"), "\27[1;2A")
  eq(termcode.resolve("<S-Down>"), "\27[1;2B")

  -- Ctrl combinations
  eq(termcode.resolve("<C-Up>"), "\27[1;5A")
  eq(termcode.resolve("<C-Left>"), "\27[1;5D")
  eq(termcode.resolve("<C-Right>"), "\27[1;5C")

  -- Alt combinations
  eq(termcode.resolve("<A-Up>"), "\27[1;3A")
  eq(termcode.resolve("<M-Up>"), "\27[1;3A") -- Meta = Alt

  -- Combined modifiers
  eq(termcode.resolve("<C-S-Up>"), "\27[1;6A")
  eq(termcode.resolve("<C-A-Up>"), "\27[1;7A")

  -- All modes should produce the same result for navigation keys
  eq(termcode.resolve("<S-Up>", OPTS_XTERM), "\27[1;2A")
  eq(termcode.resolve("<S-Up>", OPTS_CSI_N), "\27[1;2A")
  eq(termcode.resolve("<C-Up>", OPTS_XTERM), "\27[1;5A")
  eq(termcode.resolve("<C-Up>", OPTS_CSI_N), "\27[1;5A")
end

-- Test function keys
T["resolves function keys"] = function()
  local termcode = require("aibo.internal.termcode")

  -- Basic function keys
  eq(termcode.resolve("<F1>"), "\27OP")
  eq(termcode.resolve("<F2>"), "\27OQ")
  eq(termcode.resolve("<F3>"), "\27OR")
  eq(termcode.resolve("<F4>"), "\27OS")
  eq(termcode.resolve("<F5>"), "\27[15~")
  eq(termcode.resolve("<F12>"), "\27[24~")

  -- Modified function keys (F1-F4 change format with modifiers)
  eq(termcode.resolve("<C-F1>"), "\27[1;5P")
  eq(termcode.resolve("<S-F1>"), "\27[1;2P")
  eq(termcode.resolve("<C-F4>"), "\27[1;5S")

  -- Modified function keys (F5-F12 use parameter format)
  eq(termcode.resolve("<S-F5>"), "\27[15;2~")
  eq(termcode.resolve("<C-F5>"), "\27[15;5~")
  eq(termcode.resolve("<C-F12>"), "\27[24;5~")

  -- Function keys should work the same in all modes
  eq(termcode.resolve("<F1>", OPTS_XTERM), "\27OP")
  eq(termcode.resolve("<F1>", OPTS_CSI_N), "\27OP")
  eq(termcode.resolve("<C-F1>", OPTS_XTERM), "\27[1;5P")
  eq(termcode.resolve("<C-F1>", OPTS_CSI_N), "\27[1;5P")
end

-- Test multiple keys
T["resolves multiple key sequences"] = function()
  local termcode = require("aibo.internal.termcode")

  eq(termcode.resolve("<Up><Down>"), "\27[A\27[B")
  eq(termcode.resolve("<C-A><C-B>"), "\1\2")
  eq(termcode.resolve("abc<CR>"), "abc\13")

  -- Multiple key sequences with different modes
  eq(termcode.resolve("<Up><Down>", OPTS_XTERM), "\27[A\27[B")
  eq(termcode.resolve("<Up><Down>", OPTS_CSI_N), "\27[A\27[B")

  -- Mixed sequences with modified control characters
  eq(termcode.resolve("<S-Tab><CR>"), "\27[Z\13") -- hybrid mode
  eq(termcode.resolve("<S-Tab><CR>", OPTS_XTERM), "\27[Z\13")
  eq(termcode.resolve("<S-Tab><CR>", OPTS_CSI_N), "\27[9;2u\13")
end

-- Test literal text
T["handles literal text"] = function()
  local termcode = require("aibo.internal.termcode")

  eq(termcode.resolve("hello"), "hello")
  eq(termcode.resolve("123"), "123")
  eq(termcode.resolve("hello<Space>world"), "hello world")

  -- Literal text should work the same in all modes
  eq(termcode.resolve("hello", OPTS_XTERM), "hello")
  eq(termcode.resolve("hello", OPTS_CSI_N), "hello")
  eq(termcode.resolve("hello<Space>world", OPTS_XTERM), "hello world")
  eq(termcode.resolve("hello<Space>world", OPTS_CSI_N), "hello world")
end

-- Test edge cases
T["handles edge cases"] = function()
  local termcode = require("aibo.internal.termcode")

  -- Empty input
  eq(termcode.resolve(""), nil)
  eq(termcode.resolve(nil), nil)

  -- Unknown keys
  eq(termcode.resolve("<Unknown>"), nil)
  eq(termcode.resolve("<NotAKey>"), nil)

  -- Unclosed brackets
  eq(termcode.resolve("<Up"), "<Up")
  eq(termcode.resolve("text<"), "text<")

  -- Special characters in brackets
  eq(termcode.resolve("<lt>"), "<")
  eq(termcode.resolve("<gt>"), ">")
  eq(termcode.resolve("<Bar>"), "|")

  -- Edge cases should work the same in all modes
  eq(termcode.resolve("", OPTS_XTERM), nil)
  eq(termcode.resolve("", OPTS_CSI_N), nil)
  eq(termcode.resolve("<Unknown>", OPTS_XTERM), nil)
  eq(termcode.resolve("<Unknown>", OPTS_CSI_N), nil)
  eq(termcode.resolve("<lt>", OPTS_XTERM), "<")
  eq(termcode.resolve("<lt>", OPTS_CSI_N), "<")
end

-- Test case sensitivity
T["handles case variations"] = function()
  local termcode = require("aibo.internal.termcode")

  -- Keys are case-insensitive
  eq(termcode.resolve("<up>"), "\27[A")
  eq(termcode.resolve("<UP>"), "\27[A")
  eq(termcode.resolve("<Up>"), "\27[A")

  -- Modifiers too
  eq(termcode.resolve("<c-a>"), "\1")
  eq(termcode.resolve("<C-a>"), "\1")
  eq(termcode.resolve("<C-A>"), "\1")

  -- Case insensitivity should work in all modes
  eq(termcode.resolve("<up>", OPTS_XTERM), "\27[A")
  eq(termcode.resolve("<up>", OPTS_CSI_N), "\27[A")
  eq(termcode.resolve("<c-a>", OPTS_XTERM), "\1")
  eq(termcode.resolve("<c-a>", OPTS_CSI_N), "\1")
end

return T
