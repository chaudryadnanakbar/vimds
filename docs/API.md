# API Documentation

## Agent Interface

function agent.call(payload)
  -- Input: { message = string, context = table, timestamp = string }
  -- Output: { success = bool, response = string, provider = string }
end

function agent.help()
  -- Output: { name = string, description = string, config = table }
end

## HTTP API

### GET /hello

curl http://localhost:8080/hello

Response: {"message": "Hello from vimds!"}

### POST /hello

curl -X POST -H "Content-Type: application/json" \
  -d '{"name":"World"}' \
  http://localhost:8080/hello

Response: {"message": "Hello World"}

## Socket API

### hello command

echo "hello" | socat - UNIX-CONNECT:/tmp/vimds.sock

### status command

echo "status" | socat - UNIX-CONNECT:/tmp/vimds.sock

## Neovim API

require("vimds")              -- Load plugin
require("vimds").setup()      -- Initialize
require("vimds").enable()     -- Enable
require("vimds").disable()    -- Disable
require("vimds").toggle()     -- Toggle
require("vimds").status()     -- Show status

## Agent Manager

local manager = require("vimds.agents")
manager.register("name", agent)
manager.set_default("name")
manager.get_default()
manager.list()
manager.call("name", message)
manager.call_default(message)

## Logger

local logger = require("vimds.utils.logger")
logger.debug("msg", data)
logger.info("msg", data)
logger.warn("msg", data)
logger.error("msg", data)
