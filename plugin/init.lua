-- ../plugin/init.lua
local M = {}

-- Load config
local config = require("vimds.config")

-- Import modules
local output_handler = require("vimds.handlers.output")
local buffer_utils = require("vimds.utils.buffer")

-- State
local is_active = false
local is_loaded = false

-- ============================================
-- HTTP Server
-- ============================================
local function start_http_server()
  if config.api.enabled and config.api.auto_start then
    local port = config.api.port
    print("vimds: Starting HTTP server on port " .. port)
    
    local script = string.format([[
import sys
import json
from http.server import HTTPServer, BaseHTTPRequestHandler

class VimdsHandler(BaseHTTPRequestHandler):
    def do_GET(self):
        if self.path == '/hello':
            self.send_response(200)
            self.send_header('Content-type', 'application/json')
            self.end_headers()
            response = {'message': 'Hello from vimds!'}
            self.wfile.write(json.dumps(response).encode())
        elif self.path == '/status':
            self.send_response(200)
            self.send_header('Content-type', 'application/json')
            self.end_headers()
            response = {'status': 'active', 'plugin': 'vimds'}
            self.wfile.write(json.dumps(response).encode())
        else:
            self.send_response(404)
            self.end_headers()
            self.wfile.write(b'Not Found')
    
    def do_POST(self):
        if self.path == '/hello':
            content_length = int(self.headers['Content-Length'])
            post_data = self.rfile.read(content_length)
            data = json.loads(post_data.decode())
            self.send_response(200)
            self.send_header('Content-type', 'application/json')
            self.end_headers()
            response = {'message': 'Hello ' + data.get('name', 'World')}
            self.wfile.write(json.dumps(response).encode())

server = HTTPServer(('127.0.0.1', %d), VimdsHandler)
server.serve_forever()
]], port)
    
    local file = io.open("/tmp/vimds_server.py", "w")
    if file then
      file:write(script)
      file:close()
      os.execute("python3 /tmp/vimds_server.py &")
      print("vimds: HTTP server running on http://localhost:" .. port)
    end
  end
end

-- ============================================
-- Socket Server
-- ============================================
local function start_socket_server()
  if config.socket.enabled and config.socket.auto_start then
    local socket_path = config.socket.path
    print("vimds: Starting socket server at " .. socket_path)
    
    local script = string.format([[
import socket
import json
import os

sock_path = '%s'

try:
    os.unlink(sock_path)
except OSError:
    pass

server = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
server.bind(sock_path)
server.listen(1)

while True:
    conn, addr = server.accept()
    data = conn.recv(1024).decode()
    
    if data == 'hello':
        response = {'message': 'Hello from vimds socket!'}
        conn.send(json.dumps(response).encode())
    elif data == 'status':
        response = {'status': 'active', 'plugin': 'vimds'}
        conn.send(json.dumps(response).encode())
    else:
        response = {'error': 'Unknown command'}
        conn.send(json.dumps(response).encode())
    
    conn.close()
]], socket_path)
    
    local file = io.open("/tmp/vimds_socket_server.py", "w")
    if file then
      file:write(script)
      file:close()
      os.execute("python3 /tmp/vimds_socket_server.py &")
      print("vimds: Socket server running at " .. socket_path)
    end
  end
end

-- ============================================
-- External Agent Integration
-- ============================================
function M.call_external_agent(message)
  if config.api.enabled then
    local url = "http://" .. config.api.host .. ":" .. config.api.port .. "/hello"
    local cmd = string.format('curl -s -X POST -H "Content-Type: application/json" -d \'{"name":"%s"}\' %s 2>/dev/null', message, url)
    local result = io.popen(cmd):read('*all')
    
    if result and result ~= "" then
      output_handler.display("## Agent Response\n\n" .. result, {
        title = config.output.title_prefix .. " Agent Response",
        split = config.output.split,
      })
    else
      output_handler.display("## Agent Response\n\nNo response from agent. Make sure the HTTP server is running.", {
        title = config.output.title_prefix .. " Error",
        split = config.output.split,
      })
    end
    return result
  end
  
  output_handler.display("## Error\n\nNo external agent configured. Enable API in config.", {
    title = config.output.title_prefix .. " Error",
    split = config.output.split,
  })
  return nil
end

-- ============================================
-- Core Functions
-- ============================================
function M.setup()
  if is_loaded then
    return
  end
  
  -- Create commands from config
  vim.api.nvim_create_user_command(config.advanced.toggle_command, function()
    M.toggle()
  end, { desc = "Toggle vimds on/off" })
  
  vim.api.nvim_create_user_command(config.advanced.status_command, function()
    M.status()
  end, { desc = "Show vimds status" })
  
  vim.api.nvim_create_user_command(config.advanced.help_command, function()
    output_handler.show_help()
  end, { desc = "Show vimds help" })
  
  vim.api.nvim_create_user_command('VimdsClear', function()
    output_handler.clear()
  end, { desc = "Clear vimds output" })
  
  vim.api.nvim_create_user_command('VimdsClose', function()
    output_handler.close()
  end, { desc = "Close vimds output" })

  -- Add chat commands
  vim.api.nvim_create_user_command('Chat', function()
    M.open_chat()
  end, { desc = "Open chat buffer" })

  vim.api.nvim_create_user_command('ChatSend', function(opts)
    M.chat_send(opts.args)
  end, { desc = "Send message to chat", nargs = "*" })

  vim.api.nvim_create_user_command('ChatClear', function()
    M.chat_clear()
  end, { desc = "Clear chat buffer" })


  -- Start servers if enabled
  start_http_server()
  start_socket_server()
  
  is_loaded = true
  
  if config.general.show_welcome then
    print("vimds: Loaded! Use :" .. config.advanced.load_command .. " to enable")
  end
end

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
  print("vimds: Loaded! Use :" .. config.advanced.toggle_command .. " to toggle on/off")
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
  -- NEW OPTION 3: Use vim.notify (modern way, no Enter)
   -- WITH THIS (no Enter required):
  vim.api.nvim_echo({
    { "vimds: Lazy mode - Use :", "Normal" },
    { config.advanced.load_command, "Special" },
    { " to load", "Normal" }
  }, false, {})

end

function M.enable()
  if is_active then
    print("vimds already enabled")
    return
  end
  
  local keys = config.keys
  
  -- Keymaps
  if keys.hello then
    vim.keymap.set('n', keys.hello, function()
      M.hello()
    end, { desc = "vimds: Print hello" })
  end
  
  if keys.hello_alt then
    vim.keymap.set('n', keys.hello_alt, function()
      M.hello()
    end, { desc = "vimds: Print hello (alt)" })
  end
  
  -- Commands
  vim.api.nvim_create_user_command('Hello', function()
    M.hello()
  end, { desc = "vimds: Say Hello" })
  
  if config.agent.enabled then
    vim.api.nvim_create_user_command('Agent', function()
      M.call_external_agent("Neovim")
    end, { desc = "Call external agent" })
  end
  
  is_active = true
  
  if config.general.show_welcome then
    local key_display = keys.hello or "\\c"
    print("vimds ENABLED! Try: " .. key_display .. ", :Hello, or :" .. config.advanced.help_command)
  end
end

function M.disable()
  if not is_active then
    print("vimds already disabled")
    return
  end
  
  local keys = config.keys
  if keys.hello then
    pcall(function()
      vim.keymap.del('n', keys.hello)
    end)
  end
  if keys.hello_alt then
    pcall(function()
      vim.keymap.del('n', keys.hello_alt)
    end)
  end
  
  pcall(function()
    vim.api.nvim_del_user_command('Hello')
  end)
  if config.agent.enabled then
    pcall(function()
      vim.api.nvim_del_user_command('Agent')
    end)
  end
  
  is_active = false
  print("vimds DISABLED! Use :" .. config.advanced.toggle_command .. " to re-enable")
end

function M.toggle()
  if not is_loaded then
    M.manual_load()
    if config.general.auto_enable then
      M.enable()
    end
    return
  end
  
  if is_active then
    M.disable()
  else
    M.enable()
  end
end

function M.hello()
  if not is_loaded then
    print("vimds not loaded. Use :" .. config.advanced.load_command .. " to load")
    return
  end
  if not is_active then
    print("vimds is disabled. Use :" .. config.advanced.toggle_command .. " to enable")
    return
  end
  
  local content = string.format([[
# Hello from vimds!

## Message
Hello World from vimds!

## Information
- Time: %s
- Buffer: %d
- Active: %s
- Config: %s

## Quick Actions
- Press `%s` to close this window
- Press `%s` to show this again
- Use `:%s` for more help
]], 
    os.date("%Y-%m-%d %H:%M:%S"), 
    vim.api.nvim_get_current_buf(), 
    is_active and "Yes" or "No",
    config.output.title_prefix,
    config.keys.close_output or "q",
    config.keys.hello or "\\c",
    config.advanced.help_command
  )
  
  output_handler.display(content, {
    title = config.output.title_prefix .. " Hello",
    split = config.output.split,
  })
end

function M.status()
  if not is_loaded then
    print("vimds: NOT LOADED - Use :" .. config.advanced.load_command .. " to load")
    return
  end
  
  local status_info = {
    loaded = is_loaded and "Yes" or "No",
    active = is_active and "Yes" or "No",
    primary_key = config.keys.hello or "\\c",
    alt_key = config.keys.hello_alt or "<leader>c",
    http_url = config.api.enabled and ("http://" .. config.api.host .. ":" .. config.api.port) or "Disabled",
    socket_path = config.socket.enabled and config.socket.path or "Disabled",
  }
  
  output_handler.show_status(status_info)
end
-- ============================================
-- Chat Commands (Safe Buffer)
-- ============================================

function M.open_chat()
    local buffer_manager = require("vimds.utils.buffer_manager")
    buffer_manager.open_chat()
    -- Add welcome message if empty
    local buf = buffer_manager.get_chat_buffer()
    local lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
    if #lines <= 3 then
        buffer_manager.add_chat_message("Welcome to vimds chat! Type :ChatSend <message>", "System")
    end
end

function M.chat_send(message)
    if not message or message == "" then
        vim.cmd('echo "Please provide a message: :ChatSend <message>"')
        return
    end
    
    local buffer_manager = require("vimds.utils.buffer_manager")
    local config = require("vimds.config")
    
    -- Add user message
    buffer_manager.add_chat_message(message, "User")
    
    -- If agent is enabled, call it
    if config.agent and config.agent.enabled then
        vim.defer_fn(function()
            local response = M.call_external_agent(message)
            if response and response ~= "" then
                buffer_manager.add_chat_message(response, "Assistant")
            end
        end, 200)
    else
        -- Auto-response
        vim.defer_fn(function()
            local responses = {
                "That's interesting! Tell me more.",
                "I see. How can I help with that?",
                "Good point! Let me think about that.",
                "I understand. What would you like to do?",
            }
            local random_response = responses[math.random(#responses)]
            buffer_manager.add_chat_message(random_response, "Assistant")
        end, 300)
    end
    
    -- Auto-close any other output windows and show chat
    vim.defer_fn(function()
        vim.cmd('VimdsClose')
        vim.defer_fn(function()
            M.open_chat()
        end, 100)
    end, 50)
end

function M.chat_clear()
    local buffer_manager = require("vimds.utils.buffer_manager")
    buffer_manager.clear_chat()
    vim.cmd('echo "Chat cleared"')
end

-- ============================================
-- Load Mode
-- ============================================
if config.advanced.lazy_load then
  M.lazy_load()
else
  M.auto_start()
end

return M
