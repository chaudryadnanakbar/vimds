# Configuration Guide

All configuration is in ~/.config/nvim/lua/vimds/config.lua

## Agent Configuration

M.agent = {
  default = "deepseek",
  providers = {
    deepseek = {
      model = "deepseek/deepseek-chat",
      max_tokens = 2000,
      temperature = 0.7,
    },
    openai = {
      api_key = os.getenv("OPENAI_API_KEY") or "",
      model = "gpt-3.5-turbo",
    },
    webhook = {
      url = os.getenv("WEBHOOK_URL") or "",
      method = "POST",
    },
  },
}

## Logging Settings

M.logging = {
  enabled = true,
  level = "info",
  file = os.getenv("HOME") .. "/.vimds_agent.log",
}

## General Settings

M.general = {
  auto_enable = true,
  show_welcome = true,
  debug = false,
}

## Keymaps

M.keys = {
  chat = "<leader>c",
  file = "<leader>f",
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

## Environment Variables

| Variable | Description |
|----------|-------------|
| OPENAI_API_KEY | OpenAI API key |
| WEBHOOK_URL | Webhook endpoint URL |
| CUSTOM_API_URL | Custom API URL |

## Examples

### Use OpenAI

M.agent = {
  default = "openai",
  providers = {
    openai = {
      api_key = "sk-...",
      model = "gpt-4",
    },
  },
}

### Use Webhook

M.agent = {
  default = "webhook",
  providers = {
    webhook = {
      url = "https://my-service.com/chat",
      method = "POST",
    },
  },
}
