#!/bin/bash

# ============================================
# CHECK: Must be run from scripts/ directory
# ============================================
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CURRENT_DIR="$(pwd)"

if [ "$CURRENT_DIR" != "$SCRIPT_DIR" ]; then
    echo "❌ ERROR: This script must be run from its own directory!"
    echo ""
    echo "Current directory: $CURRENT_DIR"
    echo "Script directory:  $SCRIPT_DIR"
    echo ""
    echo "Please run:"
    echo "  cd $SCRIPT_DIR"
    echo "  ./helper.sh [COMMAND]"
    echo ""
    exit 1
fi

# ============================================
# Colors for output
# ============================================
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# ============================================
# Configuration
# ============================================
NVIM_CONFIG="${HOME}/.config/nvim"
PLUGIN_NAME="vimds"
PLUGIN_PATH="${NVIM_CONFIG}/lua/${PLUGIN_NAME}"
LAZY_PLUGIN_PATH="${NVIM_CONFIG}/lua/plugins"

# Plugin is at the same level as scripts folder
PLUGIN_SOURCE="$(dirname "$SCRIPT_DIR")/plugin"

# ============================================
# Functions
# ============================================
print_status() {
    echo -e "${GREEN}✓${NC} $1"
}

print_error() {
    echo -e "${RED}✗${NC} $1"
}

print_info() {
    echo -e "${YELLOW}→${NC} $1"
}

print_header() {
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${BLUE}  $1${NC}"
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
}

check_lazy_nvim() {
    if [ -f "$NVIM_CONFIG/init.lua" ] && grep -q 'require("lazy")' "$NVIM_CONFIG/init.lua"; then
        return 0  # Lazy.nvim is used
    else
        return 1  # Not using Lazy.nvim
    fi
}

check_status() {
    if [ -d "$PLUGIN_PATH" ] && [ -f "$PLUGIN_PATH/init.lua" ]; then
        echo -e "${GREEN}●${NC} Plugin installed"
        echo -e "  Location: ${YELLOW}$PLUGIN_PATH${NC}"
        
        # Check if it's in Lazy.nvim config
        if [ -f "$LAZY_PLUGIN_PATH/vimds.lua" ]; then
            echo -e "  Config: ${GREEN}Configured in Lazy.nvim${NC} (lazy loaded)"
            # Check Lazy.nvim config to see loading mode
            if grep -q 'auto_start' "$LAZY_PLUGIN_PATH/vimds.lua"; then
                echo -e "  Mode: ${BLUE}Auto-start${NC}"
            elif grep -q 'cmd' "$LAZY_PLUGIN_PATH/vimds.lua"; then
                echo -e "  Mode: ${BLUE}Manual load${NC} (use :vimds)"
            else
                echo -e "  Mode: ${YELLOW}Unknown${NC}"
            fi
        elif [ -f "$NVIM_CONFIG/init.lua" ] && grep -q 'require("vimds")' "$NVIM_CONFIG/init.lua"; then
            if grep -q 'require("vimds").auto_start()' "$NVIM_CONFIG/init.lua"; then
                echo -e "  Mode: ${BLUE}Auto-start${NC}"
            elif grep -q 'require("vimds")' "$NVIM_CONFIG/init.lua" | grep -v 'auto_start'; then
                echo -e "  Mode: ${BLUE}Manual load${NC} (use :vimds)"
            fi
        else
            echo -e "  Mode: ${YELLOW}Not configured${NC}"
        fi
        
        echo -e "  Commands: ${BLUE}:vimds${NC} (load), ${BLUE}:Vimds${NC} (toggle), ${BLUE}:VimdsStatus${NC} (status)"
        echo -e "  Keymaps: ${BLUE}\\c${NC} or ${BLUE}<leader>c${NC} (when enabled)"
        return 0
    else
        echo -e "${RED}○${NC} Plugin not installed"
        return 1
    fi
}

check_plugin_source() {
    if [ ! -d "$PLUGIN_SOURCE" ]; then
        print_error "Plugin source directory not found: $PLUGIN_SOURCE"
        print_info "Expected structure:"
        print_info "  ../plugin/    (same level as scripts folder)"
        print_info "  ../plugin/init.lua"
        return 1
    fi
    
    if [ ! -f "$PLUGIN_SOURCE/init.lua" ]; then
        print_error "init.lua not found in $PLUGIN_SOURCE"
        return 1
    fi
    
    return 0
}

update_plugin() {
    print_header "Updating vimds Plugin Files"
    
    if ! check_plugin_source; then
        return 1
    fi
    
    if [ ! -d "$PLUGIN_PATH" ]; then
        print_error "Plugin is not installed!"
        print_info "Please run './helper.sh install' first"
        return 1
    fi
    
    print_info "Copying updated plugin files from: $PLUGIN_SOURCE"
    # Copy entire directory including subdirectories
    cp -r "$PLUGIN_SOURCE/"* "$PLUGIN_PATH/"
    print_status "Plugin files updated at $PLUGIN_PATH"
    
    echo ""
    print_status "Plugin files updated successfully!"
    print_info "Restart Neovim to apply changes"
}


install_plugin() {
    print_header "Installing vimds Plugin for Neovim"
    
    if ! check_plugin_source; then
        return 1
    fi
    
    if [ -d "$PLUGIN_PATH" ]; then
        print_error "Plugin already installed!"
        echo ""
        check_status
        echo ""
        read -p "Reinstall? (y/N): " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            print_info "Installation cancelled"
            return
        fi
        print_info "Removing old installation..."
        rm -rf "$PLUGIN_PATH"
    fi
    
    if [ ! -d "$NVIM_CONFIG" ]; then
        print_info "Creating Neovim config directory..."
        mkdir -p "$NVIM_CONFIG"
    fi
    
    # Copy plugin directory
    print_info "Copying plugin files from: $PLUGIN_SOURCE"
    mkdir -p "$(dirname "$PLUGIN_PATH")"
    cp -r "$PLUGIN_SOURCE" "$PLUGIN_PATH"
    print_status "Plugin copied to $PLUGIN_PATH"
    
    # Ask user for load mode
    echo ""
    print_header "Select Load Mode"
    echo ""
    echo "  1) Auto-start    - Plugin loads and enables on Neovim startup"
    echo "  2) Manual load   - Load with :vimds command, then toggle with :Vimds"
    echo "  3) Lazy load     - Same as manual but with lazy loading"
    echo ""
    read -p "Select mode (1-3): " MODE
    
    # Update plugin with selected mode
    case $MODE in
        1)
            print_info "Setting up Auto-start mode..."
            sed -i.bak 's/^-- M.auto_start()/M.auto_start()/' "$PLUGIN_PATH/init.lua"
            sed -i.bak 's/^M.lazy_load()/-- M.lazy_load()/' "$PLUGIN_PATH/init.lua"
            rm -f "$PLUGIN_PATH/init.lua.bak"
            print_status "Auto-start mode configured"
            ;;
        2)
            print_info "Setting up Manual load mode..."
            sed -i.bak 's/^-- M.manual_load()/M.manual_load()/' "$PLUGIN_PATH/init.lua"
            sed -i.bak 's/^M.lazy_load()/-- M.lazy_load()/' "$PLUGIN_PATH/init.lua"
            rm -f "$PLUGIN_PATH/init.lua.bak"
            print_status "Manual load mode configured"
            ;;
        3)
            print_info "Setting up Lazy load mode..."
            # Default is already lazy_load
            print_status "Lazy load mode configured"
            ;;
        *)
            print_error "Invalid mode, using Lazy load (default)"
            ;;
    esac
    
    # Check if using Lazy.nvim
    if check_lazy_nvim; then
        print_info "Detected Lazy.nvim - creating plugin config..."
        
        mkdir -p "$LAZY_PLUGIN_PATH"
        cat > "$LAZY_PLUGIN_PATH/vimds.lua" << 'EOF'
return {
  "vimds",
  lazy = true,
  cmd = "vimds",
  config = function()
    require("vimds")
  end,
}
EOF
        print_status "Created Lazy.nvim config"
    else
        # Add to init.lua
        if [ -f "$NVIM_CONFIG/init.lua" ]; then
            if ! grep -q 'require("vimds")' "$NVIM_CONFIG/init.lua"; then
                echo "" >> "$NVIM_CONFIG/init.lua"
                echo "-- vimds plugin" >> "$NVIM_CONFIG/init.lua"
                echo 'require("vimds")' >> "$NVIM_CONFIG/init.lua"
                print_status "Added to init.lua"
            fi
        else
            cat > "$NVIM_CONFIG/init.lua" << 'EOF'
-- vimds plugin
require("vimds")
EOF
            print_status "Created init.lua"
        fi
    fi
    
    echo ""
    print_status "vimds plugin installed successfully!"
    echo ""
    print_header "Installation Complete"
    check_status
    echo ""
    
    case $MODE in
        1)
            print_info "Auto-start mode: Plugin loads and enables on startup"
            print_info "Press \\c or :Hello immediately"
            ;;
        2)
            print_info "Manual mode: Use :vimds to load, then :Vimds to toggle"
            print_info "  :vimds  - Load plugin and enable"
            print_info "  :Vimds  - Toggle on/off"
            ;;
        3)
            print_info "Lazy mode: Use :vimds to load and enable"
            print_info "  :vimds  - Load plugin and enable"
            print_info "  :Vimds  - Toggle on/off"
            ;;
    esac
}

uninstall_plugin() {
    print_header "Uninstalling vimds Plugin from Neovim"
    
    if [ ! -d "$PLUGIN_PATH" ]; then
        print_error "Plugin not installed!"
        echo ""
        check_status
        return
    fi
    
    print_info "Removing plugin directory..."
    rm -rf "$PLUGIN_PATH"
    print_status "Removed plugin directory"
    
    if [ -f "$LAZY_PLUGIN_PATH/vimds.lua" ]; then
        print_info "Removing Lazy.nvim config..."
        rm -f "$LAZY_PLUGIN_PATH/vimds.lua"
        print_status "Removed Lazy.nvim config"
    fi
    
    if [ -f "$NVIM_CONFIG/init.lua" ]; then
        print_info "Removing from init.lua..."
        sed -i.bak '/vimds/d' "$NVIM_CONFIG/init.lua"
        sed -i.bak '/require("vimds")/d' "$NVIM_CONFIG/init.lua"
        rm -f "$NVIM_CONFIG/init.lua.bak"
        print_status "Removed from init.lua"
    fi
    
    echo ""
    print_status "vimds plugin uninstalled successfully!"
    echo ""
    check_status
}

show_status() {
    print_header "vimds Plugin Status (Neovim)"
    check_status
    
    if [ -d "$PLUGIN_PATH" ]; then
        echo ""
        print_info "Commands:"
        print_info "  :vimds         - Load the plugin"
        print_info "  :Vimds         - Toggle on/off"
        print_info "  :VimdsStatus   - Show current status"
        echo ""
        print_info "Keymaps (when enabled):"
        print_info "  \\c            - Print Hello World"
        print_info "  <leader>c     - Print Hello World"
        echo ""
        print_info "To update: ./helper.sh update"
        print_info "To uninstall: ./helper.sh uninstall"
    fi
}

show_help() {
    echo "vimds Plugin Manager for Neovim"
    echo ""
    echo "Usage: ./helper.sh [COMMAND]"
    echo ""
    echo "Commands:"
    echo "  install     Install vimds plugin"
    echo "  update      Update plugin files only (no config changes)"
    echo "  uninstall   Uninstall vimds plugin from Neovim"
    echo "  status      Show current installation status"
    echo "  help        Show this help message"
    echo ""
    echo "Directory Structure:"
    echo "  ./scripts/helper.sh    <-- This script"
    echo "  ../plugin/             <-- Your plugin source (same level as scripts/)"
    echo "  ../plugin/init.lua     <-- Main plugin file"
    echo ""
    echo "Installation Path:"
    echo "  ${NVIM_CONFIG}/lua/vimds/"
    echo ""
    echo "Usage in Neovim:"
    echo "  :vimds         - Load the plugin"
    echo "  :Vimds         - Toggle on/off"
    echo "  :VimdsStatus   - Show current status"
    echo "  \\c            - Print Hello World (when enabled)"
    echo ""
    echo "Examples:"
    echo "  ./helper.sh install    # Install with mode selection"
    echo "  ./helper.sh update     # Update plugin files only"
    echo "  ./helper.sh status     # Check status"
}

# ============================================
# Documentation Generator
# ============================================
generate_docs() {
    print_header "Generating vimds Documentation"
    
    # Set docs directory one level above scripts (same level as plugin/)
    DOCS_DIR="$(dirname "$SCRIPT_DIR")/docs"
    mkdir -p "$DOCS_DIR"
    
    # Generate README.md at the root level
    cat > "$(dirname "$SCRIPT_DIR")/README.md" << 'EOF'
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

MIT License
EOF

    print_status "README.md generated"

    # Generate INSTALL.md
    cat > "$DOCS_DIR/INSTALL.md" << 'EOF'
# Installation Guide

## Prerequisites

- Neovim 0.5.0 or higher
- Git (optional)
- Python 3 (for API server)
- OpenRouter API key (for DeepSeek agent)

## Quick Install

### Method 1: Using the Helper Script

cd scripts
./helper.sh install

### Method 2: Manual Installation

cp -r plugin ~/.config/nvim/lua/vimds
echo 'require("vimds")' >> ~/.config/nvim/init.lua

### Method 3: Using Lazy.nvim

Add to ~/.config/nvim/lua/plugins/vimds.lua:

return {
  "vimds",
  lazy = true,
  cmd = "LoadVimds",
  config = function()
    require("vimds")
  end,
}

## DeepSeek Setup

1. Get API key from https://openrouter.ai/keys
2. Save to ~/.config/openrouter.token:

echo "sk-or-v1-your-key-here" > ~/.config/openrouter.token
chmod 600 ~/.config/openrouter.token

## Post-Installation

1. Restart Neovim
2. :LoadVimds
3. :Vimds
4. :Chat
5. :ChatSend Hello

## Troubleshooting

### Plugin not loading

ls ~/.config/nvim/lua/vimds/
cat ~/.config/nvim/init.lua | grep vimds

### DeepSeek not working

cat ~/.config/openrouter.token
:DeepSeekReload

### Check logs

:AgentLog

## Uninstall

cd scripts
./helper.sh uninstall
EOF

    print_status "INSTALL.md generated"

    # Generate CONFIG.md
    cat > "$DOCS_DIR/CONFIG.md" << 'EOF'
# Configuration Guide

All configuration is in ~/.config/nvim/lua/vimds/config.lua

## Agent Configuration

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

## Logging Settings

M.logging = {
  enabled = true,
  level = "info",
  file = os.getenv("HOME") .. "/.vimds_agent.log",
}

## General Settings

M.general = {
  auto_enable = true,
  show_welcome = true,
  debug = false,
}

## Keymaps

M.keys = {
  chat = "<leader>c",
  file = "<leader>f",
  close_output = "q",
}

## Output Settings

M.output = {
  split = "new",
  filetype = "markdown",
  title_prefix = "vimds",
  auto_close = true,
  width = 80,
  height = 20,
}

## Environment Variables

| Variable | Description |
|----------|-------------|
| OPENAI_API_KEY | OpenAI API key |
| WEBHOOK_URL | Webhook endpoint URL |
| CUSTOM_API_URL | Custom API URL |

## Examples

### Use OpenAI

M.agent = {
  default = "openai",
  providers = {
    openai = {
      api_key = "sk-...",
      model = "gpt-4",
    },
  },
}

### Use Webhook

M.agent = {
  default = "webhook",
  providers = {
    webhook = {
      url = "https://my-service.com/chat",
      method = "POST",
    },
  },
}
EOF

    print_status "CONFIG.md generated"

    # Generate API.md
    cat > "$DOCS_DIR/API.md" << 'EOF'
# API Documentation

## Agent Interface

function agent.call(payload)
  -- Input: { message = string, context = table, timestamp = string }
  -- Output: { success = bool, response = string, provider = string }
end

function agent.help()
  -- Output: { name = string, description = string, config = table }
end

## HTTP API

### GET /hello

curl http://localhost:8080/hello

Response: {"message": "Hello from vimds!"}

### POST /hello

curl -X POST -H "Content-Type: application/json" \
  -d '{"name":"World"}' \
  http://localhost:8080/hello

Response: {"message": "Hello World"}

## Socket API

### hello command

echo "hello" | socat - UNIX-CONNECT:/tmp/vimds.sock

### status command

echo "status" | socat - UNIX-CONNECT:/tmp/vimds.sock

## Neovim API

require("vimds")              -- Load plugin
require("vimds").setup()      -- Initialize
require("vimds").enable()     -- Enable
require("vimds").disable()    -- Disable
require("vimds").toggle()     -- Toggle
require("vimds").status()     -- Show status

## Agent Manager

local manager = require("vimds.agents")
manager.register("name", agent)
manager.set_default("name")
manager.get_default()
manager.list()
manager.call("name", message)
manager.call_default(message)

## Logger

local logger = require("vimds.utils.logger")
logger.debug("msg", data)
logger.info("msg", data)
logger.warn("msg", data)
logger.error("msg", data)
EOF

    print_status "API.md generated"

    # Generate CHANGELOG.md
    cat > "$DOCS_DIR/CHANGELOG.md" << 'EOF'
# Changelog

## [1.0.0] - 2026-09-02

### Added
- Initial release
- Agent-based architecture
- DeepSeek AI integration
- OpenAI GPT integration
- Webhook support
- Custom API support
- Chat interface
- File and visual selection
- Activity logging
- HTTP API server
- Socket server
- Configuration system

### Commands
- :Chat, :ChatSend, :ChatClear, :ChatHistory
- :AgentList, :AgentSwitch, :AgentStatus
- :AgentLog, :AgentLogClear, :AgentLogStatus
- :DeepSeekReload, :DeepSeekModel, :DeepSeekClear

## [0.9.0] - 2026-08-15

### Added
- Basic plugin structure
- Dummy chat agent
- Split window output
- Keymaps
EOF

    print_status "CHANGELOG.md generated"

    # Summary
    echo ""
    print_header "Documentation Generated"
    echo ""
    echo " README.md        - $(dirname "$SCRIPT_DIR")/README.md"
    echo " INSTALL.md      - $DOCS_DIR/INSTALL.md"
    echo " CONFIG.md       - $DOCS_DIR/CONFIG.md"
    echo " API.md          - $DOCS_DIR/API.md"
    echo " CHANGELOG.md    - $DOCS_DIR/CHANGELOG.md"
    echo ""
    print_status "All documentation generated successfully!"
    
    log_activity "Generated documentation"
}


# ============================================
# Main script
# ============================================
case "$1" in
    install)
        install_plugin
        ;;
    update)
        update_plugin
        ;;
    uninstall)
        uninstall_plugin
        ;;
    docs)
        generate_docs
        ;;
    status)
        show_status
        ;;
    help|--help|-h)
        show_help
        ;;
    *)
        if [ -z "$1" ]; then
            show_status
        else
            print_error "Unknown command: $1"
            echo ""
            show_help
            exit 1
        fi
        ;;
esac
