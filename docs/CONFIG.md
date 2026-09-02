# Configuration Guide

## Overview

All configuration is in ~/.config/nvim/lua/vimds/config.lua

## General Settings

M.general = {
  auto_enable = true,
  show_welcome = true,
  debug = false,
}

## Keymaps

M.keys = {
  hello = "\\c",
  hello_alt = "<leader>c",
  close_output = "q",
}

## Output Settings

M.output = {
  split = "new",
  filetype = "markdown",
  title_prefix = "vimds",
  auto_close = true,
  width = 80,
  height = 20,
}

## HTTP API Settings

M.api = {
  enabled = false,
  port = 8080,
  host = "127.0.0.1",
  auto_start = false,
}

## Socket Settings

M.socket = {
  enabled = false,
  path = "/tmp/vimds.sock",
  auto_start = false,
}

## Example Configurations

### Minimal Config

local M = {}
M.keys = { hello = "<F2>" }
M.api = { enabled = true, port = 8080 }
return M
