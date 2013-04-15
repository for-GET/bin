fs = require 'fs'
zlib = require 'zlib'
querystring = require 'querystring'
README = fs.readFileSync './README.md', 'utf8'
express = require 'express'

module.exports = app = express()

# HELPER - GZIP,DEFLATE,RAW
send = (text = '', req, res, next) ->
  callback = (err, result) ->
    return res.send 500, err  if err
    res.send result
  if typeof text isnt 'string'
    res.set 'Content-Type', 'application/json'  unless res.get 'Content-Type'
    text = JSON.stringify text, null, 2
  else
    res.set 'Content-Type', 'text/plain'  unless res.get 'Content-Type'
  encoding = req.headers['accept-encoding'] or ''
  encoding += ', ' + (res.get('Content-Encoding') or '')
  # FIXME replace with otw.tokenizedHeader
  if /\bdeflate\b/.test encoding
    res.set 'Content-Encoding', 'deflate'
    zlib.deflate new Buffer(text, 'utf-8'), callback
  else if /\bgzip\b/.test encoding
    res.set 'Content-Encoding', 'gzip'
    zlib.gzip new Buffer(text, 'utf-8'), callback
  else
    res.send text

# HELPER - JSON TRACE
fakeTrace = (req, res, next) ->
  trace =
    method: req.method
    uri: req.url
    httpVersion: req.httpVersion
    headers: req.headers
    body: req.body
    cookies: req.cookies
  send trace, req, res, next

# APP
app.set 'strict routing'
app.disable 'x-powered-by'
app.use (req, res, next) ->
  req.rawBody = ''
  req.setEncoding 'utf8'
  req.on 'data', (chunk) -> req.rawBody += chunk
  req.on 'end', () ->
    req.body = req.rawBody
    req.body = JSON.parse req.rawBody  if req.headers['content-type'] is 'application/json'
    req.body = querystring.parse req.rawBody  if req.headers['content-type'] is 'application/x-www-form-urlencoded'
    next()
app.use express.cookieParser()

# ORIGIN IP
app.use (req, res, next) ->
  res.set 'X-Originating-IP', req.socket.remoteAddress
  next()

# METHOD OVERRIDE
app.use (req, res, next) ->
  method = req.headers['x-http-method-override']
  return next()  unless method
  return res.send 400  if req.method isnt 'POST'
  req.method = method.toUpperCase()
  next()

# TRACE
app.use (req, res, next) ->
  return next()  unless req.method.toUpperCase() is 'TRACE'
  if req.accepts 'message/http'
    meta = ["#{req.method} #{req.url} HTTP/#{req.httpVersion}"]
    meta.push "#{header}: #{headerValue}"  for header, headerValue of req.headers
    meta = meta.join '\n'
    body = req.body or ''
    res.set 'Content-Type', 'message/http'
    send "#{meta}\n#{body}", req, res, next
  else
    fakeTrace req, res, next

# PREFER
app.use (req, res, next) ->
  # FIXME replace with otw.tokenizedHeader
  prefer = req.headers['x-prefer']
  return next()  unless prefer
  prefer = prefer.split ','
  result = {}
  for pref, prefIndex in prefer
    [key, value] = prefer[prefIndex].trim().split '='
    value or= 'true'
    if result[key]
      result[key] = [result[key]]  unless Array.isArray result[key]
      result[key].push value
    else
      result[key] = value
  req.prefer = result
  next()

# PREFER STATUS
app.use (req, res, next) ->
  status = req.prefer?.status
  return next() unless status?
  status = status[0]  if Array.isArray status
  res.status status
  next()

# PREFER COOKIE
app.use (req, res, next) ->
  cookies = req.prefer?.cookie
  return next()  unless cookies?
  cookies = [cookies]  unless Array.isArray cookies
  for cookie in cookies
    [name, value] = cookie.split '|'
    if value
      res.cookie name, value
    else
      res.clearCookie name
  next()

# PREFER WAIT
app.use (req, res, next) ->
  wait = req.prefer?.wait
  return next()  unless wait?
  wait = wait[0]  if Array.isArray wait
  setTimeout (() -> next()), wait * 1000

# PREFER RETURN-MINIMAL
app.use (req, res, next) ->
  returnMinimal = req.prefer?['return-minimal']
  returnMinimal = returnMinimal[0]  if Array.isArray returnMinimal
  return next()  unless returnMinimal is 'true'
  res.send()

# PREFER RETURN-REQUEST-BODY
app.use (req, res, next) ->
  returnRequestBody = req.prefer?['return-request-body']
  returnRequestBody = returnRequestBody[0]  if Array.isArray returnRequestBody
  return next()  unless returnRequestBody is 'true'
  res.set 'Content-Type', req.get 'Content-Type'  if req.get 'Content-Type'
  send req.rawBody, req, res, next

# PREFER RETURN-REQUEST
app.use (req, res, next) ->
  returnRequest = req.prefer?['return-request']
  returnRequest = returnRequest[0]  if Array.isArray returnRequest
  return next()  unless returnRequest is 'true'
  return next()  unless req.get('Content-Type') is 'application/json' and req.body?
  res.status req.body.status  if req.body.status?
  headers = req.body.headers or {}
  res.set header, headerValue  for header, headerValue of headers
  return next()  unless req.body.body?
  send req.body.body, req, res, next

# ROUTES
app.use app.router
app.all '*', (req, res, next) ->
  if req.accepts 'text/plain'
    res.set 'Content-Type', 'text/plain'
    send README, req, res, next
  else if req.accepts 'application/json'
    fakeTrace req, res, next
  else
    returnRepr = req.prefer?['return-representation']
    returnRepr = returnRepr[0]  if Array.isArray returnRepr
    return res.send()  unless returnRepr is 'true'
    fakeTrace req, res, next
