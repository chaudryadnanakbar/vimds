# vimds - Neovim Plugin

A modular Neovim plugin with agent-based architecture, external API support, and beautiful output windows.

## Features

- 🤖 Agent-Based Architecture - Multiple AI agents (Chat, DeepSeek, OpenAI, Webhook, Custom)
- 🔄 Lazy Loading - Loads only when you need it
- 🔌 Toggle On/Off - Enable/disable with a single command
- 📝 Split Window Output - Beautiful markdown output in split windows
- 🌐 HTTP API Server - Interact with external agents via REST API
- 🔌 Socket Server - Unix domain socket for fast IPC
- ⚙️ Easy Configuration - All settings in one config file
- 📊 Activity Logging - Track all plugin activities
- 🎯 Modular Design - Easy to extend and customize

## Installation

### Using the Helper Script (Recommended)

cd scripts
./helper.sh install

### Manual Installation

cp -r plugin ~/.config/nvim/lua/vimds
echo 'require("vimds")' >> ~/.config/nvim/init.lua

### Using Lazy.nvim

Add to ~/.config/nvim/lua/plugins/vimds.lua:

return {
  "vimds",
  lazy = true,
  cmd = "LoadVimds",
  config = function()
    require("vimds")
  end,
}

## Quick Start

1. Load the plugin: :LoadVimds
2. Toggle on/off: :Vimds
3. Open chat: :Chat or <leader>c
4. Send message: :ChatSend Hello
5. Get help: :VimdsHelp
6. Check status: :VimdsStatus

## Agents

| Agent | Description |
|-------|-------------|
| chat | Simple chat agent with dummy responses |
| deepseek | DeepSeek AI via OpenRouter API |
| openai | OpenAI GPT models (requires API key) |
| webhook | Send messages to a webhook endpoint |
| custom | Custom API integration |

### Switching Agents

:AgentSwitch deepseek
:AgentList        " List all available agents
:AgentStatus      " Show current agent status

### DeepSeek Commands

:DeepSeekReload      " Reload API token from ~/.config/openrouter.token
:DeepSeekModel       " Change model
:DeepSeekClear       " Clear conversation history
:DeepSeekModels      " List available models
:DeepSeekTimeout     " Set timeout in seconds

## Commands

| Command | Description |
|---------|-------------|
| :LoadVimds | Load the plugin |
| :Vimds | Toggle plugin on/off |
| :VimdsStatus | Show plugin status |
| :VimdsHelp | Show help in split window |
| :Chat | Open chat buffer |
| :ChatSend <msg> | Send message to default agent |
| :ChatClear | Clear chat buffer |
| :ChatHistory | Show chat history |
| :File | Select and send file |
| :SendVisual | Send visual selection with prompt |
| :SendVisualQuick | Send visual selection without prompt |
| :AgentList | List all available agents |
| :AgentSwitch <name> | Switch default agent |
| :AgentStatus | Show current agent status |
| :AgentLog | Show agent logs |
| :AgentLogClear | Clear logs |
| :AgentLogStatus | Show log status |

## Keymaps

| Key | Description |
|-----|-------------|
| <leader>c | Open chat |
| <leader>f | Select and send file |
| <leader>v | Send visual selection (with prompt) |
| <leader>V | Send visual selection (quick) |
| gv | Send visual selection (with prompt) |
| q | Close output window |

## Configuration

Edit ~/.config/nvim/lua/vimds/config.lua

### Agent Configuration

M.agent = {
  default = "deepseek",
  providers = {
    deepseek = {
      model = "deepseek/deepseek-chat",
      max_tokens = 2000,
      temperature = 0.7,
    },
    openai = {
      api_key = os.getenv("OPENAI_API_KEY") or "",
      model = "gpt-3.5-turbo",
    },
    webhook = {
      url = os.getenv("WEBHOOK_URL") or "",
      method = "POST",
    },
  },
}

### Logging Settings

M.logging = {
  enabled = true,
  level = "info",
  file = os.getenv("HOME") .. "/.vimds_agent.log",
}

## Helper Script Commands

./helper.sh install      # Install the plugin
./helper.sh update       # Update plugin files
./helper.sh uninstall    # Uninstall the plugin
./helper.sh status       # Show plugin status
./helper.sh docs         # Generate documentation
./helper.sh logs         # Show logs
./helper.sh clear-logs   # Clear logs
./helper.sh help         # Show help

## Directory Structure

./
├── scripts/
│   └── helper.sh        # Management script
├── plugin/
│   ├── agents/          # AI agents
│   │   ├── chat.lua
│   │   ├── deepseek.lua
│   │   ├── openai.lua
│   │   ├── webhook.lua
│   │   └── custom.lua
│   ├── handlers/        # Output handlers
│   ├── utils/           # Utilities (buffer, logger)
│   ├── config.lua       # Configuration
│   └── init.lua         # Main plugin
├── docs/                # Generated documentation
└── README.md            # This file

## Logging

Logs are stored in ~/.vimds_agent.log

:AgentLog

## License

MIT License Not sure what it is
