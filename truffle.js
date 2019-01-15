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
    }
  }
};
