pragma solidity ^0.4.24;

contract ComfreePropertyDataModel {

    address owner;

    struct EscrowDataElements {
        address escrowDepositor; //buyer
        address escrowAgent; //bank
        address escrowBeneficiary; //seller receiving the money to be deposited
        uint256 escrowAmount;
    }

}