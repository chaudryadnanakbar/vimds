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
local saved_selection = nil
local saved_selection_context = nil

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

-- Expand file path (handle ~, environment variables, etc.)
function M.expand_path(path)
  if not path or path == "" then
    return path
  end
  
  -- Expand ~ to home directory
  if path:match("^~") then
    local home = os.getenv("HOME") or vim.fn.expand("$HOME")
    path = path:gsub("^~", home)
  end
  
  -- Expand environment variables
  path = path:gsub("%$([%w_]+)", function(var)
    return os.getenv(var) or "$" .. var
  end)
  
  -- Use vim.fn.expand for additional expansion
  path = vim.fn.expand(path)
  
  return path
end

-- Get visual selection
function M.get_visual_selection()
  local start_pos = vim.fn.getpos("'<")
  local end_pos = vim.fn.getpos("'>")
  
  if start_pos[2] == 0 or end_pos[2] == 0 then
    return nil
  end
  
  local lines = vim.api.nvim_buf_get_lines(0, start_pos[2] - 1, end_pos[2], false)
  
  if #lines == 0 then
    return nil
  end
  
  if #lines == 1 then
    return lines[1]:sub(start_pos[3], end_pos[3])
  end
  
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

-- Save visual selection
function M.save_visual_selection()
  saved_selection = M.get_visual_selection()
  if saved_selection then
    local file_name = vim.fn.expand("%:t")
    local file_type = vim.bo.filetype
    local line_count = vim.fn.line("'>") - vim.fn.line("'<") + 1
    
    saved_selection_context = {
      content = saved_selection,
      file = file_name,
      filetype = file_type,
      lines = line_count > 0 and line_count or 1,
    }
    return true
  end
  return false
end

-- Get visual selection with context
function M.get_visual_selection_context()
  local selection = M.get_visual_selection()
  if selection and selection ~= "" then
    local file_name = vim.fn.expand("%:t")
    local file_type = vim.bo.filetype
    local line_count = vim.fn.line("'>") - vim.fn.line("'<") + 1
    
    return {
      content = selection,
      file = file_name,
      filetype = file_type,
      lines = line_count > 0 and line_count or 1,
    }
  end
  
  if saved_selection and saved_selection_context then
    return saved_selection_context
  end
  
  return nil
end

function M.clear_saved_selection()
  saved_selection = nil
  saved_selection_context = nil
end

-- ============================================
-- File Input with Autocomplete
-- ============================================

-- Get file completion candidates
function M.get_file_completions(prefix, directory)
  directory = directory or vim.fn.getcwd()
  prefix = prefix or ""
  
  -- Expand prefix
  prefix = M.expand_path(prefix)
  
  local completions = {}
  
  -- If prefix is empty, show directories in current path
  local search_path = directory
  local search_prefix = prefix
  
  -- Check if prefix contains a path
  if prefix:match("/") then
    local last_slash = prefix:find("/[^/]*$")
    if last_slash then
      search_path = directory .. "/" .. prefix:sub(1, last_slash - 1)
      search_prefix = prefix:sub(last_slash + 1)
    end
  end
  
  -- Get files/directories matching prefix
  local cmd = string.format('ls -1 "%s" 2>/dev/null | grep "^%s"', search_path, search_prefix)
  local handle = io.popen(cmd)
  if not handle then
    return completions
  end
  
  for item in handle:lines() do
    local full_path = search_path .. "/" .. item
    local is_dir = vim.fn.isdirectory(full_path) == 1
    if not item:match("^%.") then
      local display = is_dir and item .. "/" or item
      table.insert(completions, {
        word = display,
        kind = is_dir and "directory" or "file",
        path = full_path,
      })
    end
  end
  handle:close()
  
  return completions
end

-- Select file with autocomplete
function M.select_file()
  local cwd = vim.fn.getcwd()
  
  vim.ui.input({
    prompt = "File path: ",
    default = "",
    completion = "file",
  }, function(input)
    if input and input ~= "" then
      -- Expand the path
      local expanded = M.expand_path(input)
      
      -- Check if it's a directory
      if vim.fn.isdirectory(expanded) == 1 then
        buffer_manager.add_system_message("📁 Directory: " .. expanded)
        buffer_manager.add_system_message("Please select a file using :File with the full path")
        return
      end
      
      if vim.fn.filereadable(expanded) == 1 then
        M.send_file_path(expanded)
      else
        buffer_manager.add_system_message("File not found: " .. input)
        buffer_manager.add_system_message("Expanded path: " .. expanded)
      end
    else
      buffer_manager.add_system_message("File selection cancelled")
    end
  end)
end

-- Send file path to chat
function M.send_file_path(file_path)
  if not file_path or file_path == "" then
    buffer_manager.add_system_message("No file selected")
    return
  end
  
  -- Expand path one more time to be safe
  local expanded = M.expand_path(file_path)
  
  local file_name = vim.fn.fnamemodify(expanded, ":t")
  local file_dir = vim.fn.fnamemodify(expanded, ":h")
  local file_ext = vim.fn.fnamemodify(expanded, ":e")
  local file_size = vim.fn.getfsize(expanded)
  
  local message = string.format(
    "📎 **File:** %s\n📁 **Path:** %s\n📄 **Extension:** %s\n📊 **Size:** %d bytes",
    file_name,
    expanded,
    file_ext ~= "" and file_ext or "unknown",
    file_size
  )
  
  M.open_chat()
  M.chat_send(message)
end

-- ============================================
-- Visual Selection Functions
-- ============================================

function M.send_visual_with_prompt()
  local context = M.get_visual_selection_context()
  
  if not context or not context.content then
    buffer_manager.add_system_message("No text selected. Select text first with 'v' then use :SendVisual")
    M.clear_saved_selection()
    return
  end
  
  local preview = context.content:sub(1, 200) .. (context.content:len() > 200 and "..." or "")
  vim.api.nvim_echo({
    { "Selected ", "Normal" },
    { preview, "Comment" },
    { " (" .. context.lines .. " lines, " .. context.file .. ")", "Normal" }
  }, false, {})
  
  vim.fn.inputsave()
  local message = vim.fn.input("Message with selection (optional): ")
  vim.fn.inputrestore()
  
  M.clear_saved_selection()
  M.open_chat()
  
  local full_message
  if message and message ~= "" then
    full_message = string.format(
      "**From %s (%d lines)**\n%s\n\n```%s\n%s\n```",
      context.file,
      context.lines,
      message,
      context.filetype,
      context.content
    )
  else
    full_message = string.format(
      "**From %s (%d lines)**\n\n```%s\n%s\n```",
      context.file,
      context.lines,
      context.filetype,
      context.content
    )
  end
  
  M.chat_send(full_message)
end

function M.send_visual_quick()
  local context = M.get_visual_selection_context()
  
  if not context or not context.content then
    buffer_manager.add_system_message("No text selected. Select text first with 'v' then use :SendVisualQuick")
    M.clear_saved_selection()
    return
  end
  
  M.clear_saved_selection()
  M.open_chat()
  M.chat_send(string.format(
    "**From %s (%d lines)**\n\n```%s\n%s\n```",
    context.file,
    context.lines,
    context.filetype,
    context.content
  ))
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
      buffer_manager.add_system_message("Commands: :ChatSend <msg> | :ChatClear | :ChatHistory | :File")
      buffer_manager.add_system_message("Keymaps: <leader>c (chat) | <leader>f (file) | <leader>v (visual)")
      buffer_manager.add_system_message("Tip: Use ~/ for home directory in file paths")
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
  end, { desc = "Select file with autocomplete" })
  
  vim.api.nvim_create_user_command('SendVisual', function()
    M.send_visual_with_prompt()
  end, { desc = "Send visual selection with prompt" })
  
  vim.api.nvim_create_user_command('SendVisualQuick', function()
    M.send_visual_quick()
  end, { desc = "Send visual selection without prompt" })
  
  -- Normal mode keymaps
  vim.api.nvim_set_keymap('n', config.keys.chat, '<cmd>Chat<CR>', { noremap = true, silent = true })
  vim.api.nvim_set_keymap('n', config.keys.file, '<cmd>File<CR>', { noremap = true, silent = true })
  
  -- Visual mode keymaps
  vim.api.nvim_set_keymap('v', '<leader>v', ':<C-U>SendVisual<CR>', { noremap = true, silent = true })
  vim.api.nvim_set_keymap('v', '<leader>V', ':<C-U>SendVisualQuick<CR>', { noremap = true, silent = true })
  vim.api.nvim_set_keymap('v', 'gv', ':<C-U>SendVisual<CR>', { noremap = true, silent = true })
  
  is_loaded = true
  
  if config.general.show_welcome then
    print("vimds: Loaded! Use :Chat, <leader>f (file), <leader>v (visual)")
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
    print("vimds ENABLED! Try: :Chat, <leader>f, <leader>v, gv")
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
- Chat (normal): %s
- File (normal): %s
- Visual (prompt): <leader>v or gv
- Visual (quick): <leader>V

## Chat
- History: %d messages

## Commands
- :Chat - Open chat
- :ChatSend <msg> - Send message
- :File - Select file with autocomplete
- :SendVisual - Send visual selection with prompt
- :SendVisualQuick - Send visual selection without prompt
]],
    is_active and "Yes" or "No",
    config.keys.chat or "<leader>c",
    config.keys.file or "<leader>f",
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
