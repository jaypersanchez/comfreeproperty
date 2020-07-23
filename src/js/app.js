App = {
  web3Provider: null,
  web3: null,
  contracts: {},
  account: 0x0,
  baseURL: "http://ec2-13-59-72-72.us-east-2.compute.amazonaws.com:4000/api/v1/",
  loading: false,

  init: function() {
    return App.initWeb3();
  },

  initWeb3: function() {


    if (typeof window !== 'undefined' && typeof window.web3 !== 'undefined') {
      // We are in the browser and metamask is running.
      //Note: change to window.web3.currentProvider.enable()
      web3 = new Web3(window.web3.currentProvider.enable());
    } else {
      // We are on the server *OR* the user is not running metamask
      web3Provider = new Web3.providers.HttpProvider('http://localhost:8545');
      web3 = new Web3(web3Provider);
      App.web3Provider=web3.currentProvider;
    }
    App.displayAccountInfo();
    return App.initContract();
  },

  initContract: function() {
    console.log("init contract");
    $.getJSON('contracts/OfferContract.json', function(offerContractArtifact) {
      // get the contract artifact file and use it to instantiate a truffle contract abstraction
      App.contracts.OfferContract = TruffleContract(offerContractArtifact);
      // set the provider for our contracts
      App.contracts.OfferContract.setProvider(App.web3Provider);
      // listen to events
      //App.listenToEvents();
      // retrieve the article from the contract
      return App.reloadOfferContractList();
    });
  },

  createOffer: function() {
    $.getJSON('contracts/OfferContract.json', function(offerContractArtifact) {
      // get the contract artifact file and use it to instantiate a truffle contract abstraction
      App.contracts.OfferContract = TruffleContract(offerContractArtifact);
      // set the provider for our contracts
      App.contracts.OfferContract.setProvider(App.web3Provider);
      // retrieve screen data
      var _buyeraddress = $('#buyeraddress').val();
      var _selleraddress = $('#selleraddress').val();
      //convert value to ether
      var _etheramount = web3.fromWei(parseFloat($('#etheramount').val() || 0),"ether");
      App.contracts.OfferContract.deployed().then(function(instance) {
        return instance.createOfferContract(_buyeraddress, _selleraddress, 1,1,1,_etheramount,false);
      }).then(function(result) {
        console.log(`Offer Created Result ${result}`);
        App.reloadOfferContractList();
      }).catch(function(err) {
        console.log(`Failed to send offer to contract ${err.message}`);
        alert(console.error(`Failed to send offer to contract ${err.message}`));
      });
    });
  },

  acceptOffer: function() {
    //set Offer to accepted state
    
    //alert("Offer Accepted!");
    $.getJSON('SaleConditionContract.json', function(saleConditionContractArtifact) {
      App.contracts.SaleConditionContract = TruffleContract(offerContractArtifact);
      // set the provider for our contracts
      App.contracts.SaleConditionContract.setProvider(App.web3Provider);
      var saleConditionContractInstance;
      //App.contracts.SaleConditionContract.deployed().then
    });
  },
  /*
  * Displays only active offers(offers yet to be accepted)
  */
  reloadOfferContractList: function() {
    //avoid re-entry
    if(App.loading) {
      return;
    }
    App.loading = true;
    // refresh account information because the balance might have changed
    App.displayAccountInfo();
    $.getJSON('contracts/OfferContract.json', function(offerContractArtifact) {
      App.contracts.OfferContract = TruffleContract(offerContractArtifact);
    // set the provider for our contracts
    App.contracts.OfferContract.setProvider(App.web3Provider);
    var offerContractInstance;
    App.contracts.OfferContract.deployed().then(function(instance) {
      offerContractInstance = instance;
      return offerContractInstance.getActiveOffers();
    }).then(function(bioDataIds) {
      // retrieve the article placeholder and clear it
      $('#activeOffersRow').empty();
      for(var i =0; i < bioDataIds.length; i++) {
        var bioDataId = bioDataIds[i];
        offerContractInstance._listOfOfferContracts(bioDataId.toNumber()).then(function(_bioData) {
            /*
            * uint id, address buyerAddress,address sellerAddress
            * uint offerDate, uint expiredDate, uint currentDate
            * uint offerAmount, bool accepted;
            */
            if(!_bioData[7] ) {
              App.displayData(_bioData[0], _bioData[1], _bioData[2], _bioData[6], _bioData[7]);
            }
        });
      }
      App.loading = false;
      // add this article
      //$('#articlesRow').append(articleTemplate.html());
    }).catch(function(err) {
      App.loading = false;
      console.error(err.message);
    });
    });
    
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

  displayData: function(_id, _buyeraddress, _selleraddress, _offeramount, _offeraccepted) {
    var activeOffersRow = $('#activeOffersRow');
    var displayTemplate = $("#displayTemplate");
    displayTemplate.find('.panel-title').text("Active Offers");
    displayTemplate.find('.recordid').text(_id);
    displayTemplate.find('.buyeraddress').text(_buyeraddress);
    displayTemplate.find('.selleraddress').text(_selleraddress);
    displayTemplate.find('.offeramount').text( web3.fromWei(_offeramount,"ether") );
    displayTemplate.find('.offeraccepted').text(_offeraccepted);
    //alert(_offeraccepted);
    //add data
    $('#activeOffersRow').append(displayTemplate.html());
  },

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
