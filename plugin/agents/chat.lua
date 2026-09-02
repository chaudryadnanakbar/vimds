-- plugin/agents/chat.lua
local M = {}

-- Chat history
M.history = {}
M.max_history = 100

-- Responses
local responses = {
  "That's a great question! Let me think about it carefully.",
  "I understand what you're saying. Here's my perspective on that...",
  "Interesting point! Have you considered looking at it from this angle?",
  "I can definitely help with that. Let me break it down for you.",
  "That reminds me of something similar I worked on before.",
  "Let me analyze that from a few different perspectives...",
  "I see what you mean. Here's my recommendation.",
  "That's a common challenge. Here's how I would approach it.",
  "Great question! Let me give you a detailed answer.",
  "I appreciate you asking that. Here's what I think.",
}

-- Keyword responses - FIXED: Use proper table syntax
local keyword_responses = {
  hello = "Hello there! 👋 It's great to chat with you. How can I help today?",
  hi = "Hi! 😊 I'm here to help you with anything you need.",
  help = "I'm here to help! Use :ChatSend <message> to chat with me.",
  time = "The current time is " .. os.date("%H:%M:%S") .. " ⏰",
  date = "Today is " .. os.date("%B %d, %Y") .. " 📅",
  bye = "Goodbye! 👋 It was great chatting with you!",
  thanks = "You're very welcome! 😊 Happy to help!",
}

-- Generate response
function M.generate_response(message)
  local msg = message:lower()
  
  for keyword, response in pairs(keyword_responses) do
    if msg:match(keyword) then
      return response
    end
  end
  
  if msg:match("code") or msg:match("lua") then
    return "Here's a Lua example:\n```lua\nprint('Hello from vimds!')\n```"
  end
  
  return responses[math.random(#responses)] .. "\n\n_" .. message:sub(1, 50) .. "..._"
end

-- Call the chat agent
function M.call(message)
  if not message or message == "" then
    return {
      success = false,
      agent = "chat",
      error = "Message cannot be empty",
      timestamp = os.date("%Y-%m-%d %H:%M:%S"),
    }
  end
  
  -- Add to history
  table.insert(M.history, {
    role = "user",
    content = message,
    timestamp = os.date("%Y-%m-%d %H:%M:%S"),
  })
  
  if #M.history > M.max_history then
    table.remove(M.history, 1)
  end
  
  local response = M.generate_response(message)
  
  table.insert(M.history, {
    role = "assistant",
    content = response,
    timestamp = os.date("%Y-%m-%d %H:%M:%S"),
  })
  
  return {
    success = true,
    agent = "chat",
    message = message,
    response = response,
    timestamp = os.date("%Y-%m-%d %H:%M:%S"),
  }
end

-- Get history
function M.get_history()
  return M.history
end

-- Clear history
function M.clear_history()
  M.history = {}
  return { success = true, message = "Chat history cleared" }
end

-- Get help
function M.help()
  return {
    name = "chat",
    description = "Chat agent with contextual responses",
    commands = {
      "Any message - Chat with the agent",
      "hello, hi - Greetings",
      "help - Show help",
      "time, date - Get current time",
      "bye - Farewell",
    },
    history_count = #M.history,
  }
end

return M
