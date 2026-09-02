-- plugin/init.lua
local M = {}

-- Load config
local config = require("vimds.config")

-- Import modules
local output_handler = require("vimds.handlers.output")
local buffer_manager = require("vimds.utils.buffer_manager")
local agent_manager = require("vimds.agents")

-- State
local is_active = false
local is_loaded = false

-- ============================================
-- Load agents
-- ============================================
local function load_agents()
  local chat = require("vimds.agents.chat")
  agent_manager.register("chat", chat)
  print(string.format("Agents loaded: %s", table.concat(agent_manager.list(), ", ")))
end

-- ============================================
-- Helper Functions
-- ============================================

-- Get visual selection
function M.get_visual_selection()
  local start_pos = vim.fn.getpos("'<")
  local end_pos = vim.fn.getpos("'>")
  
  -- Get lines from buffer
  local lines = vim.api.nvim_buf_get_lines(0, start_pos[2] - 1, end_pos[2], false)
  
  -- Handle single line
  if #lines == 1 then
    return lines[1]:sub(start_pos[3], end_pos[3])
  end
  
  -- Handle multi-line
  local result = {}
  for i, line in ipairs(lines) do
    if i == 1 then
      table.insert(result, line:sub(start_pos[3]))
    elseif i == #lines then
      table.insert(result, line:sub(1, end_pos[3]))
    else
      table.insert(result, line)
    end
  end
  
  return table.concat(result, "\n")
end

-- Get file path from user
function M.select_file()
  -- Use telescope if available
  local has_telescope, telescope = pcall(require, "telescope")
  if has_telescope then
    telescope.builtin.find_files({
      attach_mappings = function(prompt_bufnr)
        local actions = require("telescope.actions")
        return function(prompt_bufnr)
          local selection = actions.get_selected_entry(prompt_bufnr)
          if selection then
            local file_path = selection.value
            M.process_file(file_path)
          end
        end
      end
    })
    return
  end
  
  -- Fallback to vim.ui.select
  vim.ui.select({ "Use Telescope or vim.ui.select" }, {
    prompt = "Select a file:",
  }, function(choice)
    if choice then
      vim.fn.input("File path: ", function(input)
        M.process_file(input)
      end)
    end
  end)
end

-- Process selected file
function M.process_file(file_path)
  if not file_path or file_path == "" then
    buffer_manager.add_system_message("No file selected")
    return
  end
  
  -- Get file info
  local file_name = vim.fn.fnamemodify(file_path, ":t")
  local file_dir = vim.fn.fnamemodify(file_path, ":h")
  local file_ext = vim.fn.fnamemodify(file_path, ":e")
  local file_size = vim.fn.getfsize(file_path)
  
  local message = string.format(
    "File: %s\nPath: %s\nExtension: %s\nSize: %d bytes",
    file_name, file_dir, file_ext, file_size
  )
  
  -- Add to chat
  buffer_manager.add_user_message("📎 File attached: " .. file_name)
  buffer_manager.add_user_message(message)
  
  -- Send to agent
  M.chat_send("I'm attaching a file: " .. file_name .. "\n\n" .. message)
end

-- ============================================
-- Chat Functions
-- ============================================
function M.open_chat()
  if not buffer_manager then
    print("Error: buffer_manager not loaded")
    return
  end
  
  buffer_manager.open_chat()
  
  local buf = buffer_manager.get_chat_buffer()
  if buf and vim.api.nvim_buf_is_valid(buf) then
    local lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
    if #lines <= 1 then
      buffer_manager.add_system_message("Welcome to vimds chat! 💬")
      buffer_manager.add_system_message("Commands: :ChatSend <msg> | :ChatClear | :ChatHistory")
      buffer_manager.add_system_message("Keymaps: \\c (chat) | \\f (file) | \\v (visual selection)")
    end
  end
end

function M.chat_send(message)
  if not message or message == "" then
    vim.cmd('echo "Please provide a message: :ChatSend <message>"')
    return
  end
  
  if not buffer_manager then
    print("Error: buffer_manager not loaded")
    return
  end
  
  buffer_manager.add_user_message(message)
  buffer_manager.show_typing()
  
  vim.defer_fn(function()
    buffer_manager.remove_typing()
    
    local result, err = agent_manager.call("chat", message)
    
    if result and result.success then
      buffer_manager.add_assistant_message(result.response)
    else
      buffer_manager.add_system_message("Error: " .. (err or "Unknown error"))
    end
  end, 500)
end

function M.chat_clear()
  if not buffer_manager then
    print("Error: buffer_manager not loaded")
    return
  end
  buffer_manager.clear_chat()
end

function M.chat_history()
  local chat_agent = agent_manager.get("chat")
  if not chat_agent then
    print("Chat agent not loaded")
    return
  end
  
  local history = chat_agent.get_history()
  local output = "# Chat History\n\n"
  
  if #history == 0 then
    output = output .. "No messages yet.\n"
  else
    for _, msg in ipairs(history) do
      local role = msg.role == "user" and "👤 User" or "🤖 Assistant"
      output = output .. string.format("**%s** (%s):\n%s\n\n", role, msg.timestamp, msg.content)
    end
  end
  
  if output_handler and output_handler.display then
    output_handler.display(output, {
      title = "Chat History",
      split = "vnew",
    })
  else
    print("Error: output_handler not available")
  end
end

-- ============================================
-- Visual Selection Handler
-- ============================================
function M.send_visual_selection()
  local selection = M.get_visual_selection()
  
  if not selection or selection == "" then
    buffer_manager.add_system_message("No text selected")
    return
  end
  
  -- Open chat if not already open
  M.open_chat()
  
  -- Send selection as message
  local message = "Visual selection:\n```\n" .. selection .. "\n```"
  M.chat_send("I selected this text:\n\n" .. selection)
end

-- ============================================
-- Setup
-- ============================================
function M.setup()
  if is_loaded then
    return
  end
  
  load_agents()
  
  -- Commands
  vim.api.nvim_create_user_command(config.advanced.toggle_command, function()
    M.toggle()
  end, { desc = "Toggle vimds on/off" })
  
  vim.api.nvim_create_user_command(config.advanced.status_command, function()
    M.status()
  end, { desc = "Show vimds status" })
  
  vim.api.nvim_create_user_command(config.advanced.help_command, function()
    if output_handler and output_handler.show_help then
      output_handler.show_help()
    end
  end, { desc = "Show vimds help" })
  
  vim.api.nvim_create_user_command('VimdsClear', function()
    if output_handler and output_handler.clear then
      output_handler.clear()
    end
  end, { desc = "Clear vimds output" })
  
  vim.api.nvim_create_user_command('VimdsClose', function()
    if output_handler and output_handler.close then
      output_handler.close()
    end
  end, { desc = "Close vimds output" })
  
  -- Chat commands
  vim.api.nvim_create_user_command('Chat', function()
    M.open_chat()
  end, { desc = "Open chat buffer" })
  
  vim.api.nvim_create_user_command('ChatSend', function(opts)
    M.chat_send(opts.args)
  end, { desc = "Send message to chat", nargs = "*" })
  
  vim.api.nvim_create_user_command('ChatClear', function()
    M.chat_clear()
  end, { desc = "Clear chat buffer" })
  
  vim.api.nvim_create_user_command('ChatHistory', function()
    M.chat_history()
  end, { desc = "Show chat history" })
  
  -- File and visual commands
  vim.api.nvim_create_user_command('File', function()
    M.select_file()
  end, { desc = "Select and send file to agent" })
  
  vim.api.nvim_create_user_command('SendVisual', function()
    M.send_visual_selection()
  end, { desc = "Send visual selection to agent" })
  
  -- Keymaps
  vim.api.nvim_set_keymap('n', config.keys.chat, '<cmd>Chat<CR>', { noremap = true, silent = true })
  vim.api.nvim_set_keymap('n', config.keys.file, '<cmd>File<CR>', { noremap = true, silent = true })
  vim.api.nvim_set_keymap('v', config.keys.visual, ':<C-U>SendVisual<CR>', { noremap = true, silent = true })
  
  is_loaded = true
  
  if config.general.show_welcome then
    print("vimds: Loaded! Use :Chat, \\f (file), \\v (visual)")
  end
end

-- ============================================
-- Enable/Disable/Toggle
-- ============================================
function M.enable()
  if is_active then
    print("vimds already enabled")
    return
  end
  
  is_active = true
  
  if config.general.show_welcome then
    print("vimds ENABLED! Try: :Chat, \\f, \\v")
  end
end

function M.disable()
  if not is_active then
    print("vimds already disabled")
    return
  end
  
  is_active = false
  print("vimds DISABLED! Use :Vimds to re-enable")
end

function M.toggle()
  if not is_loaded then
    M.setup()
  end
  
  if is_active then
    M.disable()
  else
    M.enable()
  end
end

-- ============================================
-- Status
-- ============================================
function M.status()
  if not is_loaded then
    print("vimds: NOT LOADED - Use :LoadVimds to load")
    return
  end
  
  local chat_agent = agent_manager.get("chat")
  local history_count = chat_agent and #chat_agent.get_history() or 0
  
  local status_text = string.format([[
# vimds Status

## Plugin Status
- Loaded: Yes
- Active: %s

## Keymaps
- Chat: %s
- File: %s
- Visual: %s

## Chat
- History: %d messages

## Commands
- :Chat - Open chat
- :ChatSend <msg> - Send message
- :File - Select and send file
- :SendVisual - Send visual selection
- :ChatClear - Clear chat
- :ChatHistory - Show history
]],
    is_active and "Yes" or "No",
    config.keys.chat or "\\c",
    config.keys.file or "\\f",
    config.keys.visual or "\\v",
    history_count
  )
  
  if output_handler and output_handler.display then
    output_handler.display(status_text, {
      title = "vimds Status",
      split = "new",
    })
  else
    print(status_text)
  end
end

-- ============================================
-- Load Mode
-- ============================================
function M.auto_start()
  M.setup()
  M.enable()
end

function M.manual_load()
  if is_loaded then
    print("vimds already loaded")
    return
  end
  
  M.setup()
  if config.general.auto_enable then
    M.enable()
  end
  print("vimds: Loaded! Use :Chat to start chatting")
end

function M.lazy_load()
  if is_loaded then
    return
  end
  
  vim.api.nvim_create_user_command(config.advanced.load_command, function()
    if not is_loaded then
      M.manual_load()
      if config.general.auto_enable then
        M.enable()
      end
    else
      M.toggle()
    end
  end, { desc = "Load and toggle vimds" })
  
  vim.api.nvim_echo({
    { "vimds: Lazy mode - Use :", "Normal" },
    { config.advanced.load_command, "Special" },
    { " to load", "Normal" }
  }, false, {})
end

-- ============================================
-- Initialize
-- ============================================
if config.advanced.lazy_load then
  M.lazy_load()
else
  M.auto_start()
end

return M

