-- ../plugin/config.lua
-- ============================================
-- vimds Configuration
-- Edit this file to customize vimds
-- ============================================

local M = {}

-- ============================================
-- General Settings
-- ============================================
M.general = {
  auto_enable = true,        -- Auto-enable when loaded
  show_welcome = true,       -- Show welcome message
  debug = false,             -- Enable debug messages
}

-- ============================================
-- Keymaps
-- ============================================
M.keys = {
  hello = "\\c",             -- Primary key to show hello (\c)
  hello_alt = "<leader>c",   -- Alternative key (<leader>c)
  close_output = "q",        -- Key to close output window
}

-- ============================================
-- Output Settings
-- ============================================
M.output = {
  split = "new",             -- "new" for horizontal, "vnew" for vertical
  filetype = "markdown",     -- Filetype for output buffer
  title_prefix = "vimds",    -- Prefix for buffer titles
  auto_close = true,         -- Auto-close when leaving window
  width = 80,                -- Width for vertical splits
  height = 20,               -- Height for horizontal splits
}

-- ============================================
-- External API Settings
-- ============================================
M.api = {
  enabled = false,           -- Enable HTTP API server
  port = 8080,               -- Port for HTTP server
  host = "127.0.0.1",        -- Host for HTTP server
  auto_start = false,        -- Start server on plugin load
}

-- ============================================
-- Socket Settings
-- ============================================
M.socket = {
  enabled = false,           -- Enable socket server
  path = "/tmp/vimds.sock",  -- Socket path
  auto_start = false,        -- Start server on plugin load
}

-- ============================================
-- External Agent Settings
-- ============================================
M.agent = {
  enabled = false,           -- Enable external agent integration
  command = "python3",       -- Command to run agent
  script = "~/vimds_agent.py", -- Agent script path
  timeout = 5,               -- Timeout in seconds
}

-- ============================================
-- Display Settings
-- ============================================
M.display = {
  show_timestamp = true,     -- Show timestamp in output
  show_buffer_info = true,   -- Show buffer info in output
  show_keymaps = true,       -- Show keymaps in output
  compact_mode = false,      -- Compact output mode
}

-- ============================================
-- Advanced Settings
-- ============================================
M.advanced = {
  lazy_load = true,          -- Use lazy loading
  load_command = "LoadVimds", -- Command to manually load
  toggle_command = "Vimds",   -- Command to toggle
  status_command = "VimdsStatus", -- Command to show status
  help_command = "VimdsHelp",  -- Command to show help
}

return M
