App = {
  web3Provider: null,
  contracts: {},
  account: 0x0,
  baseURL: "http://ec2-13-59-72-72.us-east-2.compute.amazonaws.com:4000/api/v1/",
  shyftapiToken: "B1C46FAD",
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
    $.getJSON('BioData.json', function(bioDataArtifact) {
      // get the contract artifact file and use it to instantiate a truffle contract abstraction
      App.contracts.BioData = TruffleContract(bioDataArtifact);
      // set the provider for our contracts
      App.contracts.BioData.setProvider(App.web3Provider);
      // listen to events
      //App.listenToEvents();
      // retrieve the article from the contract
      return App.reloadBioData();
    });
  },

  reloadBioData: function() {
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
  },

  displayBioData: function(_id, _contractOwner, _firstName, _middleName, _lastName) {
    var articlesRow = $('#articlesRow');
    var articleTemplate = $("#articleTemplate");
    articleTemplate.find('.panel-title').text(_id);
    articleTemplate.find('.panel-contractOwner').text(_contractOwner);
    articleTemplate.find('.biodata-firstname').text(_firstName);
    articleTemplate.find('.biodata-middlename').text(_middleName);
    articleTemplate.find('.biodata-lastname').text(_lastName);
    //add this article
    $('#articlesRow').append(articleTemplate.html());
  },

  addBioData: function() {
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

  setPrimaryAdministrator: function() {
    url = App.baseURL + "trust_anchor_manager/set_primary_administrator";
    alert(App.shyftapiToken);
    $.ajax({
      url: url,
      type: "POST",
      dataType: 'json',
      data: {"trust_anchor_address":"0x43ec6d0942f7faef069f7f63d0384a27f529b062"},
      headers: {
        "X-User-Token": "B1C46FAD",
        "Accept":"application/json",
      },
      success: function (msg) {
        alert("Success: ");
      },
      error: function (jqXHR, textStatus, errorThrown) {
        alert( console.log("jqXHR: " + jqXHR) ); //Acutal error
        alert( console.log("textStatus: " + textStatus) );
        alert( console.log("errorThrown: " + errorThrown) );
      }
    });
  },

  sendTransaction: function() {
    
    url = App.baseURL + "send_transaction";
    alert(url);
    $.ajax({
      type: "POST",
      url: url,
      data: App.shyftapiToken,
      contentType: 'application/json',
      dataType: 'json',
      headers: {
        "x-user-token": "B1C46FAD",
        "Accept":"application/json"
      },
      body: {
        "gas_limit":21000000,
        "gas_price":20,
        "payload":"0x1123456789768546546168496846546546"
      },
      success: function (msg) {
        alert("Success: ");
      },
      error: function (e) {
        alert( console.log(e.responseText) ); //Acutal error
      }
    });
  }
  /*createRequest: function() {
    alert("createRequest");
    result = null;
    if (window.XMLHttpRequest) {
      alert("XMLHttpRequest");
      // FireFox, Safari, etc.
      result = new HttpRequest();
      if (typeof xmlhttp.overrideMimeType != 'undefined') {
        alert("overrideMimeType");
        result.overrideMimeType('text/xml'); // Or anything else
      }
    }
    else if (window.ActiveXObject) {
      // MSIE
      result = new ActiveXObject("Microsoft.XMLHTTP");
      alert("activexobject");
    } 
    else {
      // No known mechanism -- consider aborting the application
      alert("no known mechanism");
    }
    alert("return createRequest");
    return result;
  },

  sendTransaction: function() {
    alert("sendTransaction");
      url = App.baseURL + "send_transaction";
      var req = App.createRequest(); //create XMLHttpRequest
      alert(url);
      req.onreadystatechange = function() {
        if(req.readyState != 4) {
          alert("Not there yet");
          return; //not there yet
        }
        if(req.status != 200) {
          //handle request failed
          alert("Handle request failed");
          return;
        }
        //request successful.  Read resposne
        var resp = req.responseText;
        //process incoming data
        alert(resp);
      }
      req.open("GET", url, true);
      req.setRequestHeader("X-User-Token",App.shyftapiToken);
      req.send();
  }*/
};

$(function() {
  $(window).load(function() {
    App.init();
  });
});
