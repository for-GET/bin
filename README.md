# HyperREST bin

A simple HTTP service with controlled behaviour, inspired by [httpbin](https://github.com/kennethreitz/httpbin).

# Install & run

```bash
npm install hyperrest-bin
./hyperrest-bin # or PORT=1337 ./hyperrest-bin
```

# Usage

```bash
# METHOD
curl                                                          http://127.0.0.1:1337   # README.md
curl                                                          http://127.0.0.1:1337/* # README.md
curl -XPOST                                                   http://127.0.0.1:1337   # README.md
curl -XPOST -H"Accept: application/json"                      http://127.0.0.1:1337   # JSON TRACE

# TRACE, METHOD OVERRIDE
curl -XTRACE                                                  http://127.0.0.1:1337 # message/http TRACE
curl -XPOST  -H"X-HTTP-Method-Override: TRACE"                http://127.0.0.1:1337 # message/http TRACE still
curl -XTRACE -H"Accept: application/json"                     http://127.0.0.1:1337 # JSON TRACE

# ORIGINATING IP
# see response

# PREFER
curl -H"X-Prefer: status=404"                                 http://127.0.0.1:1337 # 404 Not Found
curl -H"X-Prefer: cookie=name1|v, cookie=name2|v"             http://127.0.0.1:1337 # Set cookies "name1" and "name2"
curl -H"X-Prefer: cookie=name1"                               http://127.0.0.1:1337 # Delete cookie "name1"
curl -H"X-Prefer: wait=10"                                    http://127.0.0.1:1337 # Wait 10 seconds, then README.md

# RESPOND via request
curl -XPOST \
     -H"Content-Type: application/json" \
     -H"X-Prefer: return-request" \
     -d'{"status":"200", \
         "headers":{"Content-Type":"text/plain"}, \
         "body":"TEXT"
        }'                                                    http://127.0.0.1:1337 # return 200, etc.

# "LEGACY"?
curl -H"X-Prefer: return-minimal"                             http://127.0.0.1:1337 # 200 OK, but no README.md
curl -H"X-Prefer: return-representation" -H"Accept:text/html" http://127.0.0.1:1337 # return README.md by force
curl -XPOST -H"X-Prefer: return-request-body" -dkey=value     http://127.0.0.1:1337 # return "key=value"
```

# License

Apache 2.0
