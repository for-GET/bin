fs = require 'fs'
zlib = require 'zlib'
querystring = require 'querystring'
README = fs.readFileSync __dirname + '/README.md', 'utf8'
express = require 'express'
js2xml = require 'js2xmlparser'
xml2js = require 'xml2js'
_ = require 'lodash'
httpWell = require 'know-your-http-well'
cookieParser = require 'cookie-parser'

module.exports = app = express()

# HELPER - CONTENT-TYPE NEGOCIATION
# FIXME replace with otw
negociateContent = (req, res, body) ->
  accept = req.headers.accept or ''
  return ['text/plain', body]  if typeof body is 'string'
  return ['application/xml', js2xml 'response', body]  if /\bxml\b/.test accept
  ['application/json', JSON.stringify body, null, 2]

# HELPER - ENCODING NEGOCIATION
# FIXME replace with otw
negociateEncoding = (req, res, body, callback) ->
  encoding = req.headers['accept-encoding'] or ''
  encoding += ', ' + (res.get('Content-Encoding') or '')
  if /\bdeflate\b/.test encoding
    zlib.deflate new Buffer(body, 'utf-8'), (err, result) ->
      callback err, ['deflate', result]
  else if /\bgzip\b/.test encoding
    zlib.gzip new Buffer(body, 'utf-8'),  (err, result) ->
      callback err, ['gzip', result]
  else
    callback null, [undefined, body]

# HELPER - GZIP,DEFLATE,RAW
send = (body = '', req, res, next) ->
  [contentType, body] = negociateContent req, res, body
  res.set 'Content-Type', contentType  unless res.get 'Content-Type'
  negociateEncoding req, res, body, (err, [encoding, body]) ->
    return res.send 500, err  if err
    res.set 'Content-Encoding', encoding  unless res.get 'Content-Encoding'
    res.send body

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


# know-your-http-well
hitFun = {}
hitFun.method = (value) ->
  _.findWhere httpWell.methods, (method) ->
    method.method.toUpperCase() is value.toUpperCase()
hitFun.header = (value) ->
  _.findWhere httpWell.headers, (header) ->
    header.header.toLowerCase() is value.toLowerCase()
hitFun.statusCode = (value) ->
  _.findWhere httpWell.statusCodes, (statusCode) ->
    statusCode.code is value
hitFun.relation = (value) ->
  _.findWhere httpWell.relations, (relation) ->
    relation.relation.toLowerCase() is value.toLowerCase()

app.get '/spec/:value', (req, res, next) ->
  specs = [
    'method'
    'header'
    'statusCode'
    'relation'
  ]
  for spec in specs
    hit = hitFun[spec] req.params.value
    return res.redirect hit.spec_href  if hit
  res.send 404

app.get '/:spec/:value', (req, res, next) ->
  return next()  unless req.params.spec in [
    'statusCode'
    'method'
    'header'
    'relation'
  ]
  hit = hitFun[req.params.spec] req.params.value
  return res.redirect hit.spec_href  if hit
  res.send 404

# BODY, COOKIE PARSERS
app.use (req, res, next) ->
  req.rawBody = ''
  req.setEncoding 'utf8'
  req.on 'data', (chunk) -> req.rawBody += chunk
  req.on 'end', () ->
    req.body = req.rawBody
    if /\bjson\b/.test(req.headers['content-type'] or '')
      try
        req.body = JSON.parse req.rawBody
      catch e
        return res.send 400
      next()
    else if /\bxml\b/.test(req.headers['content-type'] or '')
      try
        xml2js.parseString req.rawBody, (err, result) ->
          return res.send 400  if err
          req.body = result
          next()
      catch e
        return res.send 400
    else if req.headers['content-type'] is 'application/x-www-form-urlencoded'
      try
        req.body = querystring.parse req.rawBody
      catch e
        return res.send 400
  next()
app.use cookieParser()

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
  prefer = req.headers['prefer'] or req.headers['x-prefer']
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
  res.set 'Preference-Applied', "status=#{status}"
  res.status status
  next()

# PREFER COOKIE
app.use (req, res, next) ->
  cookies = req.prefer?.cookie
  return next()  unless cookies?
  cookies = [cookies]  unless Array.isArray cookies
  res.set 'Preference-Applied', ("cookie=#{cookie}"  for cookie in cookies).join ', '
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
  res.set 'Preference-Applied', "wait=#{wait}"
  setTimeout (() -> next()), wait * 1000

# PREFER RETURN-MINIMAL
app.use (req, res, next) ->
  returnMinimal = req.prefer?['return-minimal']
  returnMinimal = returnMinimal[0]  if Array.isArray returnMinimal
  return next()  unless returnMinimal is 'true'
  res.set 'Preference-Applied', 'return-minimal'
  res.send()

# PREFER RETURN-REQUEST
app.use (req, res, next) ->
  returnRequest = req.prefer?['return-request']
  returnRequest = returnRequest[0]  if Array.isArray returnRequest
  return next()  unless returnRequest is 'true'
  return next()  unless /\bjson\b/.test(req.headers['content-type'] or '') and req.body?
  res.set 'Preference-Applied', 'return-request'
  res.status req.body.status  if req.body.status?
  headers = req.body.headers or {}
  res.set header, headerValue  for header, headerValue of headers
  return next()  unless req.body.body?
  send req.body.body, req, res, next

# ...
app.all '*', (req, res, next) ->
  if req.accepts 'text/plain'
    res.set 'Content-Type', 'text/plain'
    send README, req, res, next
  else if req.accepts('application/json') or req.accepts('application/xml')
    fakeTrace req, res, next
  else
    returnRepr = req.prefer?['return-representation']
    returnRepr = returnRepr[0]  if Array.isArray returnRepr
    return res.send()  unless returnRepr is 'true'
    fakeTrace req, res, next
