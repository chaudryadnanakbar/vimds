-- plugins/agents/chat.lua
local M = {}

M.history = {}

function M.call(payload)
  local message = payload.message
  local context = payload.context or {}
  
  -- Simple response logic
  local msg = message:lower()
  local response
  
  if msg:match("hello") then
    response = "Hello there! 👋 How can I help you?"
  elseif msg:match("time") then
    response = "The time is " .. os.date("%H:%M:%S")
  elseif msg:match("help") then
    response = "I'm here to help! Ask me anything."
  else
    response = "I received your message: '" .. message .. "'"
  end
  
  -- Store in history
  table.insert(M.history, {
    user = message,
    assistant = response,
    timestamp = os.date("%Y-%m-%d %H:%M:%S"),
  })
  
  return {
    success = true,
    response = response,
    provider = "chat",
    timestamp = payload.timestamp,
  }
end

function M.help()
  return {
    name = "chat",
    description = "Simple chat agent with basic responses",
    commands = {
      "hello - Greeting",
      "time - Get current time",
      "help - Show help",
    },
  }
end

return M
