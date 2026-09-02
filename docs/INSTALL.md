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
