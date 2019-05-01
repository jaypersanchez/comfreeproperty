var ConvertLib = artifacts.require("./ConvertLib.sol");
var ComfreeToken = artifacts.require("./ComfreeToken.sol");
var ComfreePropertyDataModel = artifacts.require("./ComfreePropertyDataModel.sol");
var OfferContract = artifacts.require("./OfferContract.sol");
var SaleConditionContract = artifacts.require("./SaleConditionContract.sol");
var EscrowContract = artifacts.require("./EscrowContract.sol");

module.exports = function(deployer) {
  deployer.deploy(ConvertLib);
  deployer.deploy(ComfreeToken, 500);
  deployer.deploy(ComfreePropertyDataModel);
  deployer.deploy(OfferContract);
  deployer.deploy(SaleConditionContract);
  deployer.deploy(EscrowContract);
};
