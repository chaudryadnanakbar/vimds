-- plugin/agents/init.lua
local M = {}

-- Registered agents
M.agents = {}

-- Register an agent
function M.register(name, agent)
  M.agents[name] = agent
  print(string.format("Agent registered: %s", name))
end

-- Get an agent
function M.get(name)
  return M.agents[name]
end

-- List all agents
function M.list()
  local names = {}
  for name, _ in pairs(M.agents) do
    table.insert(names, name)
  end
  return names
end

-- Call an agent
function M.call(name, ...)
  local agent = M.agents[name]
  if not agent then
    return nil, string.format("Agent not found: %s", name)
  end
  
  if not agent.call then
    return nil, string.format("Agent %s has no call method", name)
  end
  
  local success, result = pcall(agent.call, ...)
  if not success then
    return nil, string.format("Agent %s error: %s", name, tostring(result))
  end
  
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
