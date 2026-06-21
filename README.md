# BufferBuddy

AI coding assistant for Neovim powered by Google Gemini and Claude.

## Features

- **Interactive chat** — Ask questions about your codebase with AI-powered search
- **Inline editing** — Edit code via natural language instructions
- **Explain code** — Get instant explanations of single lines or selections
- **Smart selection** — Auto-expands to enclosing function/class for edits
- **Tool-supported** — LLM can run ripgrep, ast-grep, and definition searches

## Requirements

- Neovim >= 0.10
- `rg` (ripgrep) for code search
- `ast-grep` (sg) for structural search (optional)
- Google Gemini API key _or_ Anthropic API key (for Claude)

## Installation

### lazy.nvim

```lua
{
  "username/bufferbuddy",
  dependencies = { "nvim-lua/plenary.nvim" },
  opts = {
    api_key = "your-api-key",
  },
}
```

To customize further:

```lua
{
  "username/bufferbuddy",
  dependencies = { "nvim-lua/plenary.nvim" },
  opts = {
    -- Gemini
    api_key = "your-gemini-api-key",
    provider = "gemini",
    model = "gemini-3.1-flash-lite",
    max_tool_rounds = 15,

    -- Or Claude
    -- api_key = "your-anthropic-api-key",
    -- provider = "claude",
    -- model = "claude-3-5-haiku-20241022",
    -- max_tokens = 8192,
  },
}
```

## Setup

```lua
-- Gemini (default)
require("bufferbuddy").setup({
  api_key = "GEMINI_API_KEY",          -- or set GEMINI_API_KEY env var
  provider = "gemini",                 -- default
  model = "gemini-3.1-flash-lite",     -- model name
  max_tool_rounds = 15,               -- max LLM tool call iterations
})

-- Claude
require("bufferbuddy").setup({
  api_key = "ANTHROPIC_API_KEY",       -- or set ANTHROPIC_API_KEY env var
  provider = "claude",
  model = "claude-3-5-haiku-20241022",  -- model name (fastest/cheapest)
  max_tool_rounds = 15,               -- max LLM tool call iterations
  max_tokens = 8192,                  -- max response tokens
})
```

## Usage

| Keymap | Mode | Action |
|---|---|---|
| `<leader>bbq` | normal | Open chat window |
| `<leader>bbq` | visual | Open chat with selection |
| `<leader>bbx` | normal | Explain current line |
| `<leader>bbx` | visual | Explain selection |
| `<leader>bbe` | normal | Edit current line via LLM |
| `<leader>bbe` | visual | Edit selection via LLM |

| Command | Action |
|---|---|
| `:BufferBuddyChat` | Open chat window |

## Configuration

| Key | Default | Description |
|---|---|---|
| `api_key` | `nil` | API key (or env var: `GEMINI_API_KEY` / `ANTHROPIC_API_KEY`) |
| `provider` | `"gemini"` | LLM provider (`"gemini"` or `"claude"`) |
| `model` | auto | Model identifier (auto-selected per provider) |
| `max_tool_rounds` | `15` | Max function-calling rounds |
| `max_tokens` | `nil` | Max response tokens (defaults to 8192 for Claude) |

## Development

Run tests:

```bash
make test
```

Run tests filtered by name:

```bash
make test-filter name="log level"
```

Lint and format:

```bash
make lint
make format
```

## Health

Run `:checkhealth bufferbuddy` to verify your setup.
