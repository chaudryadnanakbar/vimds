-- plugin/utils/buffer_manager.lua
local M = {}

-- State
M.chat_buffer = nil
M.chat_window = nil

-- Create chat buffer
function M.create_chat_buffer()
  if M.chat_buffer and vim.api.nvim_buf_is_valid(M.chat_buffer) then
    return M.chat_buffer
  end
  
  M.chat_buffer = vim.api.nvim_create_buf(false, true)
  
  vim.bo[M.chat_buffer].buftype = "nofile"
  vim.bo[M.chat_buffer].bufhidden = "hide"
  vim.bo[M.chat_buffer].swapfile = false
  vim.bo[M.chat_buffer].filetype = "markdown"
  vim.bo[M.chat_buffer].modifiable = true
  
  vim.api.nvim_buf_set_name(M.chat_buffer, "vimds Chat")
  
  return M.chat_buffer
end

-- Open chat in split window
function M.open_chat()
  local buf = M.create_chat_buffer()
  
  for _, win in ipairs(vim.api.nvim_list_wins()) do
    if vim.api.nvim_win_get_buf(win) == buf then
      vim.api.nvim_set_current_win(win)
      return buf
    end
  end
  
  local config = require("vimds.config")
  local split_cmd = config.output.split or "new"
  vim.cmd(split_cmd)
  
  vim.api.nvim_win_set_buf(0, buf)
  
  vim.wo.wrap = true
  vim.wo.number = false
  vim.wo.relativenumber = false
  vim.wo.signcolumn = "no"
  vim.wo.statusline = " vimds Chat "
  
  if split_cmd == "vnew" and config.output.width then
    vim.api.nvim_win_set_width(0, config.output.width)
  elseif split_cmd == "new" and config.output.height then
    vim.api.nvim_win_set_height(0, config.output.height)
  end
  
  vim.keymap.set('n', 'q', function()
    vim.api.nvim_win_close(0, true)
  end, { buffer = buf, desc = "Close chat" })
  
  vim.keymap.set('n', '<CR>', function()
    local line = vim.api.nvim_get_current_line()
    if line and line ~= "" and not line:match("^---") then
      vim.cmd('ChatSend ' .. line)
    end
  end, { buffer = buf, desc = "Send line as message" })
  
  vim.keymap.set('n', 'c', function()
    vim.cmd('ChatClear')
  end, { buffer = buf, desc = "Clear chat" })
  
  M.chat_window = vim.api.nvim_get_current_win()
  
  -- Make sure buffer is modifiable
  vim.bo[buf].modifiable = true
  
  return buf
end

-- Make buffer modifiable helper
local function ensure_modifiable(buf)
  if not vim.bo[buf].modifiable then
    vim.bo[buf].modifiable = true
  end
  return buf
end

-- Format message - returns table of lines
function M.format_message(message, sender, timestamp)
  local sender_emoji = sender == "User" and "👤" or sender == "Assistant" and "🤖" or sender == "System" and "⚙️" or "💬"
  local time = timestamp or os.date("%H:%M:%S")
  
  local lines = {}
  
  if sender == "System" then
    table.insert(lines, string.format("**[%s] %s**", time, message))
  else
    table.insert(lines, string.format("**[%s] %s %s:**", time, sender_emoji, sender or "Unknown"))
    -- Split message by newlines and add each line
    for line in string.gmatch(message, "([^\n]*)\n?") do
      if line ~= "" then
        table.insert(lines, line)
      end
    end
  end
  
  return lines
end

-- Add message to chat buffer
function M.add_chat_message(message, sender, timestamp)
  local buf = M.create_chat_buffer()
  
  -- Ensure buffer is modifiable
  ensure_modifiable(buf)
  
  -- Get current lines
  local lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
  
  -- Remove last separator if exists
  if #lines > 0 and lines[#lines]:match("^---") then
    vim.api.nvim_buf_set_lines(buf, #lines - 1, -1, false, {})
    lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
  end
  
  -- Format message as table of lines
  local formatted_lines = M.format_message(message, sender, timestamp)
  
  -- Add empty line before message if not first
  if #lines > 0 then
    table.insert(formatted_lines, 1, "")
  end
  
  -- Append to buffer
  vim.api.nvim_buf_set_lines(buf, -1, -1, false, formatted_lines)
  
  -- Add separator at bottom
  vim.api.nvim_buf_set_lines(buf, -1, -1, false, {"---"})
  
  -- Scroll to bottom
  local last_line = vim.api.nvim_buf_line_count(buf)
  vim.api.nvim_win_set_cursor(0, {last_line, 0})
end

-- Shortcut functions
function M.add_user_message(message)
  M.add_chat_message(message, "User")
end

function M.add_assistant_message(message)
  M.add_chat_message(message, "Assistant")
end

function M.add_system_message(message)
  M.add_chat_message(message, "System")
end

-- Clear chat
function M.clear_chat()
  local buf = M.create_chat_buffer()
  ensure_modifiable(buf)
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, {})
  M.add_system_message("Chat cleared")
end

-- Get chat buffer
function M.get_chat_buffer()
  return M.chat_buffer
end

-- Show typing indicator
function M.show_typing()
  M.add_system_message("...thinking...")
end

-- Remove typing indicator
function M.remove_typing()
  local buf = M.create_chat_buffer()
  if not buf or not vim.api.nvim_buf_is_valid(buf) then
    return
  end
  
  ensure_modifiable(buf)
  local lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
  
  for i = #lines, 1, -1 do
    if lines[i] and lines[i]:match("...thinking...") then
      vim.api.nvim_buf_set_lines(buf, i - 1, i, false, {})
      if i > 1 and lines[i-1] and lines[i-1]:match("^---") then
        vim.api.nvim_buf_set_lines(buf, i - 2, i - 1, false, {})
      end
      break
    end
  end
end

return M

