pragma solidity ^0.4.24;

import "./SaleConditionContract.sol";

/*
* First contract to be created.  This will have an expiry date of the offer.
*/

contract OfferContract {
	
    struct OfferContract {
        address buyerAddress;
        address sellerAddress;
        uint offerDate;
        uint expiredDate;
        uint currentDate;
        uint offerAmount;
        bool accepted;
    }

    address[] saleConditionContractsArray;

    OfferContract offerContractObject;
    uint numberDaysExpiration = 10;
    SaleConditionContract saleConditionContract;

	constructor() public {
        //default setting
		offerContractObject.accepted = false;
        offerContractObject.currentDate = now;
        //Expiration date is set from current date plus numberDaysExpiration default to 10 days
        offerContractObject.expiredDate = now+numberDaysExpiration;
    }

    function setSellerAddress(address _value) public {
        offerContractObject.sellerAddress = _value;
    }

    function setBuyerAddress(address _value) public {
        offerContractObject.buyerAddress = _value;
    }

    function getSellerAddress() public returns(address _addy) {
        return offerContractObject.sellerAddress;
    } 

    function getBuyerAddress() public returns(address _addy) {
        return offerContractObject.buyerAddress;
    }

	/*
    * Parameters
    *  - buyerAddress is wallet address of buyer
    */
	function setBuyerOffer(uint _offerAmount) public  {
		offerContractObject.offerAmount = _offerAmount;
	}

    function getOfferAmount() public returns(uint _value) {
        return offerContractObject.offerAmount;
    }

    function accept(bool _value) public returns(bool) {
        /*
        * Future update.  Must have mechanism to prevent changing accepted offer
        * back to non-acception.  Depending on law of the land, the current
        * instance of this contract may have to be nulled and a new contract
        * must be opened.
        */
        offerContractObject.accepted = _value;
        return _value; //this will either return true or false
    }

    function isOfferAccepted() public returns(bool) {
        return offerContractObject.accepted;
    }

    function isOfferExpired() public returns(bool _value) {
        if( now == offerContractObject.expiredDate || now > offerContractObject.expiredDate ) {
            _value = true;
        }
        else {
            _value = false;
        }
        return _value;
    }
}
