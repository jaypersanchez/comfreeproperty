pragma solidity ^0.4.19;
import "../DataModels/DMTrustAnchorAttestation.sol";

contract ITrustChannelManager is DMTrustAnchorAttestation {
    function getTrustChannelLowestSubmapNumberForTrustAnchorIndex(uint32 _trustAnchorIndex) public view returns (uint24 result);
    function getTrustChannelHighestSubmapNumberForTrustAnchorIndex(uint32 _trustAnchorIndex) public view returns (uint24 result);
    function getTrustChannelIndexBitFieldAtSubmapNumberForTrustAnchorIndex(uint32 _trustAnchorIndex, uint24 submapNumber) public view returns (uint256 result);

    function route(uint256 _amount, address _senderIdentifiedAddress, address _receiverIdentifiedAddress, uint32 _trustChannelIndex) public returns (int16 result);
}
