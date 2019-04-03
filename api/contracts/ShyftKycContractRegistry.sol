pragma solidity ^0.4.17;

import "./ShyftKycContract.sol";


//this contract acts as a registry between past and current versions of the ShyftKycContract


// problem with registry
// need to call contractA.withdraw preserving msg.sender - can only be done with
// tx.origin (not secure) or delegatecall, which only modifies storage of caller contract
// possible fix: keep token info inside registry contract?


// the functions inside the registry act as an "interface" of sorts
// point the caller to the function, but first check if the contract has been upgraded
// if it has, the user's tokens get moved to the new contract, then the upgraded function in the
// new contract gets called


// do we need to add every ERC223 function into the registry, or just fallback and withdraw?
// do we need to transfer tokens for any other functions?

contract ShyftKycContractRegistry {
    ShyftKycContract public shyftKycContract;
    mapping (address => uint) public tokenLocation; // maps user address to contract version
    address[] public contracts;
    address owner;
    uint public currVersion;

    event EVT_ERC223TokenFallback(address _from, uint256 _value, bytes _data);

    constructor() {
        owner = msg.sender;
    }

    modifier onlyOwner{
        require(msg.sender == owner);
        _;
    }

    // this will need to be called when the ShyftKycContract is deployed for the first time
    function init(address _addr) onlyOwner public returns (address)  {
        if (contracts.length == 0){
            contracts.push(_addr); // set original contract w/ version 0
            shyftKycContract = ShyftKycContract(_addr);
        }
        return address(shyftKycContract);
    }
    
    // this will need to be called after an updated contract is deployed
    function upgrade(address _addr) onlyOwner public returns (bool) {
        contracts.push(_addr);
        currVersion++;
        shyftKycContract = ShyftKycContract(_addr);
        address _contract = contracts[currVersion-1];
        bytes4 sig = bytes4(keccak256(abi.encodePacked("update(address)")));
        return _contract.call(sig, _addr);
    }

    function getCurrentContractAddress() public returns (address) {
        return contracts[currVersion];
    }

    function getContractAddressOfVersion(uint _v) public returns (address) {
        if(_v < contracts.length) return contracts[_v];
    }
    
    function getTokenLocation(address _a) public returns (uint){
        return tokenLocation[_a];
    }

    function whereAreMyTokens() public returns (uint) {
        return tokenLocation[tx.origin];
    }

    // move tokens to new contract if needed
    // call fallback of current contract
    function () public payable {
        // try to call current contract fallback
        moveTokens();
        address _contract = contracts[currVersion];
        _contract.call.value(msg.value).gas(20000)();
    }

    // ERC223 token fallback function
    // return true if tokenFallback of ShyftKycContract called; otherwise false
    function tokenFallback(address _from, uint256 _value, bytes _data) public returns (bool) {
        // pay fallback of current contract
        bytes4 sig = bytes4(keccak256(abi.encodePacked("tokenFallback(address,uint,bytes)")));
        address _contract = address(shyftKycContract); //contracts[currVersion];
        bool res = _contract.call(sig, _from, _value, _data);
        
        // if tokens not in current contract, move them
        moveTokens();
    
        emit EVT_ERC223TokenFallback(_from, _value, _data);
        return res;
    }
    
    // forwards tokens to new contract version if needed, then calls withdraw of the current contract 
    // same parameters
    // returns true if withdraw in ShyftKycContract was called; otherwise false
    function withdraw(address _to, uint _value) public returns (bool) {
        moveTokens();        
        // call withdraw of current contract
        bytes4 sig = bytes4(keccak256(abi.encodePacked("withdraw(address,uint256)"))); // function signature
        address _contract = address(shyftKycContract);
        return _contract.call(sig, _to, _value);
    }

    // _contractTo could be a user address, doesn't have to be a contract address
    // however in this context we'll only be using a contract address

    // return true if tokens were withdrawn to a contract, false otherwise
    function withdrawAll(address _contractTo, address _contractFrom) internal returns (bool) {
        bytes4 sig = bytes4(keccak256(abi.encodePacked("withdrawAll(address)"))); // function signature
        uint codeLength;
        bool res = false;

        assembly {
            codeLength := extcodesize(_contractFrom)
        }

        // make sure we're withdrawing from a contract
        if(codeLength > 0){
            res = _contractFrom.call(sig, _contractTo);
        }

        return res;
    }
    
    
    // move msg.sender's tokens from contract where their tokens were to current contract
    // return true if tokens are moved (ie. contract was upgraded); otherwise false
    function moveTokens () internal returns (bool) {
        if (tokenLocation[tx.origin] == currVersion){
            return false;
        }

        else {
            address _contractFrom = contracts[tokenLocation[tx.origin]]; 
            address _contractTo = contracts[currVersion]; 
            tokenLocation[tx.origin] = currVersion;
            withdrawAll(_contractTo, _contractFrom);
            
            return true;
        }        
    }
}