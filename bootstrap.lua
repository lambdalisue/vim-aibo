-- Bootstrap file for lua-language-server
-- This file is used by lua-language-server when running diagnostics via the --check option

-- Set up the Lua path to include the plugin's lua directory
package.path = package.path .. ";./lua/?.lua;./lua/?/init.lua"

-- Mock vim global for static analysis
_G.vim = setmetatable({}, {
  __index = function(_, key)
    return setmetatable({}, {
      __index = function(_, _)
        return function() end
      end
    })
  end
})