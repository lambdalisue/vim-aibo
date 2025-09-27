local eq = MiniTest.expect.equality
local helpers = require("tests.helpers")

local T = helpers.new_set()

-- Test Ollama is_available
T["Ollama is_available"] = function()
  local ollama = require("aibo.integration.ollama")

  -- Mock executable
  local original_executable = vim.fn.executable
  vim.fn.executable = function(cmd)
    if cmd == "ollama" then
      return 1
    end
    return 0
  end

  eq(ollama.is_available(), true)

  -- Test when not available
  vim.fn.executable = function()
    return 0
  end
  eq(ollama.is_available(), false)

  -- Restore
  vim.fn.executable = original_executable
end

-- Test Ollama run subcommand completion
T["Ollama run subcommand completion"] = function()
  local ollama = require("aibo.integration.ollama")

  -- Test completing "run" after "ollama"
  local completions = ollama.get_command_completions("", "ollama ", 7)
  eq(#completions, 1)
  eq(completions[1], "run")

  -- Test partial "run" completion
  completions = ollama.get_command_completions("r", "ollama r", 8)
  eq(#completions, 1)
  eq(completions[1], "run")

  -- Test with "ru"
  completions = ollama.get_command_completions("ru", "ollama ru", 9)
  eq(#completions, 1)
  eq(completions[1], "run")
end

-- Test Ollama model completions
T["Ollama model completions"] = function()
  local ollama = require("aibo.integration.ollama")

  -- Mock system command
  local original_system = vim.fn.system
  vim.fn.system = function(cmd)
    -- Handle both string and table forms
    if
      (type(cmd) == "string" and cmd == "ollama list")
      or (type(cmd) == "table" and cmd[1] == "ollama" and cmd[2] == "list")
    then
      return [[NAME                  ID              SIZE      MODIFIED
llama3:latest         abc123          5.5 GB    2 days ago
mistral:latest        def456          4.1 GB    1 week ago
qwen3:latest          ghi789          5.2 GB    3 months ago]]
    end
    return ""
  end

  -- Test completing models after "run"
  local completions = ollama.get_command_completions("", "ollama run ", 11)
  eq(vim.tbl_contains(completions, "llama3:latest"), true)
  eq(vim.tbl_contains(completions, "mistral:latest"), true)
  eq(vim.tbl_contains(completions, "qwen3:latest"), true)
  eq(vim.tbl_contains(completions, "--format"), true) -- Should also include flags

  -- Test partial model completion
  completions = ollama.get_command_completions("ll", "ollama run ll", 13)
  eq(vim.tbl_contains(completions, "llama3:latest"), true)
  eq(vim.tbl_contains(completions, "mistral:latest"), false)

  -- Test completion starting with "q"
  completions = ollama.get_command_completions("q", "ollama run q", 12)
  eq(vim.tbl_contains(completions, "qwen3:latest"), true)
  eq(vim.tbl_contains(completions, "llama3:latest"), false)

  -- Restore
  vim.fn.system = original_system
end

-- Test Ollama flag completions
T["Ollama flag completions"] = function()
  local ollama = require("aibo.integration.ollama")

  -- Mock system command
  local original_system = vim.fn.system
  vim.fn.system = function(cmd)
    if
      (type(cmd) == "string" and cmd == "ollama list")
      or (type(cmd) == "table" and cmd[1] == "ollama" and cmd[2] == "list")
    then
      return "NAME ID SIZE MODIFIED\nllama3:latest abc123 5.5GB 2 days ago"
    end
    return ""
  end

  -- Test flag completion after model
  local completions = ollama.get_command_completions("", "ollama run llama3:latest ", 26)
  eq(vim.tbl_contains(completions, "--format"), true)
  eq(vim.tbl_contains(completions, "--verbose"), true)
  eq(vim.tbl_contains(completions, "--keepalive"), true)
  eq(vim.tbl_contains(completions, "--think"), true)

  -- Test partial flag completion
  completions = ollama.get_command_completions("--v", "ollama run llama3:latest --v", 29)
  eq(vim.tbl_contains(completions, "--verbose"), true)
  eq(vim.tbl_contains(completions, "--format"), false)

  -- Test flags starting with --k
  completions = ollama.get_command_completions("--k", "ollama run llama3:latest --k", 29)
  eq(vim.tbl_contains(completions, "--keepalive"), true)
  eq(vim.tbl_contains(completions, "--verbose"), false)

  -- Restore
  vim.fn.system = original_system
end

-- Test Ollama flag value completions
T["Ollama flag value completions"] = function()
  local ollama = require("aibo.integration.ollama")

  -- Mock system command
  local original_system = vim.fn.system
  vim.fn.system = function(cmd)
    if
      (type(cmd) == "string" and cmd == "ollama list")
      or (type(cmd) == "table" and cmd[1] == "ollama" and cmd[2] == "list")
    then
      return "NAME ID SIZE MODIFIED\nllama3:latest abc123 5.5GB 2 days ago"
    end
    return ""
  end

  -- Test format value completion
  local completions = ollama.get_command_completions("", "ollama run llama3 --format ", 28)
  eq(vim.tbl_contains(completions, "json"), true)

  -- Test keepalive value completion
  completions = ollama.get_command_completions("", "ollama run llama3 --keepalive ", 31)
  eq(vim.tbl_contains(completions, "5m"), true)
  eq(vim.tbl_contains(completions, "10m"), true)
  eq(vim.tbl_contains(completions, "1h"), true)
  eq(vim.tbl_contains(completions, "24h"), true)

  -- Test think value completion
  completions = ollama.get_command_completions("", "ollama run llama3 --think ", 27)
  eq(vim.tbl_contains(completions, "true"), true)
  eq(vim.tbl_contains(completions, "false"), true)
  eq(vim.tbl_contains(completions, "high"), true)
  eq(vim.tbl_contains(completions, "medium"), true)
  eq(vim.tbl_contains(completions, "low"), true)

  -- Test partial value completion
  completions = ollama.get_command_completions("h", "ollama run llama3 --think h", 28)
  eq(vim.tbl_contains(completions, "high"), true)
  eq(vim.tbl_contains(completions, "low"), false)

  -- Restore
  vim.fn.system = original_system
end

-- Test Ollama with no models available
T["Ollama no models available"] = function()
  local ollama = require("aibo.integration.ollama")

  -- Mock empty ollama list
  local original_system = vim.fn.system
  vim.fn.system = function(cmd)
    if
      (type(cmd) == "string" and cmd == "ollama list")
      or (type(cmd) == "table" and cmd[1] == "ollama" and cmd[2] == "list")
    then
      return "NAME ID SIZE MODIFIED\n"
    end
    return ""
  end

  -- Should still show flags even with no models
  local completions = ollama.get_command_completions("", "ollama run ", 11)
  eq(vim.tbl_contains(completions, "--format"), true)
  eq(vim.tbl_contains(completions, "--verbose"), true)

  -- Restore
  vim.fn.system = original_system
end

return T
