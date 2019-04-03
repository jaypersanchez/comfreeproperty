pragma solidity ^0.4.19;
import "../DataModels/DMTrustAnchorAttestation.sol";

contract ITrustAnchorStorage is DMTrustAnchorAttestation {
    function getTrustAnchorManagerAddress() public view returns (address result);

    function setAttestation(address _identifiedAddress,
                            uint16 _jurisdiction,
                            uint64 _effectiveTime,
                            uint64 _expiryTime,
                            bytes _publicData,
                            bytes _documentsEncrypted,
                            bytes32 _documentAvailabilityEncrypted) public returns (uint8 result);

//    function getAttestation(bytes32 _attestationKeccak) public view returns (trustAnchorAttestation attestation);

    function getAttestationKeccakArrayLengthForIdentifiedAddress(address _identifiedAddress) public view returns (uint16 keccakArrayLength);

    function getAttestationTrustAnchorAddress(bytes32 _attestationKeccak) public view returns (address trustAnchorAddress);
    function getAttestationTrustAnchorIndex(bytes32 _attestationKeccak) public view returns (uint32 trustAnchorIndex);

    function getAttestationKeccakArrayForIdentifiedAddress(address _identifiedAddress) public view returns (bytes32[] keccakArray);

    function getIndexedAttestationKeccakHashForIdentifiedUser(address _identifiedAddress,uint16 _index) public view returns (bytes32 keccakHash);
    function getIndexedAttestationJurisdictionForIdentifiedUser(address _identifiedAddress, uint16 _index) public view returns (uint16 jurisdiction);
    function getIndexedAttestationEffectiveTimeForIdentifiedUser(address _identifiedAddress, uint16 _index) public view returns (uint256 effectiveTime);
    function getIndexedAttestationExpiryTimeForIdentifiedUser(address _identifiedAddress, uint16 _index) public view returns (uint256 expiryTime);
    function getIndexedAttestationDocumentAvailabilityEncryptedForIdentifiedUser(address _identifiedAddress, uint16 _index) public view returns (bytes32 documentAvailabilityEncrypted);

    function getGraphConstructableAttestationInKeccakArray(address _identifiedAddress, uint16 _index) public view returns ( bytes32 keccakHash,
                                                                                                                            uint32 trustAnchorIndex,
                                                                                                                            uint16 jurisdiction,
//                                                                                                                            uint256 effectiveTime,
//                                                                                                                            uint256 expiryTime,
                                                                                                                            bool attestationStatusApproved);
//                                                                                                                            bytes32 documentAvailabilityEncrypted);
    function getAttestationStatusApprovedInKeccakArray(address _identifiedAddress, uint16 _index) public view returns (bool attestationStatusApproved);
    function getConsentAvailableInKeccakArray(address _identifiedAddress, uint16 _index) public view returns (uint8 consentAvailable);
    function getTrustAnchorAddressInKeccakArray(address _identifiedAddress, uint16 _index) public view returns (address trustAnchorAddress);
    function getAttestationValiditySignaturesInKeccakArray(address _identifiedAddress, uint16 _index) public view returns ( uint8 validityTrustAnchorSignatureV,
                                                                                                                            bytes32[2] validityTrustAnchorSignatureRS,
                                                                                                                            uint8 validityUserSignatureV,
                                                                                                                            bytes32[2] validityUserSignatureRS);

    function getAttestationValidationsArrayLengthInKeccakArray(address _identifiedAddress, uint16 _index) public view returns (uint16 arrayLength);
    function getAttestationDataRetrievalsArrayLengthInKeccakArray(address _identifiedAddress, uint16 _index) public view returns (uint16 arrayLength);
}
