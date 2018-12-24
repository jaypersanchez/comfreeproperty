pragma solidity ^0.4.24;

import "./ComfreePropertyDataModel.sol";

contract EscrowContract is ComfreePropertyDataModel {
    
    constructor() public {
        owner = msg.sender;
    } 

    modifier checkAccountBalance(address _accountAddress) {
        require(_accountAddress.value >= EscrowDataElements.escrowAmount);
        _;
    }

    /*
    *   0 = successful deposit
    *   1 = deposit failed
    */
    function depositToEscrow() public checkAccountBalance(EscrowDataElements.escrowDepositor) returns(uint8 _result) {
        /*
        * transfer funds from escrowDepositor account into 
        * escrowBeneficiary account
        */
    } 



}