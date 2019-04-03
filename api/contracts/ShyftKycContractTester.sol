pragma solidity ^0.4.17;

import "./ShyftKycContract.sol";

contract ShyftKycContractTester {
	ShyftKycContract public shyftKycContract;
	address public contractAddr;

    function init(address _addr) public returns (address) {
        shyftKycContract = ShyftKycContract(_addr);
        contractAddr = _addr;
        return address(shyftKycContract);
    }

    function callWithdraw(uint _val) public {
    	bytes4 sig = bytes4(keccak256(abi.encodePacked("withdraw(address,uint256)")));
    	contractAddr.call(sig, address(this), _val);
    }

    // test for recursion
    function() payable {
    	bytes4 sig = bytes4(keccak256(abi.encodePacked("withdraw(address,uint256)")));
    	contractAddr.call(sig, address(this), msg.value);
    }

}