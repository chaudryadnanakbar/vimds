-- plugin/agents/deepseek.lua
local M = {}

local logger = require("vimds.utils.logger")

-- ============================================
-- Configuration
-- ============================================
M.config = {
  api_key = nil,
  model = "deepseek/deepseek-chat",
  max_tokens = 2000,
  temperature = 0.7,
  api_url = "https://openrouter.ai/api/v1/chat/completions",
  timeout = 30,
  debug = true, -- Enable debug logging
}

M.history = {}
M.max_history = 100

-- ============================================
-- Load API Key from File
-- ============================================
local function load_api_key()
  local token_file = os.getenv("HOME") .. "/.config/openrouter.token"
  local file = io.open(token_file, "r")
  if file then
    local token = file:read("*all"):gsub("%s+", "")
    file:close()
    if token and token ~= "" then
      M.config.api_key = token
      logger.info("DeepSeek API key loaded", {
        key_preview = token:sub(1, 15) .. "..."
      })
      return true
    end
  end
  logger.warn("DeepSeek token file not found", { file = token_file })
  return false
end

load_api_key()

-- ============================================
-- Execute curl with timeout
-- ============================================
local function execute_curl_with_timeout(cmd, timeout)
  timeout = timeout or M.config.timeout or 30
  
 
 
  -- Add timeout to curl command
  local cmd_with_timeout = string.format(
    'timeout %d %s',
    timeout,
    cmd
  )
  
  logger.debug("Executing curl with timeout", {
    timeout = timeout,
  })
  
  local start_time = os.clock()
  local result = io.popen(cmd_with_timeout):read('*all')
  local duration_ms = (os.clock() - start_time) * 1000
  
  logger.debug("Curl completed", {
    duration_ms = duration_ms,
    response_length = #result,
  })
  
  return result, duration_ms
end

-- ============================================
-- DeepSeek API Call
-- ============================================
function M.call(payload)
  local message = payload.message
  
  logger.debug("DeepSeek agent called", {
    message = message:sub(1, 50),
    has_key = M.config.api_key and "yes" or "no",
  })
  
  -- Check API key
  if not M.config.api_key or M.config.api_key == "" then
    if not load_api_key() then
      return {
        success = false,
        response = "DeepSeek API key not found. Please create ~/.config/openrouter.token",
        provider = "deepseek",
        error = "API key missing",
      }
    end
  end
  
  -- Build messages
  local messages = {
    {
      role = "system",
      content = "You are a helpful assistant integrated with Neovim. Help users with coding, debugging, and general questions. Keep responses concise.",
    }
  }
  
  for _, msg in ipairs(M.history) do
    table.insert(messages, { role = "user", content = msg.user })
    table.insert(messages, { role = "assistant", content = msg.assistant })
  end
  
  table.insert(messages, { role = "user", content = message })
  
  local request_payload = {
    model = M.config.model,
    messages = messages,
    max_tokens = M.config.max_tokens,
    temperature = M.config.temperature,
  }
  
  -- Create temp file for JSON
  local json_payload = vim.json.encode(request_payload)
  local tmp_file = "/tmp/vimds_deepseek_payload.json"
  local f = io.open(tmp_file, "w")
  if f then
    f:write(json_payload)
    f:close()
  else
    return {
      success = false,
      response = "Failed to create API request",
      provider = "deepseek",
      error = "Temp file error",
    }
  end
  
  -- Build curl command
  local cmd = string.format(
    'curl -s -X POST "%s" -H "Content-Type: application/json" -H "Authorization: Bearer %s" -d @%s 2>&1',
    M.config.api_url,
    M.config.api_key,
    tmp_file
  )
  
  logger.debug("Executing API call", {
    model = M.config.model,
    url = M.config.api_url,
    timeout = M.config.timeout,
  })
  
  -- Execute with timeout
  local result, duration_ms = execute_curl_with_timeout(cmd, M.config.timeout)
  
  -- Clean up temp file
  os.remove(tmp_file)
  
  -- Check if timeout occurred (empty result)
  if not result or result == "" then
    logger.error("DeepSeek API timeout or no response", {
      duration_ms = duration_ms,
    })
    return {
      success = false,
      response = "DeepSeek API timeout after " .. M.config.timeout .. " seconds. Please try again.",
      provider = "deepseek",
      error = "Timeout",
    }
  end
  
  logger.debug("Response received", {
    duration_ms = duration_ms,
    response_length = #result,
    response_preview = result:sub(1, 200)
  })
  
  -- Parse JSON response
  local success, parsed = pcall(vim.json.decode, result)
  
  if success and parsed then
    if parsed.error then
      local error_msg = parsed.error.message or "Unknown error"
      logger.error("DeepSeek API error", {
        error = error_msg,
        code = parsed.error.code,
      })
      
      local user_msg = "DeepSeek API error: " .. error_msg
      if parsed.error.code == 401 then
        user_msg = "Authentication failed (401). Please check your OpenRouter API key in ~/.config/openrouter.token"
      elseif parsed.error.code == 403 then
        user_msg = "Forbidden (403). Your API key may not have access to this model."
      elseif parsed.error.code == 429 then
        user_msg = "Rate limit exceeded (429). Please try again later."
      end
      
      return {
        success = false,
        response = user_msg,
        provider = "deepseek",
        error = parsed.error,
      }
    end
    
    if parsed.choices and parsed.choices[1] then
      local response = parsed.choices[1].message.content
      
      table.insert(M.history, {
        user = message,
        assistant = response,
        timestamp = os.date("%Y-%m-%d %H:%M:%S"),
      })
      
      if #M.history > M.max_history then
        table.remove(M.history, 1)
      end
      
      logger.info("DeepSeek response successful", {
        model = parsed.model or M.config.model,
        duration_ms = duration_ms,
        response_length = #response,
      })
      
      return {
        success = true,
        response = response,
        provider = "deepseek",
        model = parsed.model or M.config.model,
        usage = parsed.usage,
        duration_ms = duration_ms,
      }
    end
  end
  
  logger.error("DeepSeek API parse error", {
    raw = result:sub(1, 300),
  })
  
  return {
    success = false,
    response = "Failed to parse DeepSeek response. Check your API key.",
    provider = "deepseek",
    error = result:sub(1, 500),
  }
end

-- ============================================
-- Agent Management Functions
-- ============================================

function M.get_history()
  return M.history
end

function M.clear_history()
  M.history = {}
  logger.info("DeepSeek history cleared")
  return { success = true, message = "History cleared" }
end

function M.set_model(model)
  M.config.model = model
  logger.info("DeepSeek model changed", { model = model })
  return true
end

function M.get_models()
  return {
    "deepseek/deepseek-chat",
    "deepseek/deepseek-coder",
    "deepseek/deepseek-r1",
  }
end

function M.reload_token()
  return load_api_key()
end

function M.set_timeout(timeout)
  M.config.timeout = timeout
  logger.info("DeepSeek timeout set", { timeout = timeout })
  return true
end

function M.help()
  return {
    name = "deepseek",
    description = "DeepSeek AI agent via OpenRouter API",
    config = {
      model = M.config.model,
      max_tokens = M.config.max_tokens,
      temperature = M.config.temperature,
      timeout = M.config.timeout .. "s",
      api_key = M.config.api_key and "✅ Loaded" or "❌ Not found",
      history_count = #M.history,
    },
    commands = {
      "Any message - Send to DeepSeek AI",
      ":DeepSeekReload - Reload API token",
      ":DeepSeekModel <model> - Change model",
      ":DeepSeekClear - Clear history",
      ":DeepSeekModels - List models",
      ":DeepSeekTimeout <seconds> - Set timeout",
    },
  }
end

return M
