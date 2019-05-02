pragma solidity ^0.5.0;

import "./ComfreePropertyDataModel.sol";
import "./ComfreeToken.sol";


contract EscrowContract {
    address owner;
    mapping (address => uint256)  private userBalances;

    constructor () public {
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

  function getMsgValue() public payable returns(uint) {
    return msg.value;
  }

  function getMsgSender() public view returns(address,address) {
    return (msg.sender, owner);
  }

    

    function() external payable {

    }
}