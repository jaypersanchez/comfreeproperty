pragma solidity ^0.4.19;

contract ITrustAnchorManager {
    function isTrustAnchorVerified(address _trustAnchorAddress) public view returns (bool result);

    function getTrustAnchorIndex(address _trustAnchorAddress) public view returns (uint32 result);
    
    function getTrustAnchorJurisdiction(address _trustAnchorAddress) public returns (uint16 result);

    function isPrimeRevocationManager(address _primeRevocationManagerAddress) public returns (bool result);
}
