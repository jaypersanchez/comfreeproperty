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
      App.web3Provider = new Web3.providers.HttpProvider('http://127.0.0.1:7545');
    }
    web3 = new Web3(App.web3Provider);
    //App.displayAccountInfo();
    return App.initContract();
  },

  initContract: function() {
    $.getJSON('OfferContract.json', function(offerContractArtifact) {
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
    $.getJSON('OfferContract.json', function(offerContractArtifact) {
      // get the contract artifact file and use it to instantiate a truffle contract abstraction
      App.contracts.OfferContract = TruffleContract(offerContractArtifact);
      // set the provider for our contracts
      App.contracts.OfferContract.setProvider(App.web3Provider);
      // retrieve screen data
      var _buyeraddress = $('#buyeraddress').val();
      var _selleraddress = $('#selleraddress').val();
      //convert value to ether
      var _etheramount = web3.toWei(parseFloat($('#etheramount').val() || 0),"ether");
      alert(_buyeraddress + "::" + _selleraddress + "::" + _etheramount);
      App.contracts.OfferContract.deployed().then(function(instance) {
        alert("send offer to blockchain");
        return instance.createOfferContract(_buyeraddress, _selleraddress, 1,1,1,_etheramount,false, {
          from: _buyeraddress,
          gas: 500000
        });
      }).then(function(result) {
        console.log(result);
        //alert("result");
        //forward to list of active offers
        
        App.reloadOfferContractList();
      }).catch(function(err) {
        console.log(err.message);
        alert(console.error("Application Error: " + err.message));
      });
    });
  },

  acceptOffer: function() {
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
    //App.displayAccountInfo();
    $.getJSON('OfferContract.json', function(offerContractArtifact) {
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
