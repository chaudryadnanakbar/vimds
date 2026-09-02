# API Documentation

## HTTP API Endpoints

### GET /hello
Returns a hello message.

curl http://localhost:8080/hello

Response: {"message": "Hello from vimds!"}

### GET /status
Returns plugin status.

curl http://localhost:8080/status

Response: {"status": "active", "plugin": "vimds"}

### POST /hello
Send a message with a name.

curl -X POST -H "Content-Type: application/json" -d '{"name":"World"}' http://localhost:8080/hello

Response: {"message": "Hello World"}

## Socket API

### hello command
echo "hello" | socat - UNIX-CONNECT:/tmp/vimds.sock
Response: {"message": "Hello from vimds socket!"}

### status command
echo "status" | socat - UNIX-CONNECT:/tmp/vimds.sock
Response: {"status": "active", "plugin": "vimds"}

## Neovim API

require("vimds").setup()           - Initialize the plugin
require("vimds").enable()          - Enable the plugin
require("vimds").disable()         - Disable the plugin
require("vimds").toggle()          - Toggle plugin on/off
require("vimds").hello()           - Print hello message
require("vimds").status()          - Show plugin status
