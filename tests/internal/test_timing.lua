local eq = MiniTest.expect.equality
local helpers = require("tests.helpers")

local T = helpers.new_set()

-- Debounce tests
T["debounce delays function execution"] = function()
  local timing = require("aibo.internal.timing")

  local called = false
  local value = nil
  local fn = timing.debounce(50, function(v)
    called = true
    value = v
  end)

  fn("test")
  eq(called, false)

  vim.wait(150, function()
    return called
  end)
  eq(called, true)
  eq(value, "test")
end

T["debounce cancels previous timer on multiple calls"] = function()
  local timing = require("aibo.internal.timing")

  local call_count = 0
  local last_value = nil
  local fn = timing.debounce(50, function(v)
    call_count = call_count + 1
    last_value = v
  end)

  fn("first")
  fn("second")
  fn("third")

  vim.wait(150, function()
    return call_count > 0
  end)
  eq(call_count, 1)
  eq(last_value, "third")
end

T["debounce handles multiple arguments"] = function()
  local timing = require("aibo.internal.timing")

  local args = nil
  local fn = timing.debounce(50, function(a, b, c)
    args = { a, b, c }
  end)

  fn("one", "two", "three")

  vim.wait(150, function()
    return args ~= nil
  end)
  eq(args[1], "one")
  eq(args[2], "two")
  eq(args[3], "three")
end

T["debounce creates independent functions"] = function()
  local timing = require("aibo.internal.timing")

  local count1 = 0
  local count2 = 0

  local fn1 = timing.debounce(50, function()
    count1 = count1 + 1
  end)

  local fn2 = timing.debounce(50, function()
    count2 = count2 + 1
  end)

  fn1()
  fn2()

  vim.wait(150, function()
    return count1 > 0 and count2 > 0
  end)
  eq(count1, 1)
  eq(count2, 1)
end

T["debounce handles rapid successive calls"] = function()
  local timing = require("aibo.internal.timing")

  local call_count = 0
  local fn = timing.debounce(50, function()
    call_count = call_count + 1
  end)

  -- Rapid fire calls
  for i = 1, 10 do
    fn()
    vim.wait(10)
  end

  -- Wait for debounce to complete
  vim.wait(200, function()
    return call_count > 0
  end)
  eq(call_count, 1)
end

T["debounce executes after exact delay"] = function()
  local timing = require("aibo.internal.timing")

  local called = false
  local fn = timing.debounce(100, function()
    called = true
  end)

  fn()

  -- Should not be called before delay
  vim.wait(50)
  eq(called, false)

  -- Should be called after delay
  vim.wait(150, function()
    return called
  end)
  eq(called, true)
end

T["debounce handles nil arguments"] = function()
  local timing = require("aibo.internal.timing")

  local args = nil
  local fn = timing.debounce(50, function(a, b)
    args = { a, b }
  end)

  fn(nil, "value")

  vim.wait(150, function()
    return args ~= nil
  end)
  eq(args[1], nil)
  eq(args[2], "value")
end

T["debounce works with zero delay"] = function()
  local timing = require("aibo.internal.timing")

  local called = false
  local fn = timing.debounce(0, function()
    called = true
  end)

  fn()

  vim.wait(50, function()
    return called
  end)
  eq(called, true)
end

-- Throttle tests
T["throttle executes immediately on first call"] = function()
  local timing = require("aibo.internal.timing")

  local called = false
  local fn = timing.throttle(100, function()
    called = true
  end)

  fn()
  eq(called, true)
end

T["throttle limits execution rate"] = function()
  local timing = require("aibo.internal.timing")

  local call_count = 0
  local fn = timing.throttle(100, function()
    call_count = call_count + 1
  end)

  -- First call executes immediately
  fn()
  eq(call_count, 1)

  -- Second call should be throttled
  fn()
  eq(call_count, 1)

  -- Wait for throttle period
  vim.wait(150, function()
    return call_count > 1
  end)

  -- Now it should execute the pending call
  eq(call_count, 2)
end

T["throttle executes trailing call with latest arguments"] = function()
  local timing = require("aibo.internal.timing")

  local values = {}
  local fn = timing.throttle(100, function(v)
    table.insert(values, v)
  end)

  fn("first") -- Executes immediately
  fn("second") -- Throttled
  fn("third") -- Throttled, replaces "second"

  vim.wait(150, function()
    return #values >= 2
  end)
  eq(#values, 2)
  eq(values[1], "first")
  eq(values[2], "third")
end

T["throttle handles multiple arguments"] = function()
  local timing = require("aibo.internal.timing")

  local args = nil
  local fn = timing.throttle(50, function(a, b, c)
    args = { a, b, c }
  end)

  fn("one", "two", "three")
  eq(args[1], "one")
  eq(args[2], "two")
  eq(args[3], "three")
end

T["throttle creates independent functions"] = function()
  local timing = require("aibo.internal.timing")

  local count1 = 0
  local count2 = 0

  local fn1 = timing.throttle(50, function()
    count1 = count1 + 1
  end)

  local fn2 = timing.throttle(50, function()
    count2 = count2 + 1
  end)

  fn1()
  fn2()
  eq(count1, 1)
  eq(count2, 1)

  fn1()
  fn2()
  eq(count1, 1)
  eq(count2, 1)

  vim.wait(100, function()
    return count1 > 1 and count2 > 1
  end)
  eq(count1, 2)
  eq(count2, 2)
end

T["throttle handles rapid successive calls"] = function()
  local timing = require("aibo.internal.timing")

  local call_count = 0
  local fn = timing.throttle(100, function()
    call_count = call_count + 1
  end)

  -- Rapid fire 10 calls over 200ms
  for i = 1, 10 do
    fn()
    vim.wait(20)
  end

  -- Should have executed: once immediately, once after 100ms, once after 200ms, and pending one
  vim.wait(150, function()
    return call_count >= 3
  end)
  -- With throttling at 100ms interval, we expect about 3-4 executions
  local is_in_range = call_count >= 3 and call_count <= 5
  eq(is_in_range, true)
end

T["throttle works with zero delay"] = function()
  local timing = require("aibo.internal.timing")

  local call_count = 0
  local fn = timing.throttle(0, function()
    call_count = call_count + 1
  end)

  fn()
  fn()
  fn()
  eq(call_count, 3)
end

T["throttle handles nil arguments"] = function()
  local timing = require("aibo.internal.timing")

  local args_list = {}
  local fn = timing.throttle(50, function(a, b)
    table.insert(args_list, { a, b })
  end)

  fn(nil, "value")
  eq(#args_list, 1)
  eq(args_list[1][1], nil)
  eq(args_list[1][2], "value")

  fn("test", nil)
  vim.wait(100, function()
    return #args_list >= 2
  end)
  eq(#args_list, 2)
  eq(args_list[2][1], "test")
  eq(args_list[2][2], nil)
end

return T
