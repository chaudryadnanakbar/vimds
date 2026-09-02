-- plugins/agents/custom.lua
-- Template for creating your own agents
local M = {}

M.config = {
  name = "custom",
  description = "Your custom agent",
  -- Add your custom config here
}

function M.call(payload)
  local message = payload.message
  local context = payload.context or {}
  
  -- YOUR CUSTOM LOGIC HERE
  -- You can call external APIs, run scripts, etc.
  
  local response = "Custom agent processed: " .. message
  
  return {
    success = true,
    response = response,
    provider = "custom",
    timestamp = payload.timestamp,
    -- Add any custom fields you want
    custom_data = {
      processed_at = os.date("%Y-%m-%d %H:%M:%S"),
    },
  }
end

function M.help()
  return {
    name = "custom",
    description = M.config.description,
    config = M.config,
  }
end

return M
