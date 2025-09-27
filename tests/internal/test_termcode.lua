local eq = MiniTest.expect.equality
local helpers = require("tests.helpers")

local T = helpers.new_set()

-- Test basic key resolution
T["resolves basic navigation keys"] = function()
  local termcode = require("aibo.termcode")

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
end

-- Test control characters
T["resolves control characters"] = function()
  local termcode = require("aibo.termcode")

  eq(termcode.resolve("<CR>"), "\13")
  eq(termcode.resolve("<Enter>"), "\13")
  eq(termcode.resolve("<Tab>"), "\9")
  eq(termcode.resolve("<Esc>"), "\27")
  eq(termcode.resolve("<Space>"), " ")
  eq(termcode.resolve("<BS>"), "\127")
end

-- Test Ctrl combinations
T["resolves Ctrl+letter combinations"] = function()
  local termcode = require("aibo.termcode")

  -- Ctrl+A through Ctrl+Z
  eq(termcode.resolve("<C-A>"), "\1")
  eq(termcode.resolve("<C-B>"), "\2")
  eq(termcode.resolve("<C-C>"), "\3")
  eq(termcode.resolve("<C-L>"), "\12")
  eq(termcode.resolve("<C-Z>"), "\26")

  -- Case insensitive
  eq(termcode.resolve("<C-a>"), "\1")
end

-- Test modified keys
T["resolves modified navigation keys"] = function()
  local termcode = require("aibo.termcode")

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
end

-- Test function keys
T["resolves function keys"] = function()
  local termcode = require("aibo.termcode")

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
end

-- Test multiple keys
T["resolves multiple key sequences"] = function()
  local termcode = require("aibo.termcode")

  eq(termcode.resolve("<Up><Down>"), "\27[A\27[B")
  eq(termcode.resolve("<C-A><C-B>"), "\1\2")
  eq(termcode.resolve("abc<CR>"), "abc\13")
end

-- Test literal text
T["handles literal text"] = function()
  local termcode = require("aibo.termcode")

  eq(termcode.resolve("hello"), "hello")
  eq(termcode.resolve("123"), "123")
  eq(termcode.resolve("hello<Space>world"), "hello world")
end

-- Test edge cases
T["handles edge cases"] = function()
  local termcode = require("aibo.termcode")

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
end

-- Test case sensitivity
T["handles case variations"] = function()
  local termcode = require("aibo.termcode")

  -- Keys are case-insensitive
  eq(termcode.resolve("<up>"), "\27[A")
  eq(termcode.resolve("<UP>"), "\27[A")
  eq(termcode.resolve("<Up>"), "\27[A")

  -- Modifiers too
  eq(termcode.resolve("<c-a>"), "\1")
  eq(termcode.resolve("<C-a>"), "\1")
  eq(termcode.resolve("<C-A>"), "\1")
end

return T
