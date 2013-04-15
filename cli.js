#!/usr/bin/env node
/*jshint node:true*/
require('coffee-script');

var app = require('./index_'),
    port = process.env.PORT || 1337;

console.log('Server started on http://0.0.0.0:' + port);
app.listen(port);
