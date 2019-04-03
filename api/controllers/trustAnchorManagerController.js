'use strict';
const fs = require('fs');
const web3 = require('web3');
const Tx = require('ethereumjs-tx');
const solc = require('solc');
const path = require('path');
/*Infura HttpProvider Endpoint
web3js = new web3(new web3.providers.HttpProvider("https://rinkeby.infura.io/YOUR_API_KEY"));
*/
//Ganache-CLI
const web3js = new web3(new web3.providers.HttpProvider('http://localhost:8545'));
var mongoose = require('mongoose'),
  Shyft = mongoose.model('Shyft');

//core contracts
var trustAnchorManager = require('../shyftcontractsjs/TrustAnchorManager');

exports.set_primary_administrator = function(req, res) {
  var walletaddress = req.query.walletaddress;
  var onboardClient = new Shyft(req.body);
  web3js.eth.getAccounts().then(console.log);
  onboardClient.save(function(err, task) {
    if (err)
      res.send(err);
    res.json(task);
  });
};

exports.set_administrator = function(req, res) {

};

exports.onboard_trust_anchor = function(req, res) {
  //instantiate trustAnchorManager
  const filepath = path.resolve(__dirname, '../contracts','TrustAnchorManager.sol').toString();
  const contractArtifact = fs.readFileSync(filepath, 'UTF-8'); 
  const abi = solc.compile(contractArtifact,1).contracts[':TrustAnchorManager'].interface;
  const TAMInstance = new web3js.eth.contract(abi);
  var onboardClient = new Shyft(req.body);
  onboardClient.save(function(err, task) {
    if (err) {
      res.send(err);
    }
    else {
      //var walletaddress = req.query.walletaddress;
      //var result = TAMInstance.setPrimaryAdministrator(walletaddress).then(console.log);
      res.json(task);
    }
    
  });
  //listOfAccounts = web3js.eth.getAccounts();
  //invoke setup primary administrator - coinbase
  //invoke setup administrator - wallet address B, C
  //invoke onboard
  //invoke verify


};

