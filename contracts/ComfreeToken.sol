pragma solidity ^0.4.24;

import "./ConvertLib.sol";
//import "./ComfreePropertyDataModel.sol";

// This is just a simple example of a coin-like contract.
// It is not standards compatible and cannot be expected to talk to other
// coin/token contracts. If you want to create a standards-compliant
// token, see: https://github.com/ConsenSys/Tokens. Cheers!

/*
*	this is executed first time contract is deployed
* NOT instantiated
* msg = is a global variable declared and populated by Ethereum itself. It contains important data for performing the * contract.
*/
contract ComfreeToken {

	mapping(address => uint256) balances;
	mapping(address => mapping (address => uint256)) allowed;
	uint256 public totalSupply;

	event Transfer(address _sender, address _receiver, uint256 _numTokens);
    event Approval(address _sender, address _delegate, uint256 _numTokens);

	constructor(uint256 total) public {
		totalSupply = total;
		balances[msg.sender] = totalSupply;
	}

	

	/*
	* used to move numTokens amount of tokens from the owner’s balance to that of another user, or receiver
	*/
	function transfer(address receiver, uint256 numTokens) payable public returns (bool) {
  		require(numTokens <= balances[msg.sender]);
		balances[msg.sender] = balances[msg.sender]-numTokens;
  		balances[receiver] = balances[receiver] + numTokens;
  		emit Transfer(msg.sender, receiver, numTokens);
  		return true;
	}

	/*
	*	allows a delegate approved for withdrawal to transfer owner funds to a third-party account.
	*/
	function transferFrom(address owner, address buyer, uint numTokens) public returns (bool) {
  		/*require(numTokens <= balances[owner] && numTokens <= allowed[owner][msg.sender]);
  		//require(numTokens <= allowed[owner][msg.sender]);
  		balances[owner] = balances[owner]-numTokens;  
  		allowed[owner][msg.sender] = allowed[from][msg.sender]-numTokens;
  		balances[buyer] = balances[buyer] + numTokens;
  		emit Transfer(owner, buyer, numTokens);*/
  		return true;
	}

	/*
	*	function is used for scenarios where owners are offering tokens on a marketplace. It allows the marketplace to *	finalize the transaction without waiting for prior approval.  Often used in a token marketplace scenario
	*/
	function approve(address delegate, uint numTokens) public returns (bool) {
  		allowed[msg.sender][delegate] = numTokens;
  		emit Approval(msg.sender, delegate, numTokens);
  		return true;
	}

	/*
	* returns the current approved number of tokens by an owner to a specific delegate
	*/
	function allowance(address owner, address delegate) public view returns (uint) {
  		return allowed[owner][delegate];
	}

	/*
	*	return the number of all tokens allocated by this contract regardless of owner
	*/
	function totalSupply() public view returns (uint256) {
  		return totalSupply;
	}

	/*
	* return the current token balance of an account, identified by its owner’s address
	*/
	function balanceOf(address tokenOwner) public view returns (uint) {
  		return balances[tokenOwner];
	}

}
