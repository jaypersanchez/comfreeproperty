//Express related libraries
const express = require('express');
var Promise = require('promise');
var session = require('express-session');
var router = express.Router();
const url = require('url');
const querystring = require('querystring');
var server = express();
require('dotenv').config();
const express_host = process.env.EXPRESS_HOST;
const express_port = process.env.EXPRESS_PORT;

server.use(express.static('js'));
server.use(express.static('css'));
server.use(express.static('src'));
server.use(express.static('contracts'));


/*
* Process default root index file
*/
server.get('/', (req, res) => {
  res.sendFile(__dirname + '/src/index.html');
});


server.listen(express_port, () => console.log(`Server listening at http://${express_host}:${express_port}`));