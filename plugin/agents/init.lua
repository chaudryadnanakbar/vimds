-- plugin/agents/init.lua
local M = {}

local logger = require("vimds.utils.logger")

-- Registered agents
M.agents = {}
M.default_agent = nil

-- Register an agent
function M.register(name, agent)
  if not agent.call then
    logger.warn("Agent missing call() method", { agent = name })
  end
  M.agents[name] = agent
  logger.info("Agent registered", { agent = name })
  print(string.format("Agent registered: %s", name))
end

-- Get an agent by name
function M.get(name)
  return M.agents[name]
end

-- Set default agent
function M.set_default(name)
  if M.agents[name] then
    M.default_agent = name
    logger.info("Default agent set", { agent = name })
    print(string.format("Default agent set to: %s", name))
    return true
  end
  logger.warn("Agent not found", { agent = name })
  print(string.format("Agent not found: %s", name))
  return false
end

-- Get default agent
function M.get_default()
  return M.default_agent
end

-- List all agents
function M.list()
  local names = {}
  for name, _ in pairs(M.agents) do
    table.insert(names, name)
  end
  return names
end

-- Call default agent with logging
function M.call_default(message, context)
  if not M.default_agent then
    local err = "No default agent set"
    logger.error(err)
    return nil, err
  end
  
  local agent = M.agents[M.default_agent]
  if not agent then
    local err = string.format("Default agent '%s' not found", M.default_agent)
    logger.error(err)
    return nil, err
  end
  
  return M.call(M.default_agent, message, context)
end

-- Call specific agent with logging
function M.call(name, message, context)
  local start_time = os.clock()
  
  logger.log_agent_call(name, message, context)
  
  local agent = M.agents[name]
  if not agent then
    local err = string.format("Agent not found: %s", name)
    logger.log_agent_error(name, err, (os.clock() - start_time) * 1000)
    return nil, err
  end
  
  local payload = {
    message = message,
    context = context or {},
    timestamp = os.date("%Y-%m-%d %H:%M:%S"),
  }
  
  local success, result = pcall(agent.call, payload)
  local duration_ms = (os.clock() - start_time) * 1000
  
  if not success then
    local err_msg = tostring(result)
    logger.log_agent_error(name, err_msg, duration_ms)
    return nil, string.format("Agent error: %s", err_msg)
  end
  
  local response = result and result.response or "No response"
  logger.log_agent_response(name, response, duration_ms, result and result.success or false)
  
  return result, nil
end

-- Get agent help
function M.get_help(name)
  local agent = M.agents[name]
  if not agent then
    return nil, "Agent not found"
  end
  if agent.help then
    return agent.help()
  end
  return { name = name, description = "No help available" }
end

return M
