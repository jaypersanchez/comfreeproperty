# Comfree Property

Comfree Property is a set of smart contracts that is required for selling a property.  It is working withing the laws of 
real state laws for each Province.  All contracts contain all tradition elements of a real state transaction.  Each contract is initiated when a dependent contract meets a certain state of the contract.  For example, the offerContract is the initial start of a real state transaction.  The buyer will make an offer that is recorded in the OfferContract.  Once the offerContract is at a state of "offer accepted", the SaleCondition contract will be initiated.

## Install
.....
Website URL TBD
.....

## Development 
$ git clone http://www.github.com/jaypersanchez/comfree.git

## Usecase Diagram

<img src="./ConsensysBootcampFinalProject.png" width="500">

## Usage from Truffle Console
1. Open terminal widow and change directory into "comfree" project
2. Open another terminal and start ganache-cli or ganache windows
3. Open another terminal and go to truffle console
4. Compile from truffle console
5. Create OfferContract instance
6. OfferContract.deployed().then(function(instance){offerInstance=instance;})
7. Set seller address using one of the account from Ganache: offerInstance.setSellerAddress('walletaddress')
8. Set buyer address using one of the account from Ganache: offerInstance.setBuyerAddress('walletAddress')
9. Accept offer: offerInstance.accept(true)
10. Verify offer is accepted: offerInstance.isOfferAccepted.call()
11. Create SaleConditionContract instance.  Application business flow will create this contract
once OfferContract.accept is true

## Improvement List
1. Set validation when setting buyer and seller address.  Make sure that buyer address is not set to seller address once seller address has been set
2. Fix date stamp in OfferContract for expiration
3. Change design/implementation so that SaleConditionContract will allow itself to be created
when OffectContract is at accepted state
