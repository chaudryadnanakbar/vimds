-- plugins/agents/webhook.lua
local M = {}

M.config = {
  url = os.getenv("WEBHOOK_URL") or "http://localhost:3000/webhook",
  method = "POST",
}

function M.call(payload)
  local message = payload.message
  local context = payload.context or {}
  
  if not M.config.url or M.config.url == "" then
    return {
      success = false,
      response = "Webhook URL not configured",
      provider = "webhook",
    }
  end
  
  -- Build payload for webhook
  local webhook_payload = {
    message = message,
    context = context,
    timestamp = payload.timestamp,
    source = "vimds",
  }
  
  local cmd = string.format(
    'curl -s -X %s %s -H "Content-Type: application/json" -d \'%s\' 2>/dev/null',
    M.config.method,
    M.config.url,
    vim.json.encode(webhook_payload)
  )
  
  local result = io.popen(cmd):read('*all')
  
  -- Try to parse response
  local response = "Webhook request sent successfully"
  if result and result ~= "" then
    local success, parsed = pcall(vim.json.decode, result)
    if success then
      response = parsed.response or parsed.message or parsed.result or result
    else
      response = result
    end
  end
  
  return {
    success = true,
    response = response,
    provider = "webhook",
    raw_response = result,
    timestamp = payload.timestamp,
  }
end

function M.help()
  return {
    name = "webhook",
    description = "Send messages to a webhook endpoint",
    config = {
      url = M.config.url,
      method = M.config.method,
    },
  }
end

return M
