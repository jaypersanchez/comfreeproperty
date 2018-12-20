pragma solidity ^0.4.24;

import "./OfferContract.sol";

/*
*   Once the OfferContract is accepted, this contract is next to be set the
* condition before it goes into escrow.  Cannot have a sale condition contract without an
* accepted OfferContract.
*/

contract SaleConditionContract {

    struct Condition {
        uint dateOfCondition;
        uint conditionExpiryDate;
        bool conditionMet;
    }

    struct ConditionsList {
        /*
        * For simplicity sake there will only be a few conditions
        * when a condition is set to true, then it is a condition 
        * that needs to be met
        */
        bool WallsPainted;
        bool CarpetCleaned;
        bool WindowsWashed;
    }

    //List of valid OfferContracts
    mapping(address => OfferContract) listOfOfferContracts;
    OfferContract offerContract;
    Condition conditionHeaderData;
    ConditionsList conditionList;
    bool private offerContractValid = false;

    modifier isOfferContractValid(address _offerContractAddress) {
        offerContract = OfferContract(_offerContractAddress);
        require(offerContract.isOfferAccepted() == true);
        _;
    }

    /* This contract is instantiated and created from OfferContract 
    * The modifier is in place to prevent an outside source from creating an instance of this contract
    * without a valid OfferContract.
    */
    /*constructor(address _offerContractAddress) public isOfferContractValid(_offerContractAddress) {
        conditionHeaderData.dateOfCondition = 0;
        conditionHeaderData.conditionExpiryDate = 0;
        conditionHeaderData.conditionMet = false;
    }*/
    constructor() public {
        conditionHeaderData.dateOfCondition = 0;
        conditionHeaderData.conditionExpiryDate = 0;
        conditionHeaderData.conditionMet = false;
    }

    function isConditionMet() public returns(bool _value) {
        if(conditionList.WallsPainted == true && conditionList.CarpetCleaned == true && conditionList.WindowsWashed == true) {
            return true;
        }
        else {
            return false;
        }           
    }
    
    /*
    * This will set which condition in the ConditionsList
    * must be met before the conditionExpireDate in Condition
    * structs expires
    */
    function setConditions(uint _dateOfCondition, uint _conditionExpiryDate, bool _conditionMet) public {
        conditionHeaderData.dateOfCondition = _dateOfCondition;
        conditionHeaderData.conditionExpiryDate = _conditionExpiryDate;
        conditionHeaderData.conditionMet = _conditionMet;
    }

    function setConditionList(bool _WallsPainted, bool _CarpetCleaned,bool _WindowsWashed) public {
        conditionList.WallsPainted = _WallsPainted;
        conditionList.CarpetCleaned = _CarpetCleaned;
        conditionList.WindowsWashed = _WindowsWashed;
    }

    function getConditions() public returns(bool _WallsPainted, bool _CarpetCleaned,bool _WindowsWashed) {
        //must return the struct as array for UI
        return (conditionList.WallsPainted, conditionList.CarpetCleaned, conditionList.WindowsWashed);
    }

}