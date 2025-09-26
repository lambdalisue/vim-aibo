local M = {}

---@class Controller
---@field send fun(data: string): nil Send data to terminal

---Create a new controller for terminal buffer
---@param bufnr integer Buffer number
---@return Controller|nil Controller instance or nil on error
function M.new(bufnr)
  local chan = vim.b[bufnr].terminal_job_id
  if not chan then
    vim.notify(
      ("Failed to create controller for buffer %d: terminal channel not found"):format(bufnr),
      vim.log.levels.ERROR,
      { title = "Aibo" }
    )
    return nil
  end

  ---@type Controller
  local controller = {
    ---Send data to terminal
    ---@param data string Data to send
    send = function(data)
      local ok, err = pcall(vim.fn.chansend, chan, data)
      if not ok then
        vim.notify(
          string.format("Failed to send data to terminal: %s", tostring(err)),
          vim.log.levels.ERROR,
          { title = "Aibo" }
        )
      end
    end,
  }

  return controller
end

return M
