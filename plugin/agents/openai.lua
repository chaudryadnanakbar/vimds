-- plugins/agents/openai.lua
local M = {}

M.config = {
  api_key = os.getenv("OPENAI_API_KEY") or "",
  model = "gpt-3.5-turbo",
  max_tokens = 500,
  temperature = 0.7,
}
M.history = {}

function M.call(payload)
  local message = payload.message
  local context = payload.context or {}
  
  -- Check API key
  if not M.config.api_key or M.config.api_key == "" then
    return {
      success = false,
      response = "OpenAI API key not configured. Set OPENAI_API_KEY environment variable.",
      provider = "openai",
    }
  end
  
  -- Build messages with history
  local messages = {}
  for _, msg in ipairs(M.history) do
    table.insert(messages, { role = "user", content = msg.user })
    table.insert(messages, { role = "assistant", content = msg.assistant })
  end
  table.insert(messages, { role = "user", content = message })
  
  local payload_api = {
    model = M.config.model,
    messages = messages,
    max_tokens = M.config.max_tokens,
    temperature = M.config.temperature,
  }
  
  -- Call OpenAI API
  local cmd = string.format(
    'curl -s -X POST https://api.openai.com/v1/chat/completions \
      -H "Content-Type: application/json" \
      -H "Authorization: Bearer %s" \
      -d \'%s\' 2>/dev/null',
    M.config.api_key,
    vim.json.encode(payload_api)
  )
  
  local result = io.popen(cmd):read('*all')
  
  if result and result ~= "" then
    local success, parsed = pcall(vim.json.decode, result)
    if success and parsed.choices and parsed.choices[1] then
      local response = parsed.choices[1].message.content
      
      table.insert(M.history, {
        user = message,
        assistant = response,
        timestamp = os.date("%Y-%m-%d %H:%M:%S"),
      })
      
      return {
        success = true,
        response = response,
        provider = "openai",
        model = parsed.model,
        usage = parsed.usage,
        timestamp = payload.timestamp,
      }
    end
  end
  
  return {
    success = false,
    response = "OpenAI API error. Check your API key and network.",
    provider = "openai",
    timestamp = payload.timestamp,
  }
end

function M.help()
  return {
    name = "openai",
    description = "OpenAI GPT integration",
    config = {
      model = M.config.model,
      max_tokens = M.config.max_tokens,
      temperature = M.config.temperature,
    },
  }
end

return M
