local M = {}

M.new_set = function(opts)
  local original_hooks_pre_case = opts and opts.hooks and opts.hooks.pre_case
  local original_hooks_post_case = opts and opts.hooks and opts.hooks.post_case
  local original_vim_ui_select = vim.ui.select
  local original_vim_notify = vim.notify

  opts = opts or {}
  opts.hooks = opts.hooks or {}
  opts.hooks.pre_case = function()
    vim.ui.select = function(items, _opts, on_choice)
      if on_choice then
        on_choice(items and items[1] or nil)
      end
    end
    vim.notify = function(...) end
    if original_hooks_pre_case then
      original_hooks_pre_case()
    end
  end
  opts.hooks.post_case = function()
    vim.ui.select = original_vim_ui_select
    vim.notify = original_vim_notify
    vim.cmd("silent! %bwipeout!")
    if original_hooks_post_case then
      original_hooks_post_case()
    end
  end

  return MiniTest.new_set(opts)
end

-- Custom expectations for common test patterns
M.expect = {}

-- Expect command to exist
M.expect.command_exists = function(cmd_name)
  local commands = vim.api.nvim_get_commands({})
  MiniTest.expect.equality(commands[cmd_name] ~= nil, true)
  return commands[cmd_name]
end

return M
