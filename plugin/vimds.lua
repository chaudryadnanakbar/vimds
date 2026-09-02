return {
  "vimds",
  lazy = true,  -- Lazy load
  cmd = "vimds",  -- Load when :Vimds is called
  config = function()
    -- Just setup the command, nothing else loads
    require("vimds").setup()
  end,
}
