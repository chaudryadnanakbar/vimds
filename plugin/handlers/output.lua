-- plugin/handlers/output.lua
local M = {}
local config = require("vimds.config")
local buffer_utils = require("vimds.utils.buffer")

local output_buffer = nil
local output_window = nil

-- Display output in split window
function M.display(content, opts)
  opts = opts or {}
  
  -- Close existing output window if open
  if output_window and vim.api.nvim_win_is_valid(output_window) then
    vim.api.nvim_win_close(output_window, true)
  end
  
  local split = opts.split or config.output.split or "new"
  local title = opts.title or config.output.title_prefix .. " Output"
  local filetype = opts.filetype or config.output.filetype or "markdown"
  
  -- Create new split
  vim.cmd(split)
  
  -- Set window size
  if split == "vnew" and config.output.width then
    vim.api.nvim_win_set_width(0, config.output.width)
  elseif split == "new" and config.output.height then
    vim.api.nvim_win_set_height(0, config.output.height)
  end
  
  local buf = vim.api.nvim_get_current_buf()
  
  -- Set buffer options
  vim.bo[buf].buftype = "nofile"
  vim.bo[buf].bufhidden = "wipe"
  vim.bo[buf].swapfile = false
  vim.bo[buf].filetype = filetype
  vim.bo[buf].modifiable = true
  
  -- Set window options
  vim.wo.wrap = true
  vim.wo.number = false
  vim.wo.relativenumber = false
  vim.wo.signcolumn = "no"
  
  -- Set content
  local lines = vim.split(content, "\n")
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
  vim.api.nvim_buf_set_name(buf, title)
  
  -- Make buffer non-modifiable
  vim.bo[buf].modifiable = false
  
  -- Keymap to close
  local close_key = config.keys.close_output or "q"
  vim.keymap.set('n', close_key, function()
    vim.api.nvim_win_close(0, true)
  end, { buffer = buf, desc = "Close output" })
  
  output_window = vim.api.nvim_get_current_win()
  output_buffer = buf
  
  return buf
end

-- Append to existing output
function M.append(content)
  if not output_buffer or not vim.api.nvim_buf_is_valid(output_buffer) then
    M.display(content, { title = config.output.title_prefix .. " Output" })
    return
  end
  
  vim.bo[output_buffer].modifiable = true
  local lines = vim.split(content, "\n")
  vim.api.nvim_buf_set_lines(output_buffer, -1, -1, false, lines)
  vim.bo[output_buffer].modifiable = false
end

-- Clear output
function M.clear()
  if output_buffer and vim.api.nvim_buf_is_valid(output_buffer) then
    vim.bo[output_buffer].modifiable = true
    vim.api.nvim_buf_set_lines(output_buffer, 0, -1, false, {})
    vim.bo[output_buffer].modifiable = false
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

-- Show help
function M.show_help()
  local help_text = [[
# vimds Help

## Commands
- :Chat - Open chat buffer
- :ChatSend <msg> - Send message
- :ChatClear - Clear chat
- :ChatHistory - Show history
- :File - Select and send file
- :SendVisual - Send visual selection
- :Vimds - Toggle on/off
- :VimdsStatus - Show status

## Keymaps
- \c or <leader>c - Open chat
- \f or <leader>f - Select and send file
- \v or <leader>v - Send visual selection
- q - Close window
- Enter - Send line in chat
- c - Clear chat

## Usage Examples
1. Select text with visual mode, press \v
2. Press \f to select a file
3. Type :Chat to start chatting
]]
  
  M.display(help_text, {
    title = "vimds Help",
    filetype = "markdown",
    split = "vnew",
  })
end

-- Show status
function M.show_status(status_info)
  local status_text = string.format([[
# vimds Status

## Plugin Status
- Loaded: %s
- Active: %s

## Keymaps
- Chat: %s
- File: %s
- Visual: %s
- Close: %s

## Commands
- :Chat - Open chat
- :ChatSend <msg> - Send message
- :File - Select and send file
- :SendVisual - Send visual selection
]],
    status_info.loaded or "No",
    status_info.active or "No",
    status_info.chat_key or "\\c",
    status_info.file_key or "\\f",
    status_info.visual_key or "\\v",
    status_info.close_key or "q"
  )
  
  M.display(status_text, {
    title = "vimds Status",
    filetype = "markdown",
    split = "new",
  })
end

return M

