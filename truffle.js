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
    buyer1:{
      host: "localhost",
      port: 7545,
      network_id: "*",
      from: "0xB3E68458CF37ee946eABF8EbFFd8fb78811A202e"
    },
    rinkeby: {
      provider: new HDWalletProvider(mnemonic,"https://rinkeby.infura.io/v3/051f0a087fcb48ce8371eab1491f7e93"),
      network_id: 4,
      gas: 6995427  
      
    }
  }
};
