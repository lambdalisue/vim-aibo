local M = {}

local TRANSLATION_TABLE = {
  ["<"] = "%%3C",
  [">"] = "%%3E",
  ["|"] = "%%7C",
  ["?"] = "%%3F",
  ["*"] = "%%2A",
  ["/"] = "%%2F",
  [":"] = "%%3A",
  ["+"] = "%%2B",
}

---Encode a bufname with a scheme and components, escaping special characters (space, <, >, |, ?, *, %, /, :, +)
---@param scheme string
---@param components string[]
---@return string
function M.encode(scheme, components)
  local encoded_components = {}
  for _, comp in ipairs(components) do
    table.insert(encoded_components, M.encode_component(comp))
  end
  return scheme .. "://" .. table.concat(encoded_components, "/")
end

---Decode a bufname into its scheme and components, unescaping special characters (space, <, >, |, ?, *, %, /, :, +)
---@param bufname string
---@return string|nil scheme
---@return string[] components
function M.decode(bufname)
  local scheme, path = bufname:match("^(.-)://(.*)$")
  if not scheme or not path then
    return nil, {}
  end
  -- Handle empty path case
  if path == "" then
    return scheme, {}
  end
  local components = {}
  -- Split by / and preserve empty components
  for comp in (path .. "/"):gmatch("([^/]*)/") do
    table.insert(components, M.decode_component(comp))
  end
  return scheme, components
end

---Encode a single component of a bufname, escaping special characters (space, <, >, |, ?, *, %, /, :, +)
---@param component string
---@return string
function M.encode_component(component)
  -- Percent must be escaped first to avoid double-escaping
  component = component:gsub("%%", "%%25")
  -- Then escape other special characters
  for k, v in pairs(TRANSLATION_TABLE) do
    component = component:gsub(k, v)
  end
  -- Space is converted to + (must be done after + is escaped to %2B)
  component = component:gsub(" ", "+")
  return component
end

---Decode a single component of a bufname, unescaping special characters (space, <, >, |, ?, *, %, /, :, +)
---@param component string
---@return string
function M.decode_component(component)
  -- + is converted to space (must be done before %2B is decoded to +)
  component = component:gsub("+", " ")
  -- Then decode other special characters
  for k, v in pairs(TRANSLATION_TABLE) do
    component = component:gsub(v, k)
  end
  -- Percent must be decoded last to avoid double-decoding
  component = component:gsub("%%25", "%%")
  return component
end

return M
