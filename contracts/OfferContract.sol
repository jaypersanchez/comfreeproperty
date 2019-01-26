pragma solidity ^0.4.24;

import "./SaleConditionContract.sol";
import "./ComfreePropertyDataModel.sol";

/*
* First contract to be created.  This will have an expiry date of the offer.
*/

contract OfferContract is ComfreePropertyDataModel {
	address owner;

    struct OfferContract {
        uint id; 
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
    mapping (uint => OfferContract) public _listOfOfferContracts;
    uint offerContractCounter; //this is used as an index that holds each contracts
    

	constructor () public {
        owner = msg.sender;
    }

    /*
    * This function is to get all of active offers
    */
    function getActiveOffers() public view returns(uint[]) {
        //prepare output array
        uint[] memory indexCounter = new uint[](offerContractCounter);
        uint numberOfSavedOfferContracts = 0;
        //itirate over biodatalist
        for(uint i = 1; i <= offerContractCounter; i++) {
            //show bio data item
            indexCounter[numberOfSavedOfferContracts] = _listOfOfferContracts[i].id;
            numberOfSavedOfferContracts++;
        }
        //copy bioDataIds array just get ids pertaining to contractOwner
        uint[] memory owneddata = new uint[](numberOfSavedOfferContracts);
        for(uint j = 0; j < numberOfSavedOfferContracts; j++) {
            owneddata[j] = indexCounter[j];
        }

        return owneddata;
        
    }

    /*
    * _address parameter can be either the seller or the buyer
    */
    function getOfferContractDetailsById(uint _id) public view returns(address _buyerAddress, address _sellerAddress, uint _offerDate, uint _currentDate, uint _expiredDate,uint _offerAmount,bool _accepted) {
        return (_listOfOfferContracts[_id].buyerAddress, _listOfOfferContracts[_id].sellerAddress,
                _listOfOfferContracts[_id].offerDate, _listOfOfferContracts[_id].expiredDate,
                _listOfOfferContracts[_id].currentDate, _listOfOfferContracts[_id].offerAmount, 
                _listOfOfferContracts[_id].accepted);
    }

    /*
    * Contract deployer via DApp is the only one allowed to initiate this transaction
    * 1 = Success
    * 0 = Failed
    */
    function createOfferContract(address _buyerAddress, address _sellerAddress, 
                                 uint _offerDate, uint _currentDate, uint _expiredDate,
                                 uint _offerAmount,bool _accepted) public returns(uint _result) {
        if(msg.sender == owner) {
            //increment index
            offerContractCounter++;
            _listOfOfferContracts[offerContractCounter] = OfferContract(offerContractCounter, _buyerAddress, _sellerAddress, _offerDate, _currentDate, _expiredDate, _offerAmount, _accepted);
            return 1;
        }
        else {
            return 0;
        }
    }

    
    function accept(uint _id, bool _value) public returns(bool) {
        /*
        * Future update.  Must have mechanism to prevent changing accepted offer
        * back to non-acception.  Depending on law of the land, the current
        * instance of this contract may have to be nulled and a new contract
        * must be opened.
        */
        _listOfOfferContracts[_id].accepted = _value;
        return _value; //this will either return true or false
    }

    function isOfferAccepted(uint _id) public view returns(bool) {
        return _listOfOfferContracts[_id].accepted;
    }

    function isOfferExpired(uint _id) public returns(bool _value) {
        /*if( now == offerContractObjects.expiredDate || now > offerContractObjects.expiredDate ) {
            _value = true;
        }
        else {
            _value = false;
        }
        return _value;*/
    }
}
