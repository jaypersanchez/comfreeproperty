pragma solidity ^0.5.0;

import "./OfferContract.sol";
import "./ComfreePropertyDataModel.sol";

/*
*   Once the OfferContract is accepted, this contract is next to be set the
* condition before it goes into escrow.  Cannot have a sale condition contract without an
* accepted OfferContract.
*/

contract SaleConditionContract is ComfreePropertyDataModel {
    address owner;

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

    /* This contract is instantiated and created from OfferContract 
    * The modifier is in place to prevent an outside source from creating an instance of this contract
    * without a valid OfferContract.
    */
    constructor () public {
        owner = msg.sender;
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
    * This will set the expiration for conditions to be met
    */
    function setConditions(uint _dateOfCondition, uint _conditionExpiryDate, bool _conditionMet) public {
        conditionHeaderData.dateOfCondition = _dateOfCondition;
        conditionHeaderData.conditionExpiryDate = _conditionExpiryDate;
        conditionHeaderData.conditionMet = _conditionMet;
    }

    /*
    * This will set which condition in the ConditionsList
    * has been met that must be met before the conditionExpireDate in Condition
    * structs expires
    */
    function setConditionList(bool _WallsPainted, bool _CarpetCleaned,bool _WindowsWashed) public {
        conditionList.WallsPainted = _WallsPainted;
        conditionList.CarpetCleaned = _CarpetCleaned;
        conditionList.WindowsWashed = _WindowsWashed;
        if( conditionList.WallsPainted && conditionList.CarpetCleaned && conditionList.WindowsWashed ) {
            //all sales conditions met
            emit isAllSaleConditionsMet(true, true, true);
        }
    }

    function getConditions() public returns(bool _WallsPainted, bool _CarpetCleaned,bool _WindowsWashed) {
        //must return the struct as array for UI
        return (conditionList.WallsPainted, conditionList.CarpetCleaned, conditionList.WindowsWashed);
    }

}