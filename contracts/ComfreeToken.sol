pragma solidity ^0.6.0 < 0.6.11;


/*
*	ComfreeToken is an ERC20 standard
*/

/*
* Token economics
* Token (stock) price of a company is calculated when a company goes public, an event
* called and initial public offering (IPO). This is when a company pays an investment
* bank to use very complex formulas and valuation techniques to derive a company's value * and to determine how many shares will be offered to the public and at what price. 
* For example,* a company whose value is estimated at $100 million may want to issue 10
* million shares at $10 per share or they may want to issue 20 million at $5 a share.
*/
contract ComfreeToken {

	//walletaddress = balance of wallet
	mapping(address => uint256) balances;
	//wallet address = anotherMapping(walletaddress = approvedwithdrawalsum)
	mapping(address => mapping (address => uint256)) allowed;
	uint256 totalSupply_;
	address private owner;
	

	/*
	* Standard event declaration required by ERC20 framework
	*/
	event Approval(address indexed tokenOwner, address indexed spender,
 uint tokens);
	event Transfer(address indexed from, address indexed to,
 uint tokens);
	event InflateToken(address owner, uint256 amountInflated, uint256 newTokenSupply);

	/*
	* constructor is run once when it is deployed for the first time
	* unlike the standard constructor practice in an OOP
	* Only the deploying account can enter a contract’s constructor. When the contract is * started up, this function allocates available tokens to the ‘contract owner’ account.
	*/
	constructor ( uint256 total ) public {
		totalSupply_ = total;
		balances[msg.sender] = totalSupply_;
		owner = msg.sender;
	}

	/*
	* ERC20 required function declaration
	*/
	function totalSupply() public view returns (uint256) {
		return totalSupply_;
	}

	function inflateTotalSupply(uint256 _amount) public returns (uint256) {
		require(msg.sender == owner);
		totalSupply_ = _amount;
		/*
		* Implement a function in here to determine inflation rate of token when increased
		* supply is manually called.
		*/
		balances[msg.sender] = balances[msg.sender]+_amount;
		//owner address, amount to inflate token, new owner supply balance
		emit InflateToken(msg.sender, _amount, balances[msg.sender]);
		return totalSupply();
	}

	function balanceOf(address tokenOwner) public view returns (uint) {
		return balances[tokenOwner]; 
	}

	function allowance(address _owner, address delegate) public view returns (uint) {
  		return allowed[owner][delegate];
	}

	function transfer(address receiver, uint numTokens) public returns (bool) {
  		require(numTokens <= balances[msg.sender]);
  		balances[msg.sender] = balances[msg.sender]-numTokens;
  		balances[receiver] = balances[receiver] + numTokens;
  		emit Transfer(msg.sender, receiver, numTokens);
  		return true;
	}

	/*
	* @Params:
	* 	delegate = spender
	*	numTokens = tokens to be transfered
	*/
	function approve(address delegate, uint numTokens)  public returns (bool) {
		allowed[msg.sender][delegate] = numTokens;
  		emit Approval(msg.sender, delegate, numTokens);
  		return true;
	}

	function transferFrom(address _owner, address buyer, uint numTokens) public returns (bool) {
  		require(numTokens <= balances[owner]);
  		require(numTokens <= allowed[owner][msg.sender]);
  		balances[owner] = balances[owner]-numTokens;
  		allowed[owner][msg.sender] = allowed[owner][msg.sender]-numTokens;
  		balances[buyer] = balances[buyer]+numTokens;
  		emit Transfer(owner, buyer, numTokens);
		return true;
	}

}
