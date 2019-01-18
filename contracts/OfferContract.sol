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
    mapping (address => OfferContract) public listOfOfferContracts;
    //mapping will hold differentr contract struct
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
    /*function getOfferContractData(address _address) public view returns(address _buyerAddress, address _sellerAddress, uint _offerDate, uint _currentDate, uint _expiredDate,uint _offerAmount,bool _accepted) {
        return (listOfOfferContracts[_address].buyerAddress, listOfOfferContracts[_address].sellerAddress,
                listOfOfferContracts[_address].offerDate, listOfOfferContracts[_address].expiredDate,
                listOfOfferContracts[_address].currentDate, listOfOfferContracts[_address].offerAmount, 
                listOfOfferContracts[_address].accepted);
    }*/

    function createOfferContract(address _buyerAddress, address _sellerAddress, 
                                 uint _offerDate, uint _currentDate, uint _expiredDate,
                                 uint _offerAmount,bool _accepted) public {
        //increment index
        offerContractCounter++;
        //biodatalist[recordCounter] = BioDataObj(recordCounter,msg.sender,_firstName, _middleName, _lastName);
        _listOfOfferContracts[offerContractCounter] = OfferContract(offerContractCounter, _buyerAddress, _sellerAddress, _offerDate, _currentDate, _expiredDate, _offerAmount, _accepted);
        /*listOfOfferContracts[_buyerAddress].buyerAddress = _buyerAddress;
        listOfOfferContracts[_buyerAddress].sellerAddress = _sellerAddress;
        listOfOfferContracts[_buyerAddress].offerDate = _offerDate;
        listOfOfferContracts[_buyerAddress].currentDate = _currentDate;
        listOfOfferContracts[_buyerAddress].expiredDate = _expiredDate;
        listOfOfferContracts[_buyerAddress].offerAmount = _offerAmount;
        listOfOfferContracts[_buyerAddress].accepted = _accepted;*/
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
