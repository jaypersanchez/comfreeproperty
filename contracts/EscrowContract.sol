pragma solidity ^0.4.24;

import "./ComfreePropertyDataModel.sol";
import "./ComfreeToken.sol";


contract EscrowContract {
    address owner;
    mapping (address => uint256)  private userBalances;

    constructor () {
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

  function getMsgValue() public view returns(uint) {
    return msg.value;
  }

  function getMsgSender() public view returns(address,address) {
    return (msg.sender, owner);
  }

    function sendFundsToSeller(uint _escrowAmount, address _escrowSellerAddress) public payable returns(uint) {
        /*
        * By design, when not using ERC20 token, ether must first be transfered from buyer address to contract owner
        */
        require(msg.sender.balance >= _escrowAmount);
        if(msg.sender == owner) {

          uint balanceAmount = msg.sender.balance - _escrowAmount;
          //need to transfer ether from account[0] to current contract address
          address(_escrowSellerAddress).transfer(_escrowAmount);
          return 1; //success
        }
        else {
          return 0; //fail
        }
    }//sendFundsToSeller

    function() payable {

    }
}