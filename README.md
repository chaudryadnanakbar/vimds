# vimds - Neovim Plugin

A modular Neovim plugin with external API support, socket integration, and beautiful output windows.

## Features

- Lazy Loading - Loads only when you need it
- Toggle On/Off - Enable/disable with a single command
- Split Window Output - Beautiful markdown output in split windows
- HTTP API Server - Interact with external agents via REST API
- Socket Server - Unix domain socket for fast IPC
- Easy Configuration - All settings in one config file
- Activity Logging - Track all plugin activities
- Modular Design - Easy to extend and customize

## Installation

### Using the Helper Script (Recommended)

cd scripts
./helper.sh install

### Manual Installation

cp -r plugin ~/.config/nvim/lua/vimds
echo 'require("vimds")' >> ~/.config/nvim/init.lua

## Quick Start

1. Load the plugin: :LoadVimds
2. Toggle on/off: :Vimds
3. Show hello: \c or :Hello
4. Get help: :VimdsHelp
5. Check status: :VimdsStatus

## Commands

:LoadVimds     - Load the plugin
:Vimds         - Toggle plugin on/off
:VimdsStatus   - Show plugin status
:VimdsHelp     - Show help in split window
:VimdsClear    - Clear output window
:VimdsClose    - Close output window
:Hello         - Print hello message
:Agent         - Call external agent

## Keymaps

\c             - Print hello message
<leader>c      - Print hello message (alternative)
q              - Close output window

## Configuration

Edit ~/.config/nvim/lua/vimds/config.lua

## Helper Script Commands

./helper.sh install      - Install the plugin
./helper.sh update       - Update plugin files
./helper.sh uninstall    - Uninstall the plugin
./helper.sh status       - Show plugin status
./helper.sh docs         - Generate documentation
./helper.sh logs         - Show logs
./helper.sh clear-logs   - Clear logs
./helper.sh help         - Show help

## Directory Structure

./
├── scripts/
│   └── helper.sh        - Management script
├── plugin/              - Plugin source
├── docs/                - Generated documentation
└── README.md            - This file

## License

MIT License
