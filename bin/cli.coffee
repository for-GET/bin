#!/usr/bin/env node

app = require '../'

port = process.env.PORT or 1337
console.log "Server listening on http://0.0.0.0:#{port}"
app.listen port
