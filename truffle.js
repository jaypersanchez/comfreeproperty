var HDWalletProvider = require("truffle-hdwallet-provider");
//var mnemonic = "parrot guide ribbon seed lady easy dizzy genre vote praise famous help";
var mnemonic = "flee sadness churn mixture harbor hurry helmet grid valve frame seat voice";
module.exports = {
  rpc: {
    host: "localhost",
    port: '8545'
  },
  networks: {
    ganache_cli: {
      host: "localhost",
      port: 8545,
      network_id: "*" // Match any network id
    },
    ganache_ui: {
      host: "localhost",
      port: 7545,
      network_id: "*"
    },
  },
  mocha: {
    useColors: true
  },
  compilers: {
      solc: {
        version: "0.6.0",
      }
  }
};
