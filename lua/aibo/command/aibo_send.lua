local M = {}

--- Internal completion function for AiboSend command
--- @param arglead string Current argument being completed
--- @param cmdline string Full command line
--- @param _cursorpos number Cursor position (unused)
--- @return string[] List of completions
local function complete(arglead, cmdline, _cursorpos)
  -- Use argparse helpers for option completion
  local argparse = require("aibo.internal.argparse")
  local known_options = {
    input = false, -- -input flag
    submit = false, -- -submit flag
    replace = false, -- -replace flag
    prefix = true, -- -prefix=value
    suffix = true, -- -suffix=value
  }

  -- Return completions for both empty arglead and options
  if arglead == "" or arglead:match("^%-") then
    return argparse.get_option_completions(arglead, cmdline, known_options)
  end
  return {}
end

--- Execute AiboSend command with given options
--- @param options table Options table { line1?: number, line2?: number, input?: boolean, submit?: boolean, replace?: boolean, prefix?: string, suffix?: string }
--- @return nil
function M.call(options)
  options = options or {}

  require("aibo.internal.send").send({
    line1 = options.line1,
    line2 = options.line2,
    input = options.input or false,
    submit = options.submit or false,
    replace = options.replace or false,
    prefix = options.prefix,
    suffix = options.suffix,
  })
end

--- Create AiboSend user command with all functionality
--- @return nil
function M.setup()
  vim.api.nvim_create_user_command("AiboSend", function(cmd_opts)
    -- Parse options using the argparse module
    local argparse = require("aibo.internal.argparse")
    -- Define known AiboSend command options
    local known_options = {
      input = true, -- -input flag
      submit = true, -- -submit flag
      replace = true, -- -replace flag
      prefix = true, -- -prefix=value
      suffix = true, -- -suffix=value
    }
    local options = argparse.parse(cmd_opts.fargs or {}, { known_options = known_options })

    -- Check if a range was explicitly provided
    -- When no range is given, line1 == line2 == current line
    -- In that case, send the whole buffer
    local line1, line2
    if cmd_opts.range == 0 then
      -- No range provided, send whole buffer
      line1 = nil
      line2 = nil
    else
      -- Range provided, use it
      line1 = cmd_opts.line1
      line2 = cmd_opts.line2
    end

    -- Call the API function
    M.call({
      line1 = line1,
      line2 = line2,
      input = options.input or false,
      submit = options.submit or false,
      replace = options.replace or false,
      prefix = options.prefix,
      suffix = options.suffix,
    })
  end, {
    range = true,
    nargs = "*",
    desc = "Send buffer content to Aibo console prompt",
    complete = complete,
  })
end

-- Internal API for testing - should not be used by end users
M._internal = {
  complete = complete,
}

return M
