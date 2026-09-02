-- ../plugin/utils/buffer.lua
local config = require("vimds.config")
local M = {}

-- Create a split window with content
function M.create_split(content, opts)
  opts = opts or {}
  local title = opts.title or config.output.title_prefix .. " Output"
  local filetype = opts.filetype or config.output.filetype
  local split_cmd = opts.split or config.output.split
  
  -- Create new split
  vim.cmd(split_cmd)
  
  -- Set window size
  if split_cmd == "vnew" and config.output.width then
    vim.api.nvim_win_set_width(0, config.output.width)
  elseif split_cmd == "new" and config.output.height then
    vim.api.nvim_win_set_height(0, config.output.height)
  end
  
  -- Get current buffer
  local buf = vim.api.nvim_get_current_buf()
  
  -- Set buffer options
  vim.bo[buf].bufhidden = "wipe"
  vim.bo[buf].buftype = "nofile"
  vim.bo[buf].swapfile = false
  vim.bo[buf].filetype = filetype
  
  -- Set window options
  vim.wo.wrap = true
  vim.wo.number = false
  vim.wo.relativenumber = false
  vim.wo.signcolumn = "no"
  
  -- Set content
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, vim.split(content, "\n"))
  
  -- Set title
  vim.api.nvim_buf_set_name(buf, title)
  
  -- Add keymap to close
  local close_key = config.keys.close_output or "q"
  vim.keymap.set('n', close_key, function()
    vim.api.nvim_win_close(0, true)
  end, { buffer = buf, desc = "Close vimds output" })
  
  -- Auto-close on window leave if configured
  if config.output.auto_close then
    vim.api.nvim_create_autocmd("WinLeave", {
      buffer = buf,
      callback = function()
        if vim.api.nvim_buf_is_valid(buf) then
          vim.api.nvim_buf_delete(buf, { force = true })
        end
      end,
    })
  end
  
  return buf
end

-- Append to existing buffer
function M.append_to_buffer(buf, content)
  local lines = vim.split(content, "\n")
  local last_line = vim.api.nvim_buf_line_count(buf)
  vim.api.nvim_buf_set_lines(buf, last_line - 1, -1, false, lines)
end

-- Clear buffer content
function M.clear_buffer(buf)
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, {})
end

-- Get current buffer content
function M.get_buffer_content(buf)
  return vim.api.nvim_buf_get_lines(buf, 0, -1, false)
end

-- Close all vimds output buffers
function M.close_all_outputs()
  local prefix = config.output.title_prefix or "vimds"
  for _, win in ipairs(vim.api.nvim_list_wins()) do
    local buf = vim.api.nvim_win_get_buf(win)
    local bufname = vim.api.nvim_buf_get_name(buf)
    if bufname:match(prefix) then
      vim.api.nvim_win_close(win, true)
    end
  end
end

return M
