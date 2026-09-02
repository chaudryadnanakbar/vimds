-- plugin/config.lua
local M = {}

-- ============================================
-- General Settings
-- ============================================
M.general = {
  auto_enable = true,
  show_welcome = true,
  debug = false,
}

-- ============================================
-- Keymaps
-- ============================================
M.keys = {
  chat = "<leader>c",        -- Open chat
  file = "<leader>f",        -- Select file and send to agent
  visual = "<leader>v",      -- Send visual selection to agent
  close_output = "q",        -- Close output window
}

-- ============================================
-- Output Settings
-- ============================================
M.output = {
  split = "new",
  filetype = "markdown",
  title_prefix = "vimds",
  auto_close = true,
  width = 80,
  height = 20,
}

-- ============================================
-- API Settings
-- ============================================
M.api = {
  enabled = false,
  port = 8080,
  host = "127.0.0.1",
  auto_start = false,
}

-- ============================================
-- Socket Settings
-- ============================================
M.socket = {
  enabled = false,
  path = "/tmp/vimds.sock",
  auto_start = false,
}

-- ============================================
-- Agent Settings
-- ============================================
M.agent = {
  enabled = true,
  default = "chat",
  timeout = 5,
}

-- ============================================
-- Display Settings
-- ============================================
M.display = {
  show_timestamp = true,
  show_buffer_info = true,
  show_keymaps = true,
  compact_mode = false,
}

-- ============================================
-- Advanced Settings
-- ============================================
M.advanced = {
  lazy_load = true,
  load_command = "LoadVimds",
  toggle_command = "Vimds",
  status_command = "VimdsStatus",
  help_command = "VimdsHelp",
}

return M

