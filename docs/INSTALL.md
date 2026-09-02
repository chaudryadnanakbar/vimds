# Installation Guide

## Prerequisites

- Neovim 0.5.0 or higher
- Git (optional, for cloning)
- Python 3 (for API server)

## Quick Install

### Method 1: Using the Helper Script (Recommended)

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
    require("vimds").setup()
  end,
}

## Post-Installation

1. Restart Neovim
2. Load the plugin: :LoadVimds
3. Toggle on: :Vimds
4. Test: \c

## Troubleshooting

### Plugin not loading

ls ~/.config/nvim/lua/vimds/
cat ~/.config/nvim/init.lua | grep vimds

### Keymaps not working

:VimdsStatus
:Vimds

### API server not starting

python3 --version
netstat -tulpn | grep 8080

## Uninstall

cd scripts
./helper.sh uninstall
