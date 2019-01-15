pragma solidity ^0.4.24;

import "./ComfreePropertyDataModel.sol";
import "./ComfreeToken.sol";

contract EscrowContract {
    address owner;

    constructor () payable {
        owner = msg.sender;
    }//constructor 

    modifier checkAccountBalance(address _accountAddress, uint _escrowAmount) {
        require(_accountAddress.balance >= _escrowAmount);
        _;
    }//checkAccountBalance

    modifier isContractOwner(address _address) { 
    require(msg.sender == _address); 
    _; }

  modifier verifyCaller (address _address) { 
    require (msg.sender == _address); 
    _;
  }

  modifier paidEnough(uint _price) { 
    require(msg.value >= _price); 
    _;
  }

  modifier checkValue(uint _price) {
    //refund them after pay for item (why it is before, _ checks for logic before func)
    _;
    uint amountToRefund = msg.value - _price;
    msg.sender.transfer(amountToRefund);
    
  }

    function sendFundsToSeller(uint _escrowAmount, address _escrowSellerAddress) public payable returns(uint) {
        /*
        * transfer funds from escrowDepositor account into 
        * escrowBeneficiary account.  For testing, escrowBeneficiary amount can use 
        * ganache coinbase.  In production, this will be another wallet address
        */
        uint result = 0; //default to fail
        require(msg.value >= _escrowAmount);
        uint balanceAmount = msg.value - _escrowAmount;
        //need to transfer ether from account[0] to current contract address
        address(_escrowSellerAddress).transfer(_escrowAmount);
        result = 1; //if require does not revert and transfer is successful, change result to 1 for success
        return result; //success
    }//sendFundsToSeller

    function() payable {

    }
}