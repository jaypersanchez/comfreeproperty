var ConvertLib = artifacts.require("./ConvertLib.sol");
var MetaCoin = artifacts.require("./MetaCoin.sol");
var OfferContract = artifacts.require("./OfferContract.sol");
var SaleConditionContract = artifacts.require("./SaleConditionContract.sol");

module.exports = function(deployer) {
  deployer.deploy(ConvertLib);
  deployer.link(ConvertLib, MetaCoin);
  deployer.deploy(MetaCoin);
  deployer.deploy(OfferContract);
  deployer.deploy(SaleConditionContract);
  /*deployer.then(function() {
    return OfferContract.deployed();
  }).then(function(instance) {
    deployer.deploy(SaleConditionContract, OfferContract.address);
  });*/
};
