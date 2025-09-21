# 🦾 nvim-aibo

[![Neovim](https://img.shields.io/badge/Neovim-0.10.0+-blueviolet.svg?style=flat-square&logo=Neovim&logoColor=white)](https://neovim.io/)
[![Lua](https://img.shields.io/badge/Lua-5.1+-blue.svg?style=flat-square&logo=lua)](https://www.lua.org/)
[![MIT License](https://img.shields.io/badge/license-MIT-green.svg?style=flat-square)](LICENSE)
[![Lua CI](https://github.com/lambdalisue/vim-aibo/actions/workflows/lua.yml/badge.svg)](https://github.com/lambdalisue/vim-aibo/actions/workflows/lua.yml)

AI Bot Integration and Orchestration for Neovim

> [!WARNING]
> This plugin is currently in **alpha stage**. The API and features may change significantly.

https://github.com/user-attachments/assets/18dcdc91-fb8c-4243-af15-df7f0c2fbd02

## Concept

Aibo (from Japanese "companion") provides seamless integration with AI assistants through terminal interfaces in Neovim.

- Pure Lua implementation for Neovim 0.10.0+
- Works with any CLI-based AI tool
- Split-window interface with console and prompt buffers
- Customizable key mappings and behaviors
- Agent-specific configurations via setup()

## Requirements

- Neovim 0.10.0 or later
- AI agent CLI tool (claude, chatgpt, ollama, etc.)

## Installation

Use your preferred plugin manager.

### lazy.nvim

```lua
{
  'lambdalisue/nvim-aibo',
  config = function()
    require('aibo').setup()
  end,
}
```

### packer.nvim

```lua
use {
  'lambdalisue/nvim-aibo',
  config = function()
    require('aibo').setup()
  end,
}
```

## Usage

Start an AI session:

```vim
:Aibo claude
:Aibo claude --continue
:Aibo codex
:Aibo ollama run llama3
```

This opens a terminal console running the AI agent with a prompt buffer below.

Type in the prompt buffer and press `<CR>` in normal mode to submit. The prompt clears automatically for the next message. You can also use `<C-Enter>` or `<F5>` to submit even while in insert mode, which is particularly useful for continuous typing.

To close the session, use `:bdelete!` or `:bwipeout!` on the console buffer.

## Configuration

### Basic Setup

```lua
require('aibo').setup({
  submit_delay = 100,         -- Delay in milliseconds (default: 100)
  prompt_height = 10,         -- Prompt window height (default: 10)
})
```

### Advanced Configuration

```lua
require('aibo').setup({
  -- Prompt buffer configuration
  prompt = {
    keymaps = {
      submit = "<CR>",                          -- Single key
      submit_close = { "<C-Enter>", "<F5>" },   -- Multiple keys
      interrupt = "<C-c>",
      clear = "<C-l>",
      next = "<C-n>",
      prev = "<C-p>",
      down = "<Down>",
      up = "<Up>",
    },
    buffer_options = {
      textwidth = 80,
      expandtab = true,
    },
    window_options = {
      number = false,
      signcolumn = "no",
    },
  },

  -- Console buffer configuration
  console = {
    keymaps = {
      -- Similar structure as prompt
    },
  },

  -- Agent-specific overrides
  agents = {
    claude = {
      -- Claude-specific configuration
      on_attach = function(bufnr, info)
        -- Custom setup for Claude buffers
      end,
    },
    codex = {
      -- Codex-specific configuration
    },
  },
})
```

### Keymap Arrays

You can define multiple keys for the same action:

```lua
require('aibo').setup({
  prompt = {
    keymaps = {
      submit = { "<CR>", "<C-Enter>", "<F5>" },  -- All three keys will submit
      interrupt = { "<C-c>", "<Esc><Esc>" },     -- Either key will interrupt
    }
  }
})
```

## Key Mappings

### Console Buffer

| Key | Action |
|-----|--------|
| `<CR>` | Submit empty line |
| `<Esc>` | Send ESC to terminal |
| `<C-c>` | Send interrupt signal |
| `<C-l>` | Clear terminal |
| `<C-n>` | Navigate to next in history |
| `<C-p>` | Navigate to previous in history |
| `<Down>` | Send down arrow |
| `<Up>` | Send up arrow |

### Prompt Buffer

| Key | Action |
|-----|--------|
| `<CR>` | Submit content (normal mode) |
| `<C-Enter>`* | Submit and close |
| `<F5>` | Submit and close |
| `<C-S-Enter>`* | Submit content |
| `<C-F5>` | Submit content |
| `:w` | Submit content |
| `:wq` | Submit and close |

Plus all console buffer mappings.

### Agent-Specific (Claude)

| Key | Action |
|-----|--------|
| `<S-Tab>`* / `<F2>` | Switch mode |
| `<C-o>` | Toggle verbose |
| `<C-t>` | Show todo |
| `<C-_>` | Undo |
| `<C-z>` | Suspend |
| `<C-v>` | Paste |

> [!IMPORTANT]
> Some key combinations (`<C-Enter>`, `<S-Tab>`) require modern terminal emulators like Kitty, WezTerm, or Ghostty. Use alternatives like `<F5>` or `:w` if these don't work.

## Customization

### Using Action Functions

Action functions are exposed for custom keymaps and scripting:

```lua
-- In your configuration or on_attach callback
local actions = require('aibo').actions.prompt(bufnr)
vim.keymap.set('n', '<C-j>', actions.submit, { buffer = bufnr })
vim.keymap.set('n', '<C-k>', actions.submit_close, { buffer = bufnr })
```

### Agent-Specific Setup

Configure agent-specific behavior through setup:

```lua
require('aibo').setup({
  agents = {
    claude = {
      keymaps = {
        -- Override default keymaps for Claude
        submit = { "<CR>", "<S-Enter>" },
      },
      on_attach = function(bufnr, info)
        -- Claude-specific setup
        local claude = require('aibo').actions.claude(bufnr)
        vim.keymap.set('n', '<leader>m', claude.mode, { buffer = bufnr })
      end,
    },
  },
})
```

### Adding New Agents

Define custom agents with their own configuration:

```lua
require('aibo').setup({
  agents = {
    myai = {
      keymaps = {
        submit = "<Tab>",
      },
      buffer_options = {
        textwidth = 100,
      },
      on_attach = function(bufnr, info)
        vim.keymap.set('n', '<C-g>', function()
          require('aibo').send('\007', bufnr)
        end, { buffer = bufnr })
      end,
    },
  },
})
```

## API

### Core Functions

```lua
local aibo = require('aibo')

-- Configure the plugin (call once)
aibo.setup({
  submit_delay = 150,
  -- ... other configuration
})

-- Send raw data to terminal
aibo.send('Hello\n', bufnr)

-- Submit with automatic return key
aibo.submit('What is Neovim?', bufnr)

-- Get current configuration
local config = aibo.get_config()

-- Get buffer-specific configuration
local prompt_cfg = aibo.get_buffer_config("prompt", "claude")
```

### Action Functions

```lua
-- Access action functions directly
local actions = require('aibo').actions

-- Get prompt buffer actions
local prompt_actions = actions.prompt(bufnr)
prompt_actions.submit()      -- Submit content
prompt_actions.interrupt()   -- Send Ctrl-C
prompt_actions.clear()        -- Clear terminal

-- Get Claude-specific actions
local claude_actions = actions.claude(bufnr)
claude_actions.mode()         -- Toggle mode
claude_actions.verbose()      -- Toggle verbose
claude_actions.todo()         -- Show todo

-- Get Codex-specific actions
local codex_actions = actions.codex(bufnr)
codex_actions.transcript()    -- Show transcript
codex_actions.quit()          -- Quit
```

## License

MIT License

## Contributing

Contributions welcome. Please report issues and submit pull requests on GitHub.

