-- plugin/init.lua
local M = {}

-- Load config
local config = require("vimds.config")

-- Import modules
local output_handler = require("vimds.handlers.output")
local buffer_manager = require("vimds.utils.buffer_manager")
local agent_manager = require("vimds.agents")
local logger = require("vimds.utils.logger")

-- State
local is_active = false
local is_loaded = false
local saved_selection = nil
local saved_selection_context = nil

-- ============================================
-- Load agents from config
-- ============================================
local function load_agents()
  local default_agent = config.agent.default or "chat"
  
  local available_agents = {
    "chat",
    "openai",
    "deepseek",
    "webhook",
    "custom",
  }
  
  for _, name in ipairs(available_agents) do
    local success, agent = pcall(require, "vimds.agents." .. name)
    if success then
      agent_manager.register(name, agent)
      
      if config.agent.providers and config.agent.providers[name] then
        if agent.apply_config then
          agent.apply_config(config.agent.providers[name])
        end
      end
    else
      logger.warn("Failed to load agent", { agent = name, error = tostring(agent) })
    end
  end
  
  if agent_manager.set_default(default_agent) then
    logger.info("Default agent set", { agent = default_agent })
  else
    logger.warn("Default agent not found, using first available", { agent = default_agent })
    local agents = agent_manager.list()
    if #agents > 0 then
      agent_manager.set_default(agents[1])
      logger.info("Using fallback agent", { agent = agents[1] })
    end
  end
  
  logger.info("Agents loaded", { agents = agent_manager.list() })
  print(string.format("Agents loaded: %s", table.concat(agent_manager.list(), ", ")))
  print(string.format("Default agent: %s", agent_manager.get_default() or "None"))
end

-- ============================================
-- Helper Functions
-- ============================================

function M.expand_path(path)
  if not path or path == "" then
    return path
  end
  
  if path:match("^~") then
    local home = os.getenv("HOME") or vim.fn.expand("$HOME")
    path = path:gsub("^~", home)
  end
  
  path = path:gsub("%$([%w_]+)", function(var)
    return os.getenv(var) or "$" .. var
  end)
  
  path = vim.fn.expand(path)
  return path
end

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
-- File Input
-- ============================================

function M.select_file()
  vim.ui.input({
    prompt = "File path: ",
    default = "",
    completion = "file",
  }, function(input)
    if input and input ~= "" then
      local expanded = M.expand_path(input)
      
      if vim.fn.isdirectory(expanded) == 1 then
        buffer_manager.add_system_message("📁 Directory: " .. expanded)
        return
      end
      
      if vim.fn.filereadable(expanded) == 1 then
        M.send_file_path(expanded)
      else
        buffer_manager.add_system_message("File not found: " .. input)
      end
    end
  end)
end

function M.send_file_path(file_path)
  if not file_path or file_path == "" then
    buffer_manager.add_system_message("No file selected")
    return
  end
  
  local expanded = M.expand_path(file_path)
  local file_name = vim.fn.fnamemodify(expanded, ":t")
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
    buffer_manager.add_system_message("No text selected")
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
    buffer_manager.add_system_message("No text selected")
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
      local agent_name = agent_manager.get_default() or "chat"
      buffer_manager.add_system_message("Welcome to vimds chat! 💬")
      buffer_manager.add_system_message("Using agent: " .. agent_name)
      buffer_manager.add_system_message("Commands: :ChatSend <msg> | :ChatClear | :ChatHistory")
      buffer_manager.add_system_message("Keymaps: <leader>c (chat) | <leader>f (file) | <leader>v (visual)")
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
    
    local result, err = agent_manager.call_default(message)
    
    if result and result.success then
      buffer_manager.add_assistant_message(result.response)
      
      if result.provider and result.provider ~= "chat" then
        buffer_manager.add_system_message("_Provider: " .. result.provider .. "_")
      end
      
      if result.model and result.model ~= "dummy" then
        buffer_manager.add_system_message("_Model: " .. result.model .. "_")
      end
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
  local default_agent = agent_manager.get_default()
  if not default_agent then
    buffer_manager.add_system_message("No default agent set")
    return
  end
  
  -- Use agent_manager.get() to get the agent
  local agent = agent_manager.get(default_agent)
  if not agent then
    buffer_manager.add_system_message("Agent not found: " .. default_agent)
    return
  end
  
  if not agent.get_history then
    buffer_manager.add_system_message("Agent doesn't support history: " .. default_agent)
    return
  end
  
  local history = agent.get_history()
  local output = "# Chat History\n\n"
  
  if not history or #history == 0 then
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
    print(output)
  end
end

-- ============================================
-- Agent Management Commands
-- ============================================

function M.list_agents()
  local agents = agent_manager.list()
  local default = agent_manager.get_default()
  
  local output = "# Available Agents\n\n"
  for _, name in ipairs(agents) do
    local marker = (name == default) and "⭐ " or "  "
    local help = agent_manager.get_help(name)
    if help then
      local config_str = ""
      if help.config then
        config_str = "\n"
        for k, v in pairs(help.config) do
          config_str = config_str .. string.format("  - %s: %s\n", k, tostring(v))
        end
      end
      output = output .. string.format("%s**%s** - %s%s\n\n", marker, name, help.description or "No description", config_str)
    else
      output = output .. string.format("%s**%s**\n\n", marker, name)
    end
  end
  
  output = output .. "\n**Default Agent:** " .. default .. "\n"
  output = output .. "\n**Commands:**\n"
  output = output .. "- `:AgentSwitch <name>` - Change default agent\n"
  output = output .. "- `:AgentStatus` - Show current agent status\n"
  output = output .. "- Edit `config.lua` to change default permanently\n"
  
  if output_handler and output_handler.display then
    output_handler.display(output, {
      title = "Agents",
      split = "vnew",
    })
  else
    print(output)
  end
end

function M.switch_agent(name)
  if not name or name == "" then
    buffer_manager.add_system_message("Usage: :AgentSwitch <agent_name>")
    return
  end
  
  if agent_manager.set_default(name) then
    buffer_manager.add_system_message("Switched to agent: " .. name)
    buffer_manager.add_system_message("Use :ChatSend to send messages")
  else
    buffer_manager.add_system_message("Agent not found: " .. name)
    buffer_manager.add_system_message("Available: " .. table.concat(agent_manager.list(), ", "))
  end
end

function M.agent_status()
  local default = agent_manager.get_default()
  if not default then
    buffer_manager.add_system_message("No default agent set")
    return
  end
  
  local agent = agent_manager.get(default)
  if not agent then
    buffer_manager.add_system_message("Agent not found: " .. default)
    return
  end
  
  local help = agent.help and agent.help() or { description = "No description" }
  local status_text = string.format([[
# Agent Status

## Current Agent
- Name: %s
- Description: %s

## Configuration
]],
    default,
    help.description or "No description"
  )
  
  if help.config then
    for k, v in pairs(help.config) do
      status_text = status_text .. string.format("- %s: %s\n", k, tostring(v))
    end
  end
  
  if help.commands then
    status_text = status_text .. "\n## Available Commands\n"
    for _, cmd in ipairs(help.commands) do
      status_text = status_text .. "- " .. cmd .. "\n"
    end
  end
  
  if output_handler and output_handler.display then
    output_handler.display(status_text, {
      title = "Agent Status",
      split = "new",
    })
  else
    print(status_text)
  end
end

-- ============================================
-- Logging Functions
-- ============================================

function M.show_logs(lines)
  lines = lines or 50
  
  local content = logger.get_recent_logs(lines)
  if #content == 0 then
    buffer_manager.add_system_message("No logs found")
    return
  end
  
  local output = "# Agent Logs (Last " .. #content .. " lines)\n\n```\n"
  output = output .. table.concat(content, "\n")
  output = output .. "\n```"
  
  if output_handler and output_handler.display then
    output_handler.display(output, {
      title = "Agent Logs",
      split = "vnew",
    })
  else
    print(output)
  end
end

function M.clear_logs()
  if logger.clear_logs() then
    buffer_manager.add_system_message("Logs cleared")
  else
    buffer_manager.add_system_message("Failed to clear logs")
  end
end

function M.show_log_status()
  local size = logger.get_log_size()
  local file = logger.config.log_file
  
  local status = string.format(
    "Log file: %s\nSize: %d bytes\nEnabled: %s\nLevel: %s",
    file,
    size,
    logger.config.enabled and "Yes" or "No",
    logger.config.level
  )
  
  buffer_manager.add_system_message(status)
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
  end, { desc = "Select file" })
  
  vim.api.nvim_create_user_command('SendVisual', function()
    M.send_visual_with_prompt()
  end, { desc = "Send visual selection with prompt" })
  
  vim.api.nvim_create_user_command('SendVisualQuick', function()
    M.send_visual_quick()
  end, { desc = "Send visual selection without prompt" })
  
  -- Agent management commands
  vim.api.nvim_create_user_command('AgentList', function()
    M.list_agents()
  end, { desc = "List available agents" })
  
  vim.api.nvim_create_user_command('AgentSwitch', function(opts)
    M.switch_agent(opts.args)
  end, { desc = "Switch default agent", nargs = 1 })
  
  vim.api.nvim_create_user_command('AgentStatus', function()
    M.agent_status()
  end, { desc = "Show current agent status" })
  
  -- Logging commands
  vim.api.nvim_create_user_command('AgentLog', function(opts)
    local lines = tonumber(opts.args) or 50
    M.show_logs(lines)
  end, { desc = "Show agent logs", nargs = "?" })
  
  vim.api.nvim_create_user_command('AgentLogClear', function()
    M.clear_logs()
  end, { desc = "Clear agent logs" })
  
  vim.api.nvim_create_user_command('AgentLogStatus', function()
    M.show_log_status()
  end, { desc = "Show log status" })
  
  -- DeepSeek commands
  local deepseek_agent = agent_manager.get("deepseek")
  if deepseek_agent then
    vim.api.nvim_create_user_command('DeepSeekReload', function()
      if deepseek_agent.reload_token then
        if deepseek_agent.reload_token() then
          buffer_manager.add_system_message("DeepSeek token reloaded successfully")
        else
          buffer_manager.add_system_message("Failed to reload DeepSeek token")
        end
      end
    end, { desc = "Reload DeepSeek API token" })

    vim.api.nvim_create_user_command('DeepSeekModel', function(opts)
      if deepseek_agent.set_model then
        if deepseek_agent.set_model(opts.args) then
          buffer_manager.add_system_message("DeepSeek model set to: " .. opts.args)
        else
          buffer_manager.add_system_message("Invalid model: " .. opts.args)
        end
      end
    end, { desc = "Set DeepSeek model", nargs = 1 })

    vim.api.nvim_create_user_command('DeepSeekClear', function()
      if deepseek_agent.clear_history then
        deepseek_agent.clear_history()
        buffer_manager.add_system_message("DeepSeek history cleared")
      end
    end, { desc = "Clear DeepSeek history" })

    vim.api.nvim_create_user_command('DeepSeekModels', function()
      if deepseek_agent.get_models then
        local models = deepseek_agent.get_models()
        buffer_manager.add_system_message("Available models: " .. table.concat(models, ", "))
      end
    end, { desc = "List available DeepSeek models" })
    
    vim.api.nvim_create_user_command('DeepSeekTimeout', function(opts)
      if deepseek_agent.set_timeout then
        local timeout = tonumber(opts.args)
        if timeout and timeout > 0 then
          deepseek_agent.set_timeout(timeout)
          buffer_manager.add_system_message("DeepSeek timeout set to: " .. timeout .. "s")
        else
          buffer_manager.add_system_message("Please provide a valid timeout in seconds")
        end
      end
    end, { desc = "Set DeepSeek timeout in seconds", nargs = 1 })
  end
  
  -- Keymaps
  vim.api.nvim_set_keymap('n', config.keys.chat, '<cmd>Chat<CR>', { noremap = true, silent = true })
  vim.api.nvim_set_keymap('n', config.keys.file, '<cmd>File<CR>', { noremap = true, silent = true })
  
  vim.api.nvim_set_keymap('v', '<leader>v', ':<C-U>SendVisual<CR>', { noremap = true, silent = true })
  vim.api.nvim_set_keymap('v', '<leader>V', ':<C-U>SendVisualQuick<CR>', { noremap = true, silent = true })
  vim.api.nvim_set_keymap('v', 'gv', ':<C-U>SendVisual<CR>', { noremap = true, silent = true })
  
  is_loaded = true
  
  if config.general.show_welcome then
    print("vimds: Loaded! Using agent: " .. (agent_manager.get_default() or "chat"))
    print("Try: :ChatSend Hello")
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
    print("vimds ENABLED! Try: :Chat, :ChatSend Hello")
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
  
  local default_agent = agent_manager.get_default()
  local agent = default_agent and agent_manager.get(default_agent)
  local history_count = agent and agent.get_history and #agent.get_history() or 0
  
  local status_text = string.format([[
# vimds Status

## Plugin Status
- Loaded: Yes
- Active: %s

## Current Agent
- Name: %s
- History: %d messages

## Available Agents
- %s

## Keymaps
- Chat: <leader>c
- File: <leader>f
- Visual (prompt): <leader>v or gv
- Visual (quick): <leader>V

## Commands
- :Chat - Open chat
- :ChatSend <msg> - Send message
- :AgentList - List all agents
- :AgentSwitch <name> - Change agent
- :AgentStatus - Show agent status
- :AgentLog - Show logs
]],
    is_active and "Yes" or "No",
    default_agent or "None",
    history_count,
    table.concat(agent_manager.list(), ", ")
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
