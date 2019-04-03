// BASE SETUP
// =============================================================================

var express    = require('express');        // call express
var app        = express();                 // define our app using express
var bodyParser = require('body-parser');

//Mongoose setup
var mongoose = require('mongoose');
mongoose.connect('mongodb://localhost:27017/shyftapidb');

var Shyft = require('./api/models/shyftModel');
var Onboarding = require('./api/models/onboardingModel');

// configure app to use bodyParser()
// this will let us get the data from a POST
app.use(bodyParser.urlencoded({ extended: true }));
app.use(bodyParser.json());

var port = process.env.PORT || 8080;        // set our port

// ROUTES FOR OUR API
// =============================================================================
var router = express.Router();              // get an instance of the express Router

//middleware to use for all request
router.use(function(req, res, next) {
  console.log('Processing transaction: ' + req.query.walletaddress);
  next(); //make sure we got ot the next routes and don't stop here
});

// test route to make sure everything is working (accessed at GET http://localhost:8080/api)
router.get('/', function(req, res) {
    res.json({ message: 'SHYFT INTERNATIONAL NETWORK SERVER SIDE API' });   
});

// more routes for our API will happen here
var routes = require('./api/routes/shyftApiRoutes')
routes(app);


// REGISTER OUR ROUTES -------------------------------
// all of our routes will be prefixed with /api
app.use('/', router);

app.use(function(req,res) {
  res.status(404).send({url: req.originalUrl + ' not found'})
});

// START THE SERVER
// =============================================================================
app.listen(port);
console.log('Shyft Network up and running on port ' + port);