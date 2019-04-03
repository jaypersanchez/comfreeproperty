pragma solidity ^0.4.19;

contract IShyftConduit {
    function withdrawFullIndividualContermiousDistribution() public;

    function isPrimeRevocationManager(address _primeRevocationManagerAddress) public returns (bool result);
}
