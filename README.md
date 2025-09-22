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
- Customizable key mappings through ftplugins
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
  -- Optional: setup can be omitted for default configuration
  config = function()
    require('aibo').setup()
  end,
}
```

### packer.nvim

```lua
use {
  'lambdalisue/nvim-aibo',
  -- Optional: setup can be omitted for default configuration
  config = function()
    require('aibo').setup()
  end,
}
```

## Health Check

Run `:checkhealth aibo` to verify your installation and diagnose any issues.

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

The plugin works without any configuration, but you can customize it using `setup()`.
The setup function can be called multiple times to update configuration:

```lua
require('aibo').setup({
  -- Prompt buffer configuration
  prompt = {
    no_default_mappings = false,  -- Set to true to disable default keymaps
    on_attach = function(bufnr, info)
      -- Custom setup for prompt buffers
      -- Runs AFTER ftplugin files
      -- info.type = "prompt"
      -- info.agent = agent name (e.g., "claude")
      -- info.aibo = aibo instance
    end,
  },

  -- Console buffer configuration
  console = {
    no_default_mappings = false,
    on_attach = function(bufnr, info)
      -- Custom setup for console buffers
      -- info.type = "console"
    end,
  },

  -- Agent-specific overrides
  agents = {
    claude = {
      no_default_mappings = false,
      on_attach = function(bufnr, info)
        -- Custom setup for Claude buffers
        -- Called after prompt/console on_attach
      end,
    },
    codex = {
      -- Codex-specific configuration
    },
  },
})
```

### Customizing Keymaps

Default keymaps are defined in ftplugin files. You can customize them in several ways:

#### 1. Using ftplugin files

Create your own ftplugin files in `~/.config/nvim/after/ftplugin/` to customize mappings:

```lua
-- ~/.config/nvim/after/ftplugin/aibo-prompt.lua
local bufnr = vim.api.nvim_get_current_buf()

-- Override specific default mappings
vim.keymap.del('n', '<C-n>', { buffer = bufnr })
vim.keymap.del('n', '<C-p>', { buffer = bufnr })

-- Add your custom mappings
vim.keymap.set('n', '<Down>', '<Plug>(aibo-prompt-next)', { buffer = bufnr })
vim.keymap.set('n', '<Up>', '<Plug>(aibo-prompt-prev)', { buffer = bufnr })
```

```lua
-- ~/.config/nvim/after/ftplugin/aibo-agent-claude.lua
local bufnr = vim.api.nvim_get_current_buf()

-- Add leader-based mappings for Claude
vim.keymap.set('n', '<leader>cm', '<Plug>(aibo-claude-mode)', { buffer = bufnr })
vim.keymap.set('n', '<leader>cv', '<Plug>(aibo-claude-verbose)', { buffer = bufnr })
vim.keymap.set('n', '<leader>ct', '<Plug>(aibo-claude-todo)', { buffer = bufnr })
```

#### 2. Using on_attach callback

Configure mappings through the setup function:

```lua
require('aibo').setup({
  prompt = {
    on_attach = function(bufnr)
      -- Remove default mappings you don't want
      vim.keymap.del('n', '<C-n>', { buffer = bufnr })
      vim.keymap.del('n', '<C-p>', { buffer = bufnr })

      -- Add your own
      vim.keymap.set('n', '<Down>', '<Plug>(aibo-prompt-next)', { buffer = bufnr })
      vim.keymap.set('n', '<Up>', '<Plug>(aibo-prompt-prev)', { buffer = bufnr })
    end,
  },
})
```

#### 3. Disable defaults and set your own

```lua
require('aibo').setup({
  prompt = {
    no_default_mappings = true,
    on_attach = function(bufnr)
      -- Set your own mappings using <Plug> mappings
      vim.keymap.set('n', '<Enter>', '<Plug>(aibo-prompt-submit)', { buffer = bufnr })
      vim.keymap.set('n', '<C-q>', '<Plug>(aibo-prompt-submit-close)', { buffer = bufnr })
    end,
  },
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

### Using <Plug> Mappings

All functionality is exposed through `<Plug>` mappings defined in ftplugin files:

```lua
-- In your configuration or on_attach callback
vim.keymap.set('n', '<C-j>', '<Plug>(aibo-prompt-submit)', { buffer = bufnr })
vim.keymap.set('n', '<C-k>', '<Plug>(aibo-prompt-submit-close)', { buffer = bufnr })
```

### Available <Plug> Mappings

#### Prompt Buffer

| <Plug> Mapping | Description |
|----------------|-------------|
| `<Plug>(aibo-prompt-submit)` | Submit prompt |
| `<Plug>(aibo-prompt-submit-close)` | Submit and close |
| `<Plug>(aibo-prompt-esc)` | Send ESC to agent |
| `<Plug>(aibo-prompt-interrupt)` | Interrupt agent |
| `<Plug>(aibo-prompt-clear)` | Clear screen |
| `<Plug>(aibo-prompt-next)` | Next history |
| `<Plug>(aibo-prompt-prev)` | Previous history |
| `<Plug>(aibo-prompt-down)` | Move down |
| `<Plug>(aibo-prompt-up)` | Move up |

#### Console Buffer

| <Plug> Mapping | Description |
|----------------|-------------|
| `<Plug>(aibo-console-submit)` | Submit empty message |
| `<Plug>(aibo-console-close)` | Close console |
| `<Plug>(aibo-console-esc)` | Send ESC to agent |
| `<Plug>(aibo-console-interrupt)` | Interrupt agent |
| `<Plug>(aibo-console-clear)` | Clear screen |
| `<Plug>(aibo-console-next)` | Next history |
| `<Plug>(aibo-console-prev)` | Previous history |
| `<Plug>(aibo-console-down)` | Move down |
| `<Plug>(aibo-console-up)` | Move up |

#### Claude Agent

| <Plug> Mapping | Description |
|----------------|-------------|
| `<Plug>(aibo-claude-mode)` | Toggle mode |
| `<Plug>(aibo-claude-verbose)` | Toggle verbose |
| `<Plug>(aibo-claude-todo)` | Show todo |
| `<Plug>(aibo-claude-undo)` | Undo |
| `<Plug>(aibo-claude-suspend)` | Suspend |
| `<Plug>(aibo-claude-paste)` | Paste |

#### Codex Agent

| <Plug> Mapping | Description |
|----------------|-------------|
| `<Plug>(aibo-codex-transcript)` | Show transcript |
| `<Plug>(aibo-codex-home)` | Home |
| `<Plug>(aibo-codex-end)` | End |
| `<Plug>(aibo-codex-page-up)` | Page up |
| `<Plug>(aibo-codex-page-down)` | Page down |
| `<Plug>(aibo-codex-quit)` | Quit |

### Agent-Specific Setup

Configure agent-specific behavior through setup:

```lua
require('aibo').setup({
  agents = {
    claude = {
      no_default_mappings = true,  -- Disable Claude-specific defaults
      on_attach = function(bufnr, info)
        -- Set your own Claude-specific mappings
        vim.keymap.set('n', '<leader>m', '<Plug>(aibo-claude-mode)', { buffer = bufnr })
        vim.keymap.set('n', '<leader>v', '<Plug>(aibo-claude-verbose)', { buffer = bufnr })
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
      no_default_mappings = false,
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

-- Get agent-specific configuration
local agent_cfg = aibo.get_agent_config("claude")
```

## License

MIT License

## Contributing

Contributions welcome. Please report issues and submit pull requests on GitHub.