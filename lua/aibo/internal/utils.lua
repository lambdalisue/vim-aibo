local M = {}

---Check if running in headless mode
---@return boolean
function M.is_headless()
  return #vim.api.nvim_list_uis() == 0
end

---Select from multiple options, automatically choosing first in headless mode
---@param items table List of items to choose from
---@param prompt string Prompt message for interactive selection
---@param get_display function Function to get display string for an item
---@param get_value function Function to get value from an item
---@return any|nil Selected value or nil if cancelled
function M.select_or_first(items, prompt, get_display, get_value)
  -- Handle empty items
  if not items or vim.tbl_isempty(items) then
    return nil
  end

  -- Convert table-like objects to array if needed
  local item_list = {}
  if #items == 0 then
    -- It's a dictionary, convert to array
    for k, v in pairs(items) do
      table.insert(item_list, { key = k, value = v })
    end
  else
    -- It's already an array
    item_list = items
  end

  if #item_list == 0 then
    return nil
  end

  if #item_list == 1 then
    return get_value(item_list[1])
  end

  if M.is_headless() then
    -- Headless mode - just use the first one
    return get_value(item_list[1])
  end

  -- Interactive mode - let user choose
  local choices = {}
  local value_map = {}

  for _, item in ipairs(item_list) do
    local display = get_display(item)
    table.insert(choices, display)
    value_map[display] = get_value(item)
  end

  local selected = nil
  vim.ui.select(choices, {
    prompt = prompt,
    format_item = function(item)
      return item
    end,
  }, function(choice)
    if choice then
      selected = value_map[choice]
    end
  end)

  return selected
end

return M
