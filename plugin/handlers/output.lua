-- ../plugin/handlers/output.lua
local M = {}
local config = require("vimds.config")
local buffer_utils = require("vimds.utils.buffer")

-- State
local output_buffer = nil
local output_window = nil

-- Display output in split window
function M.display(output, opts)
  opts = opts or {}
  
  -- Close existing output window if open
  if output_window and vim.api.nvim_win_is_valid(output_window) then
    vim.api.nvim_win_close(output_window, true)
  end
  
  -- Create split
  local split = opts.split or config.output.split
  local title = opts.title or config.output.title_prefix .. " Output"
  local filetype = opts.filetype or config.output.filetype
  
  -- Store window and buffer
  output_window = vim.api.nvim_get_current_win()
  output_buffer = buffer_utils.create_split(output, {
    title = title,
    filetype = filetype,
    split = split,
  })
  
  return output_buffer
end

-- Append to existing output
function M.append(content)
  if not output_buffer or not vim.api.nvim_buf_is_valid(output_buffer) then
    M.display(content, { title = config.output.title_prefix .. " Output", split = config.output.split })
    return
  end
  
  buffer_utils.append_to_buffer(output_buffer, content)
end

-- Clear output
function M.clear()
  if output_buffer and vim.api.nvim_buf_is_valid(output_buffer) then
    buffer_utils.clear_buffer(output_buffer)
  end
end

-- Close output
function M.close()
  if output_window and vim.api.nvim_win_is_valid(output_window) then
    vim.api.nvim_win_close(output_window, true)
  end
  output_buffer = nil
  output_window = nil
end

-- Toggle output
function M.toggle(content, opts)
  if output_window and vim.api.nvim_win_is_valid(output_window) then
    M.close()
  else
    M.display(content, opts)
  end
end

-- Show help in split
function M.show_help()
  local help_text = string.format([[
# vimds Help

## Commands
- `:%s` - Load plugin
- `:%s` - Toggle plugin on/off
- `:%s` - Show status
- `:%s` - Show this help
- `:Hello` - Print hello
- `:Agent` - Call external agent (if enabled)

## Keymaps
- `%s` or `%s` - Print hello
- `%s` - Close output window

## External Integration
- HTTP API: %s
- Socket: %s

## Usage
1. Load plugin: `:%s`
2. Enable: `:%s`
3. Test: `%s`
]],
    config.advanced.load_command,
    config.advanced.toggle_command,
    config.advanced.status_command,
    config.advanced.help_command,
    config.keys.hello or "\\c",
    config.keys.hello_alt or "<leader>c",
    config.keys.close_output or "q",
    config.api.enabled and ("http://" .. config.api.host .. ":" .. config.api.port) or "Disabled",
    config.socket.enabled and config.socket.path or "Disabled",
    config.advanced.load_command,
    config.advanced.toggle_command,
    config.keys.hello or "\\c"
  )
  
  M.display(help_text, {
    title = config.output.title_prefix .. " Help",
    filetype = "markdown",
    split = config.output.split,
  })
end

-- Show status in split
function M.show_status(status_info)
  local status_text = string.format([[
# vimds Status

## Plugin Status
- Loaded: %s
- Active: %s

## Keymaps
- Primary: %s
- Alternative: %s

## Commands
- :%s - Toggle on/off
- :Hello - Print hello
- :%s - Show help

## External APIs
- HTTP: %s
- Socket: %s

## Configuration
- Config file: ~/.config/nvim/lua/vimds/config.lua
- To modify: Edit config.lua and restart Neovim
]],
    status_info.loaded or "No",
    status_info.active or "No",
    status_info.primary_key or "\\c",
    status_info.alt_key or "<leader>c",
    config.advanced.toggle_command,
    config.advanced.help_command,
    status_info.http_url or "Disabled",
    status_info.socket_path or "Disabled"
  )
  
  M.display(status_text, {
    title = config.output.title_prefix .. " Status",
    filetype = "markdown",
    split = config.output.split,
  })
end

return M
