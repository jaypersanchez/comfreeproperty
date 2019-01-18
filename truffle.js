module.exports = {
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
    }
  }
};
