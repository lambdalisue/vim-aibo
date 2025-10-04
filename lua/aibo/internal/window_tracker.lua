local M = {}

---@class WindowState
---@field winid integer Window ID
---@field winnr integer Window number
---@field bufnr integer Buffer number
---@field pos table Window position {row, col}
---@field size table Window size {width, height}

---@alias WindowEvent "buffer_changed" | "layout_changed" | "disappeared"

---@class WindowEventData
---@field winid integer Window ID
---@field winnr integer Window number
---@field bufnr integer Buffer number
---@field event WindowEvent Event type

---@class WindowTracker
---@field private state table<integer, WindowState> Map of window states
---@field private timer uv_timer_t|nil Timer for periodic updates
---@field private interval number Update interval in milliseconds
---@field private subscribers table<integer, function[]> Map of window subscribers
local WindowTracker = {}
WindowTracker.__index = WindowTracker

---Create a new WindowTracker instance
---@param opts? {interval?: number} Options
---@return WindowTracker
function M.new(opts)
  opts = opts or {}
  local self = setmetatable({
    state = {},
    timer = nil,
    interval = opts.interval or 100, -- Default 100ms
    subscribers = {},
  }, WindowTracker)
  return self
end

---Start tracking
function WindowTracker:start()
  if self.timer then
    return -- Already started
  end

  self.timer = vim.loop.new_timer()
  self.timer:start(
    0, -- Start immediately
    self.interval,
    vim.schedule_wrap(function()
      self:_update()
    end)
  )
end

---Stop tracking
function WindowTracker:stop()
  if self.timer then
    self.timer:stop()
    self.timer:close()
    self.timer = nil
  end
end

---Subscribe to window events for a specific window
---@param winid integer Window ID to watch
---@param callback fun(data: WindowEventData) Callback function called when window events occur
---@return function Unsubscribe function
function WindowTracker:subscribe(winid, callback)
  if not self.subscribers[winid] then
    self.subscribers[winid] = {}
  end

  table.insert(self.subscribers[winid], callback)

  -- Return unsubscribe function
  return function()
    local callbacks = self.subscribers[winid]
    if not callbacks then
      return
    end

    for i, cb in ipairs(callbacks) do
      if cb == callback then
        table.remove(callbacks, i)
        break
      end
    end

    -- Clean up empty subscriber list
    if #callbacks == 0 then
      self.subscribers[winid] = nil
    end
  end
end

---Update window states
---@private
function WindowTracker:_update()
  for winid, _ in pairs(self.subscribers) do
    if vim.api.nvim_win_is_valid(winid) then
      local bufnr = vim.api.nvim_win_get_buf(winid)
      local winnr = vim.api.nvim_win_get_number(winid)
      local pos = vim.api.nvim_win_get_position(winid)
      local width = vim.api.nvim_win_get_width(winid)
      local height = vim.api.nvim_win_get_height(winid)

      local old_state = self.state[winid]
      local new_state = {
        winid = winid,
        winnr = winnr,
        bufnr = bufnr,
        pos = { row = pos[1], col = pos[2] },
        size = { width = width, height = height },
      }

      if old_state then
        -- Check for buffer change (highest priority)
        if old_state.bufnr ~= new_state.bufnr then
          self:_notify_subscribers(winid, winnr, bufnr, "buffer_changed")
        -- Check for any layout change (winnr, position, or size)
        elseif old_state.winnr ~= new_state.winnr
          or old_state.pos.row ~= new_state.pos.row
          or old_state.pos.col ~= new_state.pos.col
          or old_state.size.width ~= new_state.size.width
          or old_state.size.height ~= new_state.size.height then
          self:_notify_subscribers(winid, winnr, bufnr, "layout_changed")
        end
      end

      self.state[winid] = new_state
    else
      -- Window is no longer valid
      local old_state = self.state[winid]
      if old_state then
        self:_notify_subscribers(winid, old_state.winnr, old_state.bufnr, "disappeared")
        self.state[winid] = nil
      end
    end
  end
end

---Notify subscribers for a window
---@private
---@param winid integer Window ID
---@param winnr integer Window number
---@param bufnr integer Buffer number
---@param event WindowEvent Event type
function WindowTracker:_notify_subscribers(winid, winnr, bufnr, event)
  local callbacks = self.subscribers[winid]
  if not callbacks then
    return
  end

  local data = {
    winid = winid,
    winnr = winnr,
    bufnr = bufnr,
    event = event,
  }

  for _, callback in ipairs(callbacks) do
    local ok, err = pcall(callback, data)
    if not ok then
      vim.notify(
        string.format("Error in window tracker subscriber: %s", err),
        vim.log.levels.ERROR
      )
    end
  end
end

return M
