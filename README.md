# HyperREST bin

A simple HTTP service with controlled behaviour, inspired by [httpbin](https://github.com/kennethreitz/httpbin).

The service makes use of HTTP headers, and predominantly [X-Prefer](http://tools.ietf.org/html/draft-snell-http-prefer-18), in order to allow the client to control server behaviour.


## Install & run

```bash
npm install hyperrest-bin
hyperrest-bin                                                                         # or PORT=1337 hyperrest-bin
```


## Usage

```bash
curl                                                          http://127.0.0.1:1337   # README.md
curl                                                          http://127.0.0.1:1337/* # README.md on any path
curl -XPOST                                                   http://127.0.0.1:1337   # README.md
curl -XPOST -H"Accept: application/json"                      http://127.0.0.1:1337   # JSON TRACE
curl -XPOST -H"Accept: application/xml"                       http://127.0.0.1:1337   # XML TRACE

                                                                                      # TRACE, METHOD OVERRIDE
curl -XTRACE                                                  http://127.0.0.1:1337   # message/http TRACE
curl -XPOST  -H"X-HTTP-Method-Override: TRACE"                http://127.0.0.1:1337   # message/http TRACE still
curl -XTRACE -H"Accept: application/json"                     http://127.0.0.1:1337   # JSON TRACE
curl -XTRACE -H"Accept: application/xml"                      http://127.0.0.1:1337   # XML TRACE

                                                                                      # ORIGINATING IP
                                                                                      # see response

                                                                                      # GZIP/DEFLATE
curl -H"Accept-Encoding: gzip,deflate"                        http://127.0.0.1:1337   # GZIP README.md

                                                                                      # PREFER (as per registered preferences)
curl -H"X-Prefer: status=404"                                 http://127.0.0.1:1337   # 404 Not Found
curl -H"X-Prefer: wait=10"                                    http://127.0.0.1:1337   # wait 10 seconds, then README.md
curl -H"X-Prefer: return-minimal"                             http://127.0.0.1:1337   # 200 OK, but no README.md
curl -H"X-Prefer: return-representation" -H"Accept:text/html" http://127.0.0.1:1337   # return README.md by force

                                                                                      # PREFER (as per extensions of preferences)
curl -H"X-Prefer: cookie=name1|v, cookie=name2|v"             http://127.0.0.1:1337   # set cookies "name1" and "name2"
curl -H"X-Prefer: cookie=name1"                               http://127.0.0.1:1337   # delete cookie "name1"

                                                                                      # PREFER response as defined in the request body
curl -XPOST \
     -H"Content-Type: application/json" \
     -H"X-Prefer: return-request" \
     -d'{"status":"200", \
         "headers":{"Content-Type":"text/plain"}, \
         "body":"TEXT"
        }'                                                    http://127.0.0.1:1337   # return 200, etc.

                                                                                      # PREFER response with request body (LEGACY; return-request is much more versatile)
curl -XPOST -H"X-Prefer: return-request-body" -dkey=value     http://127.0.0.1:1337   # return "key=value"


                                           # https://github.com/andreineculau/know-your-http-well
curl http://127.0.0.1:1337/method/{method} # Specification for HTTP Status Code
curl http://127.0.0.1:1337/header/{header} # Specification for HTTP Header
curl http://127.0.0.1:1337/status/{code}   # Specification for HTTP Method
curl http://127.0.0.1:1337/rel/{rel}       # Specification for HTTP Relation
```


## License

[Apache 2.0](LICENSE).
