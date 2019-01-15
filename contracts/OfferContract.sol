pragma solidity ^0.4.24;

import "./SaleConditionContract.sol";
import "./ComfreePropertyDataModel.sol";

/*
* First contract to be created.  This will have an expiry date of the offer.
*/

contract OfferContract is ComfreePropertyDataModel {
	address owner;

    struct OfferContract {
        address buyerAddress;
        address sellerAddress;
        uint offerDate;
        uint expiredDate;
        uint currentDate;
        uint offerAmount;
        bool accepted;
    }

    OfferContract offerContractObjects;
    uint numberDaysExpiration = 10;
    SaleConditionContract saleConditionContract;

    address[] saleConditionContractsArray;
    mapping (address => OfferContract) public listOfOfferContracts;

    

	constructor () public {
        //default setting
		//offerContractObjects.accepted = false;
        //offerContractObjects.currentDate = now;
        //Expiration date is set from current date plus numberDaysExpiration default to 10 days
        //offerContractObjects.expiredDate = now+numberDaysExpiration;
        owner = msg.sender;
    }

    /*
    * _address parameter can be either the seller or the buyer
    */
    function getOfferContractData(address _address) public view returns(address _buyerAddress, address _sellerAddress, uint _offerDate, uint _currentDate, uint _expiredDate,uint _offerAmount,bool _accepted) {
        return (listOfOfferContracts[_address].buyerAddress, listOfOfferContracts[_address].sellerAddress,
                listOfOfferContracts[_address].offerDate, listOfOfferContracts[_address].expiredDate,
                listOfOfferContracts[_address].currentDate, listOfOfferContracts[_address].offerAmount, 
                listOfOfferContracts[_address].accepted);
    }

    function createOfferContract(address _buyerAddress, address _sellerAddress, 
                                 uint _offerDate, uint _currentDate, uint _expiredDate,
                                 uint _offerAmount,bool _accepted) public {
        listOfOfferContracts[_buyerAddress].buyerAddress = _buyerAddress;
        listOfOfferContracts[_buyerAddress].sellerAddress = _sellerAddress;
        listOfOfferContracts[_buyerAddress].offerDate = _offerDate;
        listOfOfferContracts[_buyerAddress].currentDate = _currentDate;
        listOfOfferContracts[_buyerAddress].expiredDate = _expiredDate;
        listOfOfferContracts[_buyerAddress].offerAmount = _offerAmount;
        listOfOfferContracts[_buyerAddress].accepted = _accepted;
    }

    /*
    * Parameters
    *  - buyerAddress is wallet address of buyer
    */
	function setBuyerOffer(address _address, uint _offerAmount) public  {
		listOfOfferContracts[_address].offerAmount = _offerAmount;
	}

    function accept(address _address, bool _value) public returns(bool) {
        /*
        * Future update.  Must have mechanism to prevent changing accepted offer
        * back to non-acception.  Depending on law of the land, the current
        * instance of this contract may have to be nulled and a new contract
        * must be opened.
        */
        listOfOfferContracts[_address].accepted = _value;
        return _value; //this will either return true or false
    }

    function isOfferAccepted(address _address) public view returns(bool) {
        return listOfOfferContracts[_address].accepted;
    }

    function isOfferExpired() public returns(bool _value) {
        /*if( now == offerContractObjects.expiredDate || now > offerContractObjects.expiredDate ) {
            _value = true;
        }
        else {
            _value = false;
        }
        return _value;*/
    }
}
