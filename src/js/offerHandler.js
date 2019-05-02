web3Provider =  null,
  contracts= {},
  account= 0x0,
  baseURL= "http://ec2-13-59-72-72.us-east-2.compute.amazonaws.com:4000/api/v1/",
  loading= false

var listOfActiveOffers = new Array();

class Offers {
    constructor(_id, _header_banner, _property_address, _property_feature, _listed_price, _offered_price) {
        this.id = _id; //from property ID
        this.id_offer = "activeoffer-" + Math.floor(Math.random()*1972); 
        this.header_banner = _header_banner;
        this.property_address = _property_address;
        this.property_feature = _property_feature;
        this.listing_price = _listed_price;
        this.offered_price = _offered_price;
        this.hasOffer = false;
    }
}

class ActiveOfferListingUI {

    addPropertyToActiveOfferList(offer) {
        const list = document.getElementById('property-list');
        // Create tr element
        const row = document.createElement('tr');
        // Insert cols
        row.innerHTML = `
            <td>${offer.id} - ${offer.id_offer}</td>
            <td>${offer.property_address}</td>
            <td>${offer.listing_price}</td>
            <td><a href="activeEscrows.html?propertyid=${offer.id}&idoffer=${offer.id_offer}&address=${offer.property_address}&feature=${offer.property_feature}&price=${offer.listing_price}&offer=${offer.offered_price}">${offer.offered_price}</a></td>
            <td><a href="#" class="delete">Decline<a></td>
            `;
        //alert("UInew offer: " + offer.id + ":" + offer.id_offer + ":" + offer.property_address + ":" + offer.listed_price + ":" + offer.offered_price );
        list.appendChild(row);
        listOfActiveOffers.push(offer);
        window.localStorage.setItem(offer.id_offer, JSON.stringify(listOfActiveOffers));
    }

    showAlert(message, className) {
        // Create div
        const div = document.createElement('div');
        // Add classes
        div.className = `alert ${className}`;
        // Add text
        div.appendChild(document.createTextNode(message));
        // Get parent
        const container = document.querySelector('.container');
        // Get form
        const form = document.querySelector('#book-form');
        // Insert alert
        container.insertBefore(div, form);

        // Timeout after 3 sec
        setTimeout(function(){
        document.querySelector('.alert').remove();
        }, 3000);
    }

    removeFromList(target) {
        if(target.className === 'delete') {
            target.parentElement.parentElement.remove();
        }
    }

    clearFields() {
        document.getElementById('property_id').value = '';
        document.getElementById('headerbanner').value = '';
        document.getElementById('address').value = '';
        document.getElementById('features').value = '';
        document.getElementById('listing_price').value = '';
        document.getElementById('offer_price').value = '';
    }

}

class StoreProperties {
    
    static getActiveOffers() {
        let activeoffers;
        if(window.localStorage.getItem('activeoffers') === null) {
            activeoffers = [];
            
        }
        else {
            activeoffers = JSON.parse(window.localStorage.getItem('activeoffers'));
            
        }
        //alert("lenght: " + activeoffers.length);
        return activeoffers;
    }

    static addPropertyToActiveOfferList(_offer) {
        const activeoffers = StoreProperties.getActiveOffers();
        activeoffers.push(_offer);
        window.localStorage.setItem('activeoffers', JSON.stringify(activeoffers));
    }

    static displayActiveOffers() {
        const activeoffers = StoreProperties.getActiveOffers();
        activeoffers.forEach(function(offer){
                // Instantiate UI
                const activeOfferListingUI = new ActiveOfferListingUI();

                // Add active offer
                activeOfferListingUI.addPropertyToActiveOfferList(offer);
        });
        
    }

    static getActiveOffersById(_property_id) {
        /*const activeoffers = StoreProperties.getActiveOffers();
        activeoffers.forEach(function(activeoffer){
            //alert("ID: " + property.id_datestamp);
            if(activeoffer.id === _property_id) {
                document.getElementById("property_id").value = property.id_datestamp;
                document.getElementById('headerbanner').value = property.header_banner;
                document.getElementById('address').value = property.property_address;
                document.getElementById('features').value = property.property_feature;
                document.getElementById('listing_price').value = property.listing_price;
            }
        });*/
    }
}//StoreProperties

var getWalletAccount = function(index) {
            return web3.eth.accounts[index];
}//getWalletAccount

var createOfferContract = function(offer) {
    //console.log("create offer contract instance");
    var file = "../abi_src/offerContract.abi";
    
            var offerContractABI = web3.eth.contract([
	{
		"constant": false,
		"inputs": [
			{
				"name": "_id",
				"type": "uint256"
			},
			{
				"name": "_value",
				"type": "bool"
			}
		],
		"name": "accept",
		"outputs": [
			{
				"name": "",
				"type": "bool"
			}
		],
		"payable": false,
		"stateMutability": "nonpayable",
		"type": "function"
	},
	{
		"constant": false,
		"inputs": [
			{
				"name": "_buyerAddress",
				"type": "address"
			},
			{
				"name": "_sellerAddress",
				"type": "address"
			},
			{
				"name": "_offerDate",
				"type": "uint256"
			},
			{
				"name": "_currentDate",
				"type": "uint256"
			},
			{
				"name": "_expiredDate",
				"type": "uint256"
			},
			{
				"name": "_offerAmount",
				"type": "uint256"
			},
			{
				"name": "_accepted",
				"type": "bool"
			}
		],
		"name": "createOfferContract",
		"outputs": [
			{
				"name": "_result",
				"type": "uint256"
			}
		],
		"payable": false,
		"stateMutability": "nonpayable",
		"type": "function"
	},
	{
		"constant": false,
		"inputs": [
			{
				"name": "_id",
				"type": "uint256"
			}
		],
		"name": "isOfferExpired",
		"outputs": [
			{
				"name": "_value",
				"type": "bool"
			}
		],
		"payable": false,
		"stateMutability": "nonpayable",
		"type": "function"
	},
	{
		"constant": false,
		"inputs": [
			{
				"name": "number",
				"type": "uint256"
			}
		],
		"name": "processData",
		"outputs": [
			{
				"name": "",
				"type": "bool"
			}
		],
		"payable": false,
		"stateMutability": "nonpayable",
		"type": "function"
	},
	{
		"inputs": [],
		"payable": false,
		"stateMutability": "nonpayable",
		"type": "constructor"
	},
	{
		"constant": true,
		"inputs": [
			{
				"name": "",
				"type": "uint256"
			}
		],
		"name": "_listOfOfferContracts",
		"outputs": [
			{
				"name": "id",
				"type": "uint256"
			},
			{
				"name": "buyerAddress",
				"type": "address"
			},
			{
				"name": "sellerAddress",
				"type": "address"
			},
			{
				"name": "offerDate",
				"type": "uint256"
			},
			{
				"name": "expiredDate",
				"type": "uint256"
			},
			{
				"name": "currentDate",
				"type": "uint256"
			},
			{
				"name": "offerAmount",
				"type": "uint256"
			},
			{
				"name": "accepted",
				"type": "bool"
			}
		],
		"payable": false,
		"stateMutability": "view",
		"type": "function"
	},
	{
		"constant": true,
		"inputs": [],
		"name": "getActiveOffers",
		"outputs": [
			{
				"name": "",
				"type": "uint256[]"
			}
		],
		"payable": false,
		"stateMutability": "view",
		"type": "function"
	},
	{
		"constant": true,
		"inputs": [
			{
				"name": "_id",
				"type": "uint256"
			}
		],
		"name": "getOfferContractDetailsById",
		"outputs": [
			{
				"name": "_buyerAddress",
				"type": "address"
			},
			{
				"name": "_sellerAddress",
				"type": "address"
			},
			{
				"name": "_offerDate",
				"type": "uint256"
			},
			{
				"name": "_currentDate",
				"type": "uint256"
			},
			{
				"name": "_expiredDate",
				"type": "uint256"
			},
			{
				"name": "_offerAmount",
				"type": "uint256"
			},
			{
				"name": "_accepted",
				"type": "bool"
			}
		],
		"payable": false,
		"stateMutability": "view",
		"type": "function"
	},
	{
		"constant": true,
		"inputs": [
			{
				"name": "_id",
				"type": "uint256"
			}
		],
		"name": "isOfferAccepted",
		"outputs": [
			{
				"name": "",
				"type": "bool"
			}
		],
		"payable": false,
		"stateMutability": "view",
		"type": "function"
	}
]);
            //Must set default account
            web3.eth.defaultAccount = getWalletAccount(0);
            var offerContractInstance = offerContractABI.at('0x8c1ed7e19abaa9f23c476da86dc1577f1ef401f5');
                //console.log(offerContractInstance.address);
                //console.log("Waletts: " + getWalletAccount(1) + "::" + getWalletAccount(0));
                var result =  offerContractInstance.createOfferContract("0x79bc53CBcB9A525f34F4eB652DF8F92a34fC4184", "0x7Ca6F215DAe1877f29AE89A48A0B11ec9017dc79","", "", "",offer.offered_price,true);
                console.log("Result: " + result);
           
            

}//createOfferContract

/*
*   Event listeners
*/
//DOM event
//document.addEventListener('DOMContentLoaded', StoreProperties.displayProperties);

document.addEventListener('DOMContentLoaded', function(e) {
    var urlParams = new URLSearchParams(window.location.search);
    /*
    * If POST header is passed an 'id' field, display property data on form in order for user to enter an offered price
    */
    if( urlParams.has("id") ) {
        //alert(urlParams.get('id')+":"+urlParams.get('banner')+":"+urlParams.get('address')+":"+urlParams.get('feature')+":"+urlParams.get('price'));
        document.getElementById('property_id').value = urlParams.get('id');
        document.getElementById('headerbanner').value = urlParams.get('banner');
        document.getElementById('address').value = urlParams.get('address');
        document.getElementById('features').value = urlParams.get('feature');
        document.getElementById('listing_price').value = urlParams.get('price');
    }
    else {
        //StoreProperties.displayActiveOffers();
    }

    document.getElementById('properties-form').addEventListener('submit', function(e){
        //capture source of button
        var source = e.srcElement || e.originalTarget;
        // Get form values
        const property_id = document.getElementById('property_id').value,
            headerbanner = document.getElementById('headerbanner').value,
            address = document.getElementById('address').value,
            features = document.getElementById('features').value
            price = document.getElementById('listing_price').value
            offer_price = document.getElementById('offer_price').value
            
            // Instantiate book
            const activeOfferListingUI = new ActiveOfferListingUI();
            // Validate
            if(offer_price === '') {
                // Error alert
                activeOfferListingUI.showAlert('Please fill in all fields', 'error');
            }
            else {
                //alert(property_id+":"+headerbanner+":"+address+":"+features+":"+price+":"+offer_price);
                offer = new Offers(property_id, headerbanner, address, features, price, offer_price);
                /*
                * At this point, an OfferContract must be generate
                */
                createOfferContract(offer);
                window.localStorage.setItem('activeoffers', JSON.stringify(offer));
                
                activeOfferListingUI.addPropertyToActiveOfferList(offer);
                
                //add to storage
                //StoreProperties.addPropertyToActiveOfferList(offer);
                
                // Show success
                activeOfferListingUI.showAlert('Offer Added!', 'success');
    
                // Clear fields
                activeOfferListingUI.clearFields();
            }
            
            e.preventDefault();
        
    });

    document.getElementById('property-list').addEventListener('click', function(e){
        //capture source of click
        var source = e.srcElement || e.originalTarget;
        //alert("click source: " + source.id);
    });

    /*
    * Setup Web3 components
    */
    // initialize web3
    if(typeof web3 !== 'undefined') {
      //reuse the provider of the Web3 object injected by Metamask
      web3Provider = web3.currentProvider;
    } else {
      //create a new provider and plug it directly into our local node
      web3Provider = new Web3.providers.HttpProvider('http://127.0.0.1:7545');
    }
    web3 = new Web3(web3Provider);
});
