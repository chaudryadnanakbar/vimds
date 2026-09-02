-- plugin/utils/logger.lua
local M = {}

-- ============================================
-- Configuration
-- ============================================
M.config = {
  enabled = true,
  log_file = os.getenv("HOME") .. "/.vimds_agent.log",
  max_size = 10 * 1024 * 1024, -- 10MB
  level = "info", -- debug, info, warn, error
}

-- Log levels
local LEVELS = {
  debug = 1,
  info = 2,
  warn = 3,
  error = 4,
}

-- ============================================
-- Helper Functions
-- ============================================

-- Check if log level should be shown
function M.should_log(level)
  if not M.config.enabled then
    return false
  end
  local current = LEVELS[M.config.level] or LEVELS.info
  local requested = LEVELS[level] or LEVELS.info
  return requested >= current
end

-- Get log file size
function M.get_log_size()
  local file = io.open(M.config.log_file, "r")
  if not file then
    return 0
  end
  local size = file:seek("end")
  file:close()
  return size
end

-- Rotate log file if too large
function M.rotate_log()
  local size = M.get_log_size()
  if size > M.config.max_size then
    local old_file = M.config.log_file .. ".old"
    os.rename(M.config.log_file, old_file)
    M.info("Log file rotated (was " .. size .. " bytes)")
  end
end

-- Write to log
function M.write(level, message, data)
  if not M.should_log(level) then
    return
  end
  
  -- Rotate if needed
  M.rotate_log()
  
  local timestamp = os.date("%Y-%m-%d %H:%M:%S")
  local log_line = string.format("[%s] [%s] %s", timestamp, level:upper(), message)
  
  -- Format data if present
  if data then
    if type(data) == "table" then
      -- Try to format nicely, truncate if too long
      local data_str = vim.inspect(data)
      if #data_str > 1000 then
        data_str = data_str:sub(1, 1000) .. "... (truncated)"
      end
      log_line = log_line .. "\n  " .. data_str
    else
      log_line = log_line .. " " .. tostring(data)
    end
  end
  
  local file = io.open(M.config.log_file, "a")
  if file then
    file:write(log_line .. "\n")
    file:close()
  end
end

-- ============================================
-- Public Log Functions
-- ============================================

function M.debug(message, data)
  M.write("debug", message, data)
end

function M.info(message, data)
  M.write("info", message, data)
end

function M.warn(message, data)
  M.write("warn", message, data)
end

function M.error(message, data)
  M.write("error", message, data)
end

-- Special log for agent calls
function M.log_agent_call(agent_name, message, context)
  M.info("Agent called: " .. agent_name, {
    message = message:sub(1, 200),
    context = context,
    timestamp = os.date("%Y-%m-%d %H:%M:%S"),
  })
end

-- Special log for agent responses
function M.log_agent_response(agent_name, response, duration_ms, success)
  M.info("Agent response: " .. agent_name, {
    response = type(response) == "string" and response:sub(1, 500) or response,
    duration_ms = duration_ms,
    success = success,
    timestamp = os.date("%Y-%m-%d %H:%M:%S"),
  })
end

-- Special log for agent errors
function M.log_agent_error(agent_name, error_msg, duration_ms)
  M.error("Agent error: " .. agent_name, {
    error = error_msg,
    duration_ms = duration_ms,
    timestamp = os.date("%Y-%m-%d %H:%M:%S"),
  })
end

-- Get recent logs
function M.get_recent_logs(lines)
  lines = lines or 50
  local content = {}
  
  local file = io.open(M.config.log_file, "r")
  if not file then
    return { "No log file found" }
  end
  
  -- Read all lines and get last N
  local all_lines = {}
  for line in file:lines() do
    table.insert(all_lines, line)
  end
  file:close()
  
  local start = math.max(1, #all_lines - lines)
  for i = start, #all_lines do
    table.insert(content, all_lines[i])
  end
  
  return content
end

-- Clear log file
function M.clear_logs()
  local file = io.open(M.config.log_file, "w")
  if file then
    file:write("-- Log cleared at " .. os.date("%Y-%m-%d %H:%M:%S") .. "\n")
    file:close()
    M.info("Log file cleared")
    return true
  end
  return false
end

return M
