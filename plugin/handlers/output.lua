-- plugin/handlers/output.lua
local buffer_manager = require("vimds.utils.buffer_manager")

local M = {}

function M.display(content, opts)
    return buffer_manager.display(content, opts)
end

function M.show_status(status_info)
    return buffer_manager.show_status(status_info)
end

function M.clear()
    buffer_manager.clear_output()
end

function M.close()
    buffer_manager.close_all()
end

function M.show_help()
    local help_content = [[
# 📚 vimds Help

## Commands

| Command | Description |
|---------|-------------|
| `:LoadVimds` | Load the plugin |
| `:Vimds` | Toggle plugin on/off |
| `:VimdsStatus` | Show plugin status |
| `:VimdsHelp` | Show this help |
| `:VimdsClear` | Clear output |
| `:VimdsClose` | Close output |
| `:Hello` | Say hello |
| `:Chat` | Open chat buffer |
| `:ChatSend <msg>` | Send message to chat |
| `:ChatClear` | Clear chat |

## Keymaps

| Key | Description |
|-----|-------------|
| `\c` | Say hello |
| `<leader>c` | Say hello (alternative) |

## Usage

1. **Load**: `:LoadVimds`
2. **Enable**: `:Vimds` (toggles on/off)
3. **Test**: `\c` or `:Hello`
4. **Status**: `:VimdsStatus`
5. **Chat**: `:Chat`

## Configuration

Edit `~/.config/nvim/lua/vimds/config.lua`

---
_Press `q` or `<ESC>` to close this buffer_
    ]]
    
    buffer_manager.display(help_content, {
        title = "vimds Help",
        split = "botright",
        size = 20,
    })
end

return M
