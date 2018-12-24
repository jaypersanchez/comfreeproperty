App = {
  web3Provider: null,
  contracts: {},
  account: 0x0,
  baseURL: "http://ec2-13-59-72-72.us-east-2.compute.amazonaws.com:4000/api/v1/",
  loading: false,

  init: function() {
    return App.initWeb3();
  },

  initWeb3: function() {
    // initialize web3
    if(typeof web3 !== 'undefined') {
      //reuse the provider of the Web3 object injected by Metamask
      App.web3Provider = web3.currentProvider;
    } else {
      //create a new provider and plug it directly into our local node
      App.web3Provider = new Web3.providers.HttpProvider('http://127.0.0.1:8545');
    }
    web3 = new Web3(App.web3Provider);
    App.displayAccountInfo();
    return App.initContract();
  },

  displayAccountInfo: function() {
    //Must be setup in Metamask or some other wallet
    web3.eth.getCoinbase(function(err, account) {
      if (err === null) { 
        App.account = account;
        $("#account").text(App.account);
        web3.eth.getBalance(App.account, function(err, balance) {
          if (err === null) {
            $("#accountBalance").text(web3.fromWei(balance, "ether") + " ETH");
          }
        });
      }
    });
  },

  initContract: function() {
    /*$.getJSON('BioData.json', function(bioDataArtifact) {
      // get the contract artifact file and use it to instantiate a truffle contract abstraction
      App.contracts.BioData = TruffleContract(bioDataArtifact);
      // set the provider for our contracts
      App.contracts.BioData.setProvider(App.web3Provider);
      // listen to events
      //App.listenToEvents();
      // retrieve the article from the contract
      return App.reloadBioData();
    });*/
  },

  createOffer: function() {
  },

  /*reloadBioData: function() {
    //avoid re-entry
    if(App.loading) {
      return;
    }
    App.loading = true;
    // refresh account information because the balance might have changed
    App.displayAccountInfo();
    var BioDataInstance;
    
    App.contracts.BioData.deployed().then(function(instance) {
      BioDataInstance = instance;
      return BioDataInstance.getBioData();
    }).then(function(bioDataIds) {
      // retrieve the article placeholder and clear it
      $('#articlesRow').empty();
      for(var i =0; i < bioDataIds.length; i++) {
        var bioDataId = bioDataIds[i];
        BioDataInstance.biodatalist(bioDataId.toNumber()).then(function(_bioData) {
            App.displayBioData(_bioData[0], _bioData[1], _bioData[2], _bioData[3], _bioData[4]);
        });
      }
      App.loading = false;
      // add this article
      //$('#articlesRow').append(articleTemplate.html());
    }).catch(function(err) {
      App.loading = false;
      console.error(err.message);
    });
  },*/

  /*displayBioData: function(_id, _contractOwner, _firstName, _middleName, _lastName) {
    var articlesRow = $('#articlesRow');
    var articleTemplate = $("#articleTemplate");
    articleTemplate.find('.panel-title').text(_id);
    articleTemplate.find('.panel-contractOwner').text(_contractOwner);
    articleTemplate.find('.biodata-firstname').text(_firstName);
    articleTemplate.find('.biodata-middlename').text(_middleName);
    articleTemplate.find('.biodata-lastname').text(_lastName);
    //add this article
    $('#articlesRow').append(articleTemplate.html());
  },*/

  /*addBioData: function() {
    // retrieve screen data
    var _first_name = $('#first_name').val();
    var _middle_name = $('#middle_name').val();
    var _last_name = $('#last_name').val();
    //alert(_first_name + " " + _middle_name + " " + _last_name + " " + App.account );
    App.contracts.BioData.deployed().then(function(instance) {
      return instance.setBioData(_first_name, _middle_name, _last_name, {
        from: App.account,
        gas: 500000
      });
    }).then(function(result) {
      //alert("invoke reload");
      App.reloadBioData();
    }).catch(function(err) {
      alert(console.error("Application Error: " + err.message));
      //console.error(err);
    });
  },*/

  bindEvents: function() {
    $(document).on('click', '.btn-adopt', App.handleAdopt);
  },

  markAdopted: function(adopters, account) {
    /*
     * Replace me...
     */
  },

  handleAdopt: function(event) {
    event.preventDefault();

    var petId = parseInt($(event.target).data('id'));

    /*
     * Replace me...
     */
  },

};

$(function() {
  $(window).load(function() {
    App.init();
  });
});
