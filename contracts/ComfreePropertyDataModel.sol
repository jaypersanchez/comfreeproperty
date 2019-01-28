pragma solidity ^0.4.24;

contract ComfreePropertyDataModel {

    address owner;

    struct EscrowDataElements {
        address escrowDepositorAddress; //buyer
        address escrowAgentAddress; //bank
        address escrowBeneficiaryAddress; //seller receiving the money to be deposited
        uint256 escrowAmount;
    }
    EscrowDataElements public escrowDataElements;

    //event Transfer(address _sender, address _receiver, uint256 _numTokens);
    //event Approval(address _sender, address _delegate, uint256 _numTokens);
    event OfferCreated(address _buyer, address _seller, uint256 offerAmount);
    event OfferAccepted(uint _id, bool _value);
}