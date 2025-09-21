local M = {}

function M.new(bufnr)
  local chan = vim.b[bufnr].terminal_job_id
  if not chan then
    error(string.format('[aibo] Failed to create controller of the buffer (bufnr: %d): terminal channel is not found', bufnr))
  end

  local controller = {
    send = function(data)
      vim.fn.chansend(chan, data)
    end
  }

  return controller
end

return M