# 🦾 vim-aibo

[![Neovim](https://img.shields.io/badge/Neovim-0.10.0+-blueviolet.svg?style=flat-square&logo=Neovim&logoColor=white)](https://neovim.io/)
[![Lua](https://img.shields.io/badge/Lua-5.1+-blue.svg?style=flat-square&logo=lua)](https://www.lua.org/)
[![MIT License](https://img.shields.io/badge/license-MIT-green.svg?style=flat-square)](LICENSE)

AI Bot Integration and Orchestration for Neovim

> [!WARNING]
> This plugin is currently in **alpha stage**. The API and features may change significantly.

## Concept

Aibo (from Japanese "companion") provides seamless integration with AI assistants through terminal interfaces in Neovim.

- Pure Lua implementation for Neovim 0.10.0+
- Works with any CLI-based AI tool
- Split-window interface with console and prompt buffers
- Customizable key mappings and behaviors
- Agent-specific configurations via ftplugin

## Requirements

- Neovim 0.10.0 or later
- AI agent CLI tool (claude, chatgpt, ollama, etc.)

## Installation

Use your preferred plugin manager.

### lazy.nvim

```lua
{
  'lambdalisue/vim-aibo',
  config = function()
    require('aibo').setup()
  end,
}
```

### packer.nvim

```lua
use {
  'lambdalisue/vim-aibo',
  config = function()
    require('aibo').setup()
  end,
}
```

## Usage

Start an AI session:

```vim
:Aibo claude
:Aibo chatgpt
:Aibo ollama run llama3
```

This opens a terminal console running the AI agent with a prompt buffer below.

Type in the prompt buffer and press `<CR>` in normal mode to submit. The prompt clears automatically for the next message.

To close the session, use `:bdelete!` or `:bwipeout!` on the console buffer.

## Configuration

```lua
require('aibo').setup({
  submit_key = '<CR>',        -- Key to submit input
  submit_delay = 100,         -- Delay in milliseconds
  prompt_height = 10,         -- Prompt window height
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

### Custom Mappings

```lua
-- ~/.config/nvim/after/ftplugin/aibo-prompt.lua
vim.keymap.set('n', '<C-j>', '<Plug>(aibo-submit)', { buffer = true })
vim.keymap.set('n', '<C-k>', '<Plug>(aibo-submit-close)', { buffer = true })
```

### Agent Configuration

```lua
-- ~/.config/nvim/after/ftplugin/aibo-agent-claude.lua
vim.keymap.set('n', '<leader>m', '<Plug>(aibo-claude-mode)', { buffer = true })
```

### Adding New Agents

Create a ftplugin file for your agent:

```lua
-- ~/.config/nvim/after/ftplugin/aibo-agent-myai.lua
vim.keymap.set('n', '<C-g>', function()
  require('aibo').send('\007')
end, { buffer = true })
```

## API

```lua
local aibo = require('aibo')

-- Configure
aibo.setup({ submit_delay = 150 })

-- Send raw data
aibo.send('Hello\n')

-- Submit with return key
aibo.submit('What is Neovim?')

-- Get configuration
local config = aibo.get_config()
```

## License

MIT License

## Contributing

Contributions welcome. Please report issues and submit pull requests on GitHub.

