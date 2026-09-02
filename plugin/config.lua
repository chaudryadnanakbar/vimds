-- plugin/config.lua
local M = {}

M.general = {
  auto_enable = true,
  show_welcome = true,
  debug = false,
}

M.keys = {
  chat = "<leader>c",
  file = "<leader>f",
  close_output = "q",
}

M.output = {
  split = "new",
  filetype = "markdown",
  title_prefix = "vimds",
  auto_close = true,
  width = 80,
  height = 20,
}

M.api = {
  enabled = false,
  port = 8080,
  host = "127.0.0.1",
  auto_start = false,
}

M.socket = {
  enabled = false,
  path = "/tmp/vimds.sock",
  auto_start = false,
}

-- Add to config.lua
-- ============================================
-- Logging Settings
-- ============================================
M.logging = {
  enabled = true,
  level = "info",  -- debug, info, warn, error
  max_size = 10 * 1024 * 1024, -- 10MB
  file = os.getenv("HOME") .. "/.vimds_agent.log",
}

-- ============================================
-- Agent Configuration
-- ============================================
M.agent = {
  -- Which agent to use by default
  -- Options: "chat", "openai", "webhook", "custom", "deepseek"
  default = "deepseek",
  
  -- Agent-specific settings
  providers = {
    openai = {
      api_key = os.getenv("OPENAI_API_KEY") or "",
      model = "gpt-3.5-turbo",
      max_tokens = 500,
      temperature = 0.7,
    },
    webhook = {
      url = os.getenv("WEBHOOK_URL") or "http://localhost:3000/webhook",
      method = "POST",
    },
    custom = {
      url = os.getenv("CUSTOM_API_URL") or "",
      method = "POST",
      headers = {},
    },
    deepseek = {
      model = "deepseek/deepseek-chat",
      max_tokens = 2000,
      temperature = 0.7,
    },
  },
}

M.display = {
  show_timestamp = true,
  show_buffer_info = true,
  show_keymaps = true,
  compact_mode = false,
}

M.advanced = {
  lazy_load = true,
  load_command = "LoadVimds",
  toggle_command = "Vimds",
  status_command = "VimdsStatus",
  help_command = "VimdsHelp",
}

return M

