local eq = MiniTest.expect.equality
local helpers = require("tests.helpers")

local T = helpers.new_set()

-- Helper to create a temporary window
local function create_temp_window()
  vim.cmd("vsplit")
  return vim.api.nvim_get_current_win()
end

-- Helper to wait for event
local function wait_for_event(events, timeout)
  timeout = timeout or 500
  vim.wait(timeout, function()
    return #events > 0
  end)
end

T["creates new tracker instance"] = function()
  local window_tracker = require("aibo.internal.window_tracker")
  local tracker = window_tracker.new()
  eq(type(tracker), "table")
end

T["creates tracker with custom interval"] = function()
  local window_tracker = require("aibo.internal.window_tracker")
  local tracker = window_tracker.new({ interval = 50 })
  eq(type(tracker), "table")
end

T["start/stop tracking"] = function()
  local window_tracker = require("aibo.internal.window_tracker")
  local tracker = window_tracker.new({ interval = 50 })

  tracker:start()
  -- Multiple starts should not cause issues
  tracker:start()

  tracker:stop()
  -- Multiple stops should not cause issues
  tracker:stop()
end

T["subscribe/unsubscribe"] = function()
  local window_tracker = require("aibo.internal.window_tracker")
  local tracker = window_tracker.new()

  local unsubscribe = tracker:subscribe(1000, function()
  end)

  eq(type(unsubscribe), "function")
  unsubscribe()
end

T["detects buffer_changed event"] = function()
  local window_tracker = require("aibo.internal.window_tracker")
  local tracker = window_tracker.new({ interval = 50 })

  local winid = create_temp_window()
  local events = {}

  tracker:subscribe(winid, function(data)
    table.insert(events, data)
  end)

  tracker:start()

  -- Change buffer
  local new_buf = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_win_set_buf(winid, new_buf)

  wait_for_event(events)

  tracker:stop()
  vim.api.nvim_win_close(winid, true)

  eq(#events >= 1, true)
  eq(events[1].event, "buffer_changed")
  eq(events[1].winid, winid)
  eq(events[1].bufnr, new_buf)
end

T["detects layout_changed event on resize"] = function()
  local window_tracker = require("aibo.internal.window_tracker")
  local tracker = window_tracker.new({ interval = 50 })

  local winid = create_temp_window()
  local events = {}

  tracker:subscribe(winid, function(data)
    table.insert(events, data)
  end)

  tracker:start()

  -- Need to trigger initial state capture
  vim.wait(100)
  events = {}

  -- Change window size
  local current_width = vim.api.nvim_win_get_width(winid)
  vim.api.nvim_win_set_width(winid, current_width + 5)

  wait_for_event(events)

  tracker:stop()
  vim.api.nvim_win_close(winid, true)

  eq(#events >= 1, true)
  eq(events[1].event, "layout_changed")
  eq(events[1].winid, winid)
end

T["detects layout_changed event on move"] = function()
  local window_tracker = require("aibo.internal.window_tracker")
  local tracker = window_tracker.new({ interval = 50 })

  vim.cmd("split")
  local winid = vim.api.nvim_get_current_win()
  local events = {}

  tracker:subscribe(winid, function(data)
    table.insert(events, data)
  end)

  tracker:start()

  -- Need to trigger initial state capture
  vim.wait(100)
  events = {}

  -- Move window
  vim.cmd("wincmd K")

  wait_for_event(events)

  tracker:stop()
  vim.api.nvim_win_close(winid, true)

  eq(#events >= 1, true)
  eq(events[1].event, "layout_changed")
  eq(events[1].winid, winid)
end

T["buffer_changed has priority over layout_changed"] = function()
  local window_tracker = require("aibo.internal.window_tracker")
  local tracker = window_tracker.new({ interval = 50 })

  local winid = create_temp_window()
  local events = {}

  tracker:subscribe(winid, function(data)
    table.insert(events, data)
  end)

  tracker:start()

  -- Wait for initial state
  vim.wait(100)
  events = {}

  -- Change both buffer and size simultaneously
  local new_buf = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_win_set_buf(winid, new_buf)
  local current_width = vim.api.nvim_win_get_width(winid)
  vim.api.nvim_win_set_width(winid, current_width + 5)

  wait_for_event(events)

  tracker:stop()
  vim.api.nvim_win_close(winid, true)

  -- Should only get buffer_changed event, not layout_changed
  eq(#events, 1)
  eq(events[1].event, "buffer_changed")
end

T["detects disappeared event"] = function()
  local window_tracker = require("aibo.internal.window_tracker")
  local tracker = window_tracker.new({ interval = 50 })

  local winid = create_temp_window()
  local events = {}

  tracker:subscribe(winid, function(data)
    table.insert(events, data)
  end)

  tracker:start()

  -- Wait for initial state
  vim.wait(100)
  events = {}

  -- Close window
  vim.api.nvim_win_close(winid, true)

  wait_for_event(events)

  tracker:stop()

  eq(#events >= 1, true)
  eq(events[1].event, "disappeared")
  eq(events[1].winid, winid)
end

T["multiple subscribers on same window"] = function()
  local window_tracker = require("aibo.internal.window_tracker")
  local tracker = window_tracker.new({ interval = 50 })

  local winid = create_temp_window()
  local events1 = {}
  local events2 = {}

  tracker:subscribe(winid, function(data)
    table.insert(events1, data)
  end)

  tracker:subscribe(winid, function(data)
    table.insert(events2, data)
  end)

  tracker:start()

  -- Change buffer
  local new_buf = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_win_set_buf(winid, new_buf)

  wait_for_event(events1)
  wait_for_event(events2)

  tracker:stop()
  vim.api.nvim_win_close(winid, true)

  eq(#events1 >= 1, true)
  eq(#events2 >= 1, true)
  eq(events1[1].event, "buffer_changed")
  eq(events2[1].event, "buffer_changed")
end

T["unsubscribe removes callback"] = function()
  local window_tracker = require("aibo.internal.window_tracker")
  local tracker = window_tracker.new({ interval = 50 })

  local winid = create_temp_window()
  local events = {}

  local unsubscribe = tracker:subscribe(winid, function(data)
    table.insert(events, data)
  end)

  tracker:start()
  vim.wait(100)

  -- Unsubscribe before changing buffer
  unsubscribe()

  -- Change buffer
  local new_buf = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_win_set_buf(winid, new_buf)

  vim.wait(200)

  tracker:stop()
  vim.api.nvim_win_close(winid, true)

  -- Should not receive any events after unsubscribe
  eq(#events, 0)
end

T["event data contains correct fields"] = function()
  local window_tracker = require("aibo.internal.window_tracker")
  local tracker = window_tracker.new({ interval = 50 })

  local winid = create_temp_window()
  local event_data = nil

  tracker:subscribe(winid, function(data)
    event_data = data
  end)

  tracker:start()

  -- Change buffer to trigger event
  local new_buf = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_win_set_buf(winid, new_buf)

  wait_for_event({ event_data })

  tracker:stop()
  vim.api.nvim_win_close(winid, true)

  eq(type(event_data.winid), "number")
  eq(type(event_data.winnr), "number")
  eq(type(event_data.bufnr), "number")
  eq(type(event_data.event), "string")
  eq(event_data.winid, winid)
  eq(event_data.bufnr, new_buf)
end

return T
