-- Tests for termcode module (lua/aibo/termcode.lua)

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

-- Test basic key resolution
test_set["resolves basic navigation keys"] = function()
  local termcode = require("aibo.termcode")

  -- Arrow keys
  T.eq(termcode.resolve("<Up>"), "\27[A")
  T.eq(termcode.resolve("<Down>"), "\27[B")
  T.eq(termcode.resolve("<Left>"), "\27[D")
  T.eq(termcode.resolve("<Right>"), "\27[C")

  -- Home/End
  T.eq(termcode.resolve("<Home>"), "\27[H")
  T.eq(termcode.resolve("<End>"), "\27[F")

  -- Page keys
  T.eq(termcode.resolve("<PageUp>"), "\27[5~")
  T.eq(termcode.resolve("<PageDown>"), "\27[6~")
end

-- Test control characters
test_set["resolves control characters"] = function()
  local termcode = require("aibo.termcode")

  T.eq(termcode.resolve("<CR>"), "\13")
  T.eq(termcode.resolve("<Enter>"), "\13")
  T.eq(termcode.resolve("<Tab>"), "\9")
  T.eq(termcode.resolve("<Esc>"), "\27")
  T.eq(termcode.resolve("<Space>"), " ")
  T.eq(termcode.resolve("<BS>"), "\127")
end

-- Test Ctrl combinations
test_set["resolves Ctrl+letter combinations"] = function()
  local termcode = require("aibo.termcode")

  -- Ctrl+A through Ctrl+Z
  T.eq(termcode.resolve("<C-A>"), "\1")
  T.eq(termcode.resolve("<C-B>"), "\2")
  T.eq(termcode.resolve("<C-C>"), "\3")
  T.eq(termcode.resolve("<C-L>"), "\12")
  T.eq(termcode.resolve("<C-Z>"), "\26")

  -- Case insensitive
  T.eq(termcode.resolve("<C-a>"), "\1")
end

-- Test modified keys
test_set["resolves modified navigation keys"] = function()
  local termcode = require("aibo.termcode")

  -- Shift combinations
  T.eq(termcode.resolve("<S-Up>"), "\27[1;2A")
  T.eq(termcode.resolve("<S-Down>"), "\27[1;2B")

  -- Ctrl combinations
  T.eq(termcode.resolve("<C-Up>"), "\27[1;5A")
  T.eq(termcode.resolve("<C-Left>"), "\27[1;5D")
  T.eq(termcode.resolve("<C-Right>"), "\27[1;5C")

  -- Alt combinations
  T.eq(termcode.resolve("<A-Up>"), "\27[1;3A")
  T.eq(termcode.resolve("<M-Up>"), "\27[1;3A") -- Meta = Alt

  -- Combined modifiers
  T.eq(termcode.resolve("<C-S-Up>"), "\27[1;6A")
  T.eq(termcode.resolve("<C-A-Up>"), "\27[1;7A")
end

-- Test function keys
test_set["resolves function keys"] = function()
  local termcode = require("aibo.termcode")

  -- Basic function keys
  T.eq(termcode.resolve("<F1>"), "\27OP")
  T.eq(termcode.resolve("<F2>"), "\27OQ")
  T.eq(termcode.resolve("<F3>"), "\27OR")
  T.eq(termcode.resolve("<F4>"), "\27OS")
  T.eq(termcode.resolve("<F5>"), "\27[15~")
  T.eq(termcode.resolve("<F12>"), "\27[24~")

  -- Modified function keys (F1-F4 change format with modifiers)
  T.eq(termcode.resolve("<C-F1>"), "\27[1;5P")
  T.eq(termcode.resolve("<S-F1>"), "\27[1;2P")
  T.eq(termcode.resolve("<C-F4>"), "\27[1;5S")

  -- Modified function keys (F5-F12 use parameter format)
  T.eq(termcode.resolve("<S-F5>"), "\27[15;2~")
  T.eq(termcode.resolve("<C-F5>"), "\27[15;5~")
  T.eq(termcode.resolve("<C-F12>"), "\27[24;5~")
end

-- Test multiple keys
test_set["resolves multiple key sequences"] = function()
  local termcode = require("aibo.termcode")

  T.eq(termcode.resolve("<Up><Down>"), "\27[A\27[B")
  T.eq(termcode.resolve("<C-A><C-B>"), "\1\2")
  T.eq(termcode.resolve("abc<CR>"), "abc\13")
end

-- Test literal text
test_set["handles literal text"] = function()
  local termcode = require("aibo.termcode")

  T.eq(termcode.resolve("hello"), "hello")
  T.eq(termcode.resolve("123"), "123")
  T.eq(termcode.resolve("hello<Space>world"), "hello world")
end

-- Test edge cases
test_set["handles edge cases"] = function()
  local termcode = require("aibo.termcode")

  -- Empty input
  T.eq(termcode.resolve(""), nil)
  T.eq(termcode.resolve(nil), nil)

  -- Unknown keys
  T.eq(termcode.resolve("<Unknown>"), nil)
  T.eq(termcode.resolve("<NotAKey>"), nil)

  -- Unclosed brackets
  T.eq(termcode.resolve("<Up"), "<Up")
  T.eq(termcode.resolve("text<"), "text<")

  -- Special characters in brackets
  T.eq(termcode.resolve("<lt>"), "<")
  T.eq(termcode.resolve("<gt>"), ">")
  T.eq(termcode.resolve("<Bar>"), "|")
end

-- Test case sensitivity
test_set["handles case variations"] = function()
  local termcode = require("aibo.termcode")

  -- Keys are case-insensitive
  T.eq(termcode.resolve("<up>"), "\27[A")
  T.eq(termcode.resolve("<UP>"), "\27[A")
  T.eq(termcode.resolve("<Up>"), "\27[A")

  -- Modifiers too
  T.eq(termcode.resolve("<c-a>"), "\1")
  T.eq(termcode.resolve("<C-a>"), "\1")
  T.eq(termcode.resolve("<C-A>"), "\1")
end

return test_set
