# Comfree Property

Comfree Property is a set of smart contracts protocol that is required for selling a property.  It is working within the laws of real state laws for each Canadian Province and U.S State.  All contracts contain all tradition elements of a real state transaction.  Each contract is initiated when a dependent contract meets a certain state of the contract.  For example, the offerContract is the initial start of a real state transaction.  The buyer will make an offer that is recorded in the OfferContract.  Once the offerContract is at a state of "offer accepted", the SaleCondition contract will be initiated.  The flow of this logic is controlled on the application layer.  Comfree protocol is a layer to transaction but logic and business flow will dictate when each contract is instantiated.  This design will allow any real estate company to use the "comfree property" platform in anyway while the owner of these contract, the developers, will get a share of each transaction which is why the payment between buyer and seller from escrow contract goes through the default coinbase.  But the architecture of the core contracts are/should be flexible enough to be used in both commercial and private property sales.

## Project Requirements
The customer web application interface will consist of four web pages: propertiesForSale.html, activeOffers.html, activeEscrows.html and propertiesSold.html

# propertiesForSale.html
The user can add a new property that is for sale and will include basic features of the property.  Below the form to add new properties is a list of properties that is open to accept offers.  There will be two buttons: 'remove from list' and 'make an offer'.  Remove button will remove the property from the list.  Make offer will take the user to the activeOffers.html page.  Once there is an offer, both buttons will be disabled to prevent any action while on active offer.

# activeOffers.html
This page list out properties that has an active offer.  The offer can either be rejected or accepted.  If the offer is rejected, it will remove this from the active offer list and the buttons from the propertiesForSale.html list will once again be enabled.  If offer is accepted, this will be removed from the current list and will then be moved to the activeEscrows.html page but will still be in the propertiesForSale.html but with buttons still disabled.

# activeEscrows.html
This page list out properties that are going through escrow.  This is where the buyer is going through finance approval process.  The escrow will either be approved or denied.  If the escrow is denied, the property is removed from this list and it goes back to the propertiesForSale.html with both buttons enabled.  If escrow is approved, this property will be removed from propertiesForSale.html and from this current list and will then show in the propertiesSold.html page.  Transfer of assets between seller and buyer and land title and all legal documents are all generated.

# propertiesSold.html
This page simply list out all properties that have gone through escrow closing. 

## Project Evaluation Notes
1. Please use 0_test_OfferContract to test the end to end flow of the contracts.  The web UI is not in full functioning mode.  It is currently only displaying offers waiting to be accepted.
 

## Install
GitHub:
* git clone https://github.com/jaypersanchez/comfreeproperty.git
* change directory ./comfreeproperty
* Run npm init - to generate package.json if needed

NodeMon:
* Nodemon is needed for NodeJS server side
* npm install --save-dev nodemon

Express:
* npm install express --save

Lite-Server
* Install local HTTP server to test DApp
* npm install lite-server --save

MongoDB:
* npm mongo
* mongo --version

## Development 
$ git clone https://github.com/jaypersanchez/comfreeproperty

## Setup for NodeJS RESTful API
* change directory into comfreeproperty
* From current root of comfreeproperty create a Javascript file and call it "server.js"
* See sample code in this project
* Create directory "api"
* Create the following sub-directories: api/conrollers, api/models, api/routes
* This RESTful takes the MVC framework

## Usecase Diagram

<img src="./ConsensysBootcampFinalProject.png" width="500">


## Usage from Truffle Console 
1. Create OfferContract instance - OfferContract.deployed().then(function(instance){offerInstance=instance;})
2. Set seller address using one of the account from Ganache: offerInstance.setSellerAddress('walletaddress')
3. Set buyer address using one of the account from Ganache: offerInstance.setBuyerAddress('walletAddress')
4. Accept offer: offerInstance.accept(true)
5. Verify offer is accepted: offerInstance.isOfferAccepted.call()
6. Create SaleConditionContract instance.  
7. Set condition list to true/false.  Invoke SaleCondition.isConditionMet; if all conditions from ConditionList are true, next state of contract will be allowed

## Future to-do Improvement List
1. Set validation when setting buyer and seller address.  Make sure that buyer address is not set to seller address once seller address has     been set
2. Fix date stamp in OfferContract for expiration
3. Change design/implementation so that SaleConditionContract will allow itself to be created
when OffectContract is at accepted state
4. Should add change when moving from one state to another, from OfferContract to SaleConditionContract for example, both public keys of seller and buyer must be provided as a way to authenticate consent of state change
5. Add contracts for tenancy/rental contracts
6. Shyft Network or uPort for KYC/AML
7. Application UI for user application example
8. During development, ether is used as currency for the buy/sell transaction.  Implement MetaCoin as a utility 
token as currency for buy/sell transaction

## Miscellaneous Cheat Notes

###Should ganche UI does not start do the following
* netstat -vanp tcp | grep <portnumber> OR ls -f -i:<portnumber>
* kill -9 <PID#>

###Add ssh key
* Follow instructions below
* https://help.github.com/en/articles/generating-a-new-ssh-key-and-adding-it-to-the-ssh-agent
