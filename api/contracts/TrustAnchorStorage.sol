pragma solidity ^0.4.19;

import "./Interfaces/ITrustAnchorStorage.sol";
import "./Interfaces/ITrustAnchorManager.sol";
import "./Interfaces/IShyftCacheGraph.sol";

import "./ECRecovery.sol";
import "./Administrable.sol";

contract TrustAnchorStorage is DMTrustAnchorAttestation, Administrable, ITrustAnchorStorage {
    //@note: due to https://github.com/trufflesuite/truffle-contract/issues/8
    // events will not log from called contracts (in the attestation revocation call for instance).
    // this allows for debugging internally.
//    event EVT_UpdatingCacheGraph(address _identifiedAddress,
//        uint16 updateLength,
//        uint16 oldAttestationKeccakArrayLength,
//        uint16 attestationKeccakArrayLength);
//    event EVT_DoCompileCacheGraph(address _identifiedAddress,
//        uint32 i,
//        uint16 idx);
//    event EVT_DoConditionallyRemoveTrustChannelEXBitFields(address _identifiedAddress,
//        uint32 trustAnchorIndex,
//        bytes32 keccakHash);
//    event EVT_GotAttestationStatus(address _identifiedAddress,
//        bool attestationStatusApproved,
//        bool didChangeApprovedStatus,
//        uint16 attestationIndex,
//        bool attestationHasAlreadyBeenProcessed);
//    event EVT_CompareTime(uint256 _effectiveTime,
//        uint256 blockTimestamp,
//        uint256 _expiryTime,
//        bool isActive);
//    event EVT_DoCompileCacheGraphTrustChannelEXBitFields(address _identifiedAddress,
//        bytes32 keccakHash,
//        bool consentAvailable);
//    event EVT_GetActiveTrustChannelEXBitFieldLength(uint24 senderHighestSubmapNumber,
//        uint24 receiverHighestSubmapNumber,
//        uint256 senderBitfield,
//        uint256 receiverBitfield,
//        uint256 andedBitField);
//    event EVT_GotBitFieldFromTrustAnchor(address trustAnchorAddress,
//        uint32 trustAnchorIndex,
//        uint256 bitField);

    event EVT_TrustChannelBitFieldWords(uint32 bitFieldWords);
    event EVT_TrustChannelBitFieldIndex(uint16 trustChannelIndex);
    event EVT_TrustChannelBitFieldIndexEXT(uint32 index,
        uint32 shifter,
        uint32 trustChannelBitFieldWord,
        uint256 trustChannelBitField,
        uint16 trustChannelIndex);

    event EVT_GotHighestSubmapNumbers(uint24 senderHighestSubmapNumber,
        uint24 receiverHighestSubmapNumber);

    event EVT_GotLowestAndHighestTrustChannelSubmapNumber(uint24 lowestTrustChannelSubmapNumber,
        uint24 highestTrustChannelSubmapNumber);

    event EVT_TrustChannelRouted(uint24 trustChannelIndex,
        address _senderIdentifiedAddress,
        address _receiverIdentifiedAddress);

    event EVT_setAttestation(bytes32 attestationKeccak,
        address msg_sender,
        address _identifiedAddress,
        uint16 _jurisdiction,
        uint256 _effectiveTime,
        uint256 _expiryTime,
        bytes32 _publicData_0,
        bytes32 _documentsEncrypted_0,
        bytes32 _documentAvailabilityEncrypted);

    event EVT_REQ_revokeAttestation(bytes32 _attestationKeccak);

    event EVT_revokeAttestation(bytes32 _attestationKeccak,
        address trustAnchorAddress,
        uint16 keccakArrayIndex);

    event EVT_revokeAttestationDoRecompile(address shyftCacheGraphAddress);

    //get/set attestation keccak hash to storage of the attestation
    mapping(bytes32 => trustAnchorAttestation) attestationKeccak_to_attestation;
    //add/remove attestation keccak hash array to trust anchor's list
    mapping(address => bytes32[]) trustAnchorAddress_to_attestationKeccakArray;

    //get/set attestation keccak hash to identified address
    mapping(bytes32 => address) attestationKeccak_to_identifiedAddress;
    //add/remove attestation keccak hash array to user's list
    mapping(address => bytes32[]) identifiedAddress_to_attestationKeccakArray;

    mapping(bytes32 => uint16) attestationKeccak_to_identifiedAddressAttestationKeccakArrayIndex;

    //@note:@checkwhenupdating: this is inside of the TrustAnchorReferenceCompatible contract, as to allow access to the struct via inheritance.
    // struct trustAnchorAttestation {
    //     address attestorAddress;

    //     address identifiedAddress;
    //     uint16 jurisdiction;
    //     uint64 effectiveTime;
    //     uint64 expiryTime;
    //     bytes publicData;

    //     bytes documentsEncrypted;
    //     bytes32 documentAvailabilityEncrypted;

    //     bytes32 trustAnchorPublicAddressEncrypted;

    //     bytes attestationValidityTrustAnchorSignature;
    //     bytes attestationValidityUserSignature;

    //     uint16 fieldsDirtyBitMap;
    // }

    address internal trustAnchorManagerAddress = address(0);
    address internal shyftCacheGraphAddress = address(0);

    constructor() public {
        owner = msg.sender;
    }
    
    //returns:
    // 0 = not an administrator
    // 1 = only one administrator has permissioned change
    // 2 = trust anchor set
    
    function setTrustAnchorManagerAddress(address _trustAnchorManagerAddress) public returns (uint8 result) {
        require(_trustAnchorManagerAddress != address(0));

        if (isAdministrator(msg.sender)) {
            bytes32 keyKeccak = keccak256(abi.encodePacked("trustAnchorManagerAddress", _trustAnchorManagerAddress));
            
            uint16 numPermissions = getPermissionsForMultisignKey(keyKeccak);
            
            bool permittedToModify;
            
            if (numPermissions >= maxThreshold) {
                permittedToModify = true;
            } else {
                uint16 numConfirmedPermissions = adminApplyAndGetPermissionsForMultisignKey(keyKeccak);
                
                if (numConfirmedPermissions >= maxThreshold) {
                    permittedToModify = true;
                } 
            }
            
            if (permittedToModify == true) {
                trustAnchorManagerAddress = _trustAnchorManagerAddress;

                adminResetPermissionsForMultisignKey(keyKeccak);
                
                // trust anchor set
                return 2;

            } else {
                // not enough administrators have permissioned change
                return 1;
            }
        } else {
            // not an administrator
            return 0;
        }
    }

    //returns:
    // 0 = not an administrator
    // 1 = only one administrator has permissioned change
    // 2 = trust anchor set

    function setShyftCacheGraphAddress(address _shyftCacheGraphAddress) public returns (uint8 result) {
        require(_shyftCacheGraphAddress != address(0));

        if (isAdministrator(msg.sender)) {
            bytes32 keyKeccak = keccak256(abi.encodePacked("shyftCacheGraphAddress", _shyftCacheGraphAddress));

            uint16 numPermissions = getPermissionsForMultisignKey(keyKeccak);

            bool permittedToModify;

            if (numPermissions >= maxThreshold) {
                permittedToModify = true;
            } else {
                uint16 numConfirmedPermissions = adminApplyAndGetPermissionsForMultisignKey(keyKeccak);

                if (numConfirmedPermissions >= maxThreshold) {
                    permittedToModify = true;
                }
            }

            if (permittedToModify == true) {
                shyftCacheGraphAddress = _shyftCacheGraphAddress;

                adminResetPermissionsForMultisignKey(keyKeccak);

                // trust anchor set
                return 2;

            } else {
                // not enough administrators have permissioned change
                return 1;
            }
        } else {
            // not an administrator
            return 0;
        }
    }

    //returns:
    // 0 = no trust anchor manager address set
    // !0 = trust anchor manager address

    function getTrustAnchorManagerAddress() public view returns (address result) {
        return trustAnchorManagerAddress;
    }


    // ** attestations caching and management ** //

    //results:
    // false = address not verified
    // true = verified address
    
    function isTrustAnchorVerified(address _trustAnchorAddress) internal view returns (bool result){
        ITrustAnchorManager trustAnchorManager = ITrustAnchorManager(trustAnchorManagerAddress);

        if (trustAnchorManager.isTrustAnchorVerified(_trustAnchorAddress)) {
            //verified address
            return true;
        } else {
            //address not verified
            return false;
        }
    }

    //results: (notes: the attestation can never be overwritten due to it being a sha3 hash, so the validity(sanity component) check simply saves gas.)
    // 0 = trust anchor is not verified
    // 1 = attestation not valid
    // 2 = attestation already exists
    // 3 = attestation set

    //@reference: for remix input
    //"0x405346187a971f064f33a8e1368bb86dbf054368", "0x85d14957f6d70b3b3921a460e12b5c88186e44ef", 12, 0, 0, "gdageagsgc", "rtryrturuyrt", "0xe0b59a365a026b8ce1524e5b1f293effd626b380", "0xe0b59a365a026b8ce1524e5b1f293effd626b380"
    //"0x405346187a971f064f33a8e1368bb86dbf054368", "0x85d14957f6d70b3b3921a460e12b5c88186e44ef", 12, 0, 0, "", "", "0xe0b59a365a026b8ce1524e5b1f293effd626b380", "0xe0b59a365a026b8ce1524e5b1f293effd626b380"

    //@note:@todo:@next:@here: maybe adding in coinflip-blinding around specific data fields & hence total kyc level would make sense.
    // so it'd turn into a statistically relative level that could be attested to, without revealing the exact dimensionality of the
    // individual's data.

    function setAttestation(address _identifiedAddress,
                            uint16 _jurisdiction,
                            uint64 _effectiveTime,
                            uint64 _expiryTime,
                            bytes _publicData,
                            bytes _documentsEncrypted,
                            bytes32 _documentAvailabilityEncrypted) public returns (uint8 result) {
        if (isTrustAnchorVerified(msg.sender)) {
            // Notes on Keccak hash:
            // the bitmap from the _documents is used
            // so is the nonce (first 8 bit unsigned int) from the publicData field.

            bytes32 attestationKeccak;

            if (_publicData.length > 0 && _documentsEncrypted.length > 0) {
                attestationKeccak = keccak256(abi.encodePacked(
                                                msg.sender,
                                                _identifiedAddress,
                                                _jurisdiction,
                                                _effectiveTime,
                                                _expiryTime,
                                                bytes32(_publicData[0]),
                                                bytes32(_documentsEncrypted[0]),
                                                _documentAvailabilityEncrypted));
            } else {
                if (_documentsEncrypted.length > 0) {
                    attestationKeccak = keccak256(abi.encodePacked(
                                                    msg.sender,
                                                    _identifiedAddress,
                                                    _jurisdiction,
                                                    _effectiveTime,
                                                    _expiryTime,
                                                    bytes32(_documentsEncrypted[0]),
                                                    _documentAvailabilityEncrypted));
                } else {
                    attestationKeccak = keccak256(abi.encodePacked(
                                                    msg.sender,
                                                    _identifiedAddress,
                                                    _jurisdiction,
                                                    _effectiveTime,
                                                    _expiryTime,
                                                    _documentAvailabilityEncrypted));
                }
            }

            uint8 verificationStatus = verifyAttestationValidity(attestationKeccak,
                                                                _identifiedAddress,
                                                                _documentsEncrypted,
                                                                _documentAvailabilityEncrypted);
            // uint8 verificationStatus = 1;

            emit EVT_setAttestation(attestationKeccak,
                msg.sender,
                _identifiedAddress,
                _jurisdiction,
                _effectiveTime,
                _expiryTime,
                bytes32(_publicData[0]),
                bytes32(_documentsEncrypted[0]),
                _documentAvailabilityEncrypted);

            if (verificationStatus == 1) {
                //@note: @checkwhenupdating: for reference
                // address attestorAddress;

                // address identifiedAddress;
                // uint16 jurisdiction;
                // uint64 effectiveTime;
                // uint64 expiryTime;
                // bytes publicData;

                // bytes documentsEncrypted;
                // bytes32 documentAvailabilityEncrypted;

                // bytes32 trustAnchorPublicAddressEncrypted;

                if (attestationKeccak_to_identifiedAddress[attestationKeccak] == 0) {
                    //set the main attestation in storage
                    ITrustAnchorManager trustAnchorManager = ITrustAnchorManager(trustAnchorManagerAddress);

                    trustAnchorAttestation storage newAttestation = attestationKeccak_to_attestation[attestationKeccak];
                    newAttestation.attestationStatusApproved = (_effectiveTime <= (block.timestamp * 1000) && (_expiryTime == 0 || _expiryTime > (block.timestamp * 1000)));

                    newAttestation.trustAnchorAddress = msg.sender;
                    newAttestation.trustAnchorIndex = trustAnchorManager.getTrustAnchorIndex(msg.sender);
                    newAttestation.identifiedAddress = _identifiedAddress;
                    newAttestation.jurisdiction = _jurisdiction;
                    newAttestation.effectiveTime = _effectiveTime;
                    newAttestation.expiryTime = _expiryTime;
                    newAttestation.publicData = _publicData;

                    newAttestation.documentsEncrypted = _documentsEncrypted;
                    newAttestation.documentAvailabilityEncrypted = _documentAvailabilityEncrypted;

                    //add the attestation keccak to the trust anchor's list
                    //@note:@here:@todo: not checking bounds.. will this be an issue?
                    trustAnchorAddress_to_attestationKeccakArray[msg.sender].push(attestationKeccak);
                    //create a attestation keccak to end-user mapping
                    attestationKeccak_to_identifiedAddress[attestationKeccak] = _identifiedAddress;
                    //add the attestation keccak to the users's list
                    //@note:@here:@todo: not checking bounds.. will this be an issue?
                    attestationKeccak_to_identifiedAddressAttestationKeccakArrayIndex[attestationKeccak] = uint16(identifiedAddress_to_attestationKeccakArray[_identifiedAddress].length);
                    identifiedAddress_to_attestationKeccakArray[_identifiedAddress].push(attestationKeccak);

                    //attestation set
                    return 3;
                } else {
                    // attestation already exists
                    return 2;
                }
            } else {
                //attestation validity/signature mapping [from verifyAttestationValidity :: 0 = not valid: 2 = invalid signature]
                if (verificationStatus == 0) {
                    //attestation not valid
                    return 1;
                }
            }
        } else {
            //trust anchor is not verified
            return 0;
        }
    }

    //@note:@here:@todo:@next: in the case where consent has changed, there should be a method of updating (appending to the "consented" trust channel mappings for instance) the associated attestations.
    // otherwise, compiling a non-consented (yet) attestation will prevent the compilation to the consented channels.

    //@note: in this sense, this attestation has the consent of the trust anchor to be published.
    // causes a secondary consented attestation and the ability of this to be published on the fully consented trust
    // channel rails.

    //results:
    // 0 = not the trust anchor address that created this attestation
    // 0 = already signed
    // 1 = invalid signature
    // 2 = stored valid signature
    function signAttestationTrustAnchorSignature(bytes32 _attestationKeccak, uint8 _attestationValidityTrustAnchorSignatureV, bytes32[2] _attestationValidityTrustAnchorSignatureRS) public returns (uint8 result) {
        trustAnchorAttestation storage attestation = attestationKeccak_to_attestation[_attestationKeccak];

        if (attestation.trustAnchorAddress == msg.sender) {
            if (attestation.attestationValidityTrustAnchorSignatureRS[0] != 0) {
                bytes32 attestationAndTrustAnchorAddressKeccak = keccak256(abi.encodePacked(_attestationKeccak, msg.sender));
                
                address recoveredAddress = ecrecover(attestationAndTrustAnchorAddressKeccak, _attestationValidityTrustAnchorSignatureV, _attestationValidityTrustAnchorSignatureRS[0], _attestationValidityTrustAnchorSignatureRS[1]);
                // address recoveredAddress = ECRecovery.recover(_attestationKeccak, _attestationValidityTrustAnchorSignature);
                // this should recover the trust anchor's address, but this is encrypted...
                if (recoveredAddress == msg.sender) {
                    attestation.attestationValidityTrustAnchorSignatureV = _attestationValidityTrustAnchorSignatureV;
                    attestation.attestationValidityTrustAnchorSignatureRS = _attestationValidityTrustAnchorSignatureRS;

                    attestation.consentAvailable++;
                    
                    //stored valid signature
                    return 3;
                } else {
                    //invalid signature
                    return 2;
                }
            } else {
                //already signed
                return 1;
            }
        } else {
            //not the trust anchor address that created this attestation
            return 0;
        }
    }

    //@note: in this sense, this attestation has the consent of the user to be associated with their address.
    // prevents spam attestations from being considered on the consented rails.

    //results:
    // 0 = not the user address that is associated with this attestation
    // 0 = already signed
    // 1 = invalid signature
    // 2 = stored valid signature
    function signAttestationUserSignature(bytes32 _attestationKeccak, uint8 _attestationValidityUserSignatureV, bytes32[2] _attestationValidityUserSignatureRS) public returns (uint8 result) {
        trustAnchorAttestation storage attestation = attestationKeccak_to_attestation[_attestationKeccak];

        if (attestation.identifiedAddress == msg.sender) {
            if (attestation.attestationValidityUserSignatureRS[0] != 0) {
                bytes32 attestationAndUserAddressKeccak = keccak256(abi.encodePacked(_attestationKeccak, msg.sender));

                address recoveredAddress = ecrecover(attestationAndUserAddressKeccak, _attestationValidityUserSignatureV, _attestationValidityUserSignatureRS[0], _attestationValidityUserSignatureRS[1]);
                // address recoveredAddress = ECRecovery.recover(_attestationKeccak, _attestationValidityTrustAnchorSignature);
                // this should recover the trust anchor's address, but this is encrypted...
                if (recoveredAddress == msg.sender) {
                    attestation.attestationValidityUserSignatureV = _attestationValidityUserSignatureV;
                    attestation.attestationValidityUserSignatureRS = _attestationValidityUserSignatureRS;

                    attestation.consentAvailable++;

                    //stored valid signature
                    return 3;
                } else {
                    //invalid signature
                    return 2;
                }
            } else {
                //already signed
                return 1;
            }
        } else {
            //not the user address that is associated with this attestation
            return 0;
        }
    }

    //@note: @here: @todo: @optimization: should build a function to clear (only by admin access) data by previous (offchain) computation of dirty objects.
    // this should only be used however once we know what the cost (and thus the gas savings of the storage) would look like to rebuild identifiedAddress graph caches.
    // function clearAttestationNoCheck(bytes32 _attestationKeccak) public returns (uint8 result) {
    //     if (isTrustAnchorVerified(msg.sender)) {
    //         trustAnchorAttestation storage attestation = attestationKeccak_to_attestation[_attestationKeccak];
    //         if (msg.sender == attestation.attestorAddress) {
    //             delete attestation.identifiedAddress;
    //             delete attestation.jurisdiction;
    //             delete attestation.effectiveTime;
    //             delete attestation.expiryTime;
    //             delete attestation.documentsEncrypted;
    //             delete attestation.documentAvailabilityEncrypted;
    //             delete attestation.publicData;
    //         }
    //         return 1;
    //     }

    //     //trust anchor not verified
    //     return 0;
    // }

    //results:
    // 0 = not valid
    // 1 = valid attestation
    function verifyAttestationValidity( bytes32 _attestationKeccak,
                                        address _identifiedAddress,
                                        bytes _documentsEncrypted,
                                        bytes32 _documentAvailabilityEncrypted) internal pure returns (uint8 result) {
        if (_attestationKeccak != 0 &&
            _identifiedAddress != address(0) &&
            _documentsEncrypted.length != 0 &&
            _documentAvailabilityEncrypted != 0) {
            //valid attestation
            return 1;
        } else {
            //not valid
            return 0;
        }
    }

    //@note: revokes attestations. can be used by Shyft's prime revocation manager.
    //@note:@todo:@audit:@review: what happens when a TA's attestation key is revoked.. should they still be allowed
    // to revoke attestations?

    //results:
    // 0 = trust anchor not verified
    // 1 = no non-revoked attestation found
    // 2 = attestation revoked
    function revokeAttestation(bytes32 _attestationKeccak) public returns (uint8 result) {
        ITrustAnchorManager trustAnchorManager = ITrustAnchorManager(trustAnchorManagerAddress);

        trustAnchorAttestation storage attestation = attestationKeccak_to_attestation[_attestationKeccak];

        emit EVT_REQ_revokeAttestation(_attestationKeccak);
//        EVT_revokeAttestation(_attestationKeccak, attestation.trustAnchorAddress, attestationKeccak_to_identifiedAddressAttestationKeccakArrayIndex[_attestationKeccak]);

        //@note:@todo:@audit: should trust anchors that have been revoked be able to revoke previously signed
        // messages?

//        if (isTrustAnchorVerified(msg.sender)) {
        if (attestation.trustAnchorAddress == msg.sender || trustAnchorManager.isPrimeRevocationManager(msg.sender)) {
            if (attestation.identifiedAddress != address(0) &&
                attestation.attestationStatusApproved == true) {
                attestation.attestationStatusApproved = false;

//                EVT_revokeAttestationDoRecompile(shyftCacheGraphAddress);

                //recompile cache graph of the identifiedAddress that would depend on this attestation.
                IShyftCacheGraph shyftCacheGraph = IShyftCacheGraph(shyftCacheGraphAddress);

                shyftCacheGraph.compileCacheGraph(attestation.identifiedAddress,
                    attestationKeccak_to_identifiedAddressAttestationKeccakArrayIndex[_attestationKeccak]);

                //attestation revoked
                return 2;
            } else {
                //no non-revoked attestation found
                return 1;
            }
        } else {
            //trust anchor not verified
            return 0;
        }
    }

    // ** data retrieval entities management and validation ** //

    //returns:
    // 0 = trust anchor is not verified
    // 1 = not the trust anchor address that created this attestation
    // 2 = attestation already has this data retrieval target
    // 3 = data retrieval target set

    //@note:@here:@todo:@next: add the ability for the identifiedAddress specified in an attestation to allow a data
    // retrieval target (possibly a 2 stage process, where the user adds their consent to this transfer, and then the
    // Trust Anchor initiates the transference through this interface).
    //
    //@note:@todo:@next: Also required is a time limit to this data retrieval event. (1 week, 1 month, etc).
    // also, should this have a bitfield to scope the data retrieval allowed? being on the blockchain, this might
    // require an encryption pass with the result being a public key encrypted from the TA to the user.
    // If this is required, a registering TA should provide a public key to perform the RSA-like encryption of small
    // messages. PGP-like.
    function addDataRetrievalTarget(bytes32 _attestationKeccak, address _dataRetrievalTarget) public returns (uint8 result) {
        if (isTrustAnchorVerified(msg.sender)) {
            trustAnchorAttestation storage attestation = attestationKeccak_to_attestation[_attestationKeccak];
            if (attestation.trustAnchorAddress == msg.sender) {
                if (attestation.dataRetrievalTargets[_dataRetrievalTarget] != false) {
                    attestation.dataRetrievalTargets[_dataRetrievalTarget] = true;
                    attestation.dataRetrievalTargetsArray.push(_dataRetrievalTarget);

                    //data retrieval target set
                    return 3;
                } else {
                    //attestation already has this data retrieval target
                    return 2;
                }
            } else {
                //not the trust anchor address that created this attestation
                return 1;
            }
        } else {
            //trust anchor is not verified
            return 0;
        }
    }


    //@note: validates an existing attestation with another trust anchor. useful step after validating out-of-band
    // data source(s).

    //results:
    // 0 = attestation does not exist
    // 1 = attestation cannot be signed by the trust anchor that set the attestation
    // 2 = attestation data source(s) have not been sent to this entity
    // 3 = attestation already validated by this entity
    // 4 = attestation validated
    //@note:@todo:@next: generalize this and confirm
    function dataRetrievalEntityValidateAttestation(bytes32 _attestationKeccak) public returns (uint8 result) {
        trustAnchorAttestation storage attestation = attestationKeccak_to_attestation[_attestationKeccak];

        if (attestation.trustAnchorAddress != address(0)) {
            if (attestation.trustAnchorAddress != msg.sender) {
                if (attestation.dataRetrievalTargets[msg.sender] != false) {
                    if (attestation.validations[msg.sender] != false) {
                        attestation.validationsArray.push(msg.sender);

                        //attestation validated
                        return 4;
                    } else {
                        //attestation already validated by this entity
                        return 3;
                    }
                } else {
                    //attestation data source(s) have not been sent to this entity
                    return 2;
                }
            } else {
                //attestation cannot be signed by the trust anchor that set the attestation
                return 1;
            }
        } else {
            //attestation does not exist
            return 0;
        }
    }

//    function getAttestation(bytes32 _attestationKeccak) public view returns (trustAnchorAttestation attestation) {
//        return attestationKeccak_to_attestation[_attestationKeccak];
//    }

    function getAttestationKeccakArrayLengthForIdentifiedAddress(address _identifiedAddress) public view returns (uint16 keccakArrayLength) {
        //@note:@here:256 attestations maximum for current bitfield size, however it's not useful for overflows to be blocked
        return uint16(identifiedAddress_to_attestationKeccakArray[_identifiedAddress].length);
    }

    function getAttestationTrustAnchorAddress(bytes32 _attestationKeccak) public view returns (address trustAnchorAddress) {
        return attestationKeccak_to_attestation[_attestationKeccak].trustAnchorAddress;
    }

    function getAttestationTrustAnchorIndex(bytes32 _attestationKeccak) public view returns (uint32 trustAnchorIndex) {
        return attestationKeccak_to_attestation[_attestationKeccak].trustAnchorIndex;
    }

    //@note:@here:@todo: this will copy the memory if it's not passed as storage
    function getAttestationKeccakArrayForIdentifiedAddress(address _identifiedAddress) public view returns (bytes32[] keccakArray) {
        return identifiedAddress_to_attestationKeccakArray[_identifiedAddress];
    }
    
    /*
    * The returning value is for keccakHash and not for error codes.  In order to avoid adding a second return value, 
    * if the calling function passes an _index value greater than the length of the array, it will return a zero, 0, value
    * if the _index is within the boundary of the array, it will naturally return the keccakHash value
    * For mapping, if a value is passed that does not exist in the mapping array, the response is just a value of zero
    * mappings do not throw an exception error
    */
    function getIndexedAttestationKeccakHashForIdentifiedUser(address _identifiedAddress, uint16 _index) public view returns (bytes32 keccakHash) {
        //@note:@here:@todo: not checking bounds.. most likely this will return a VM error if out of bounds on the check.
        /*
        * array length is in uint256 but _index is in uint16.  Even if a value is past greater than the range of uint16
        * there will be lost of data basically garaunting the parameter value will always be less than uint256
        * The boundary check is just to make sure this will never happen
        */
        if( _index < identifiedAddress_to_attestationKeccakArray[_identifiedAddress].length ) {
            return identifiedAddress_to_attestationKeccakArray[_identifiedAddress][_index];
        }
        else {
            return 0;
        }
            
        
    }

    function getIndexedAttestationJurisdictionForIdentifiedUser(address _identifiedAddress, uint16 _index) public view returns (uint16 jurisdiction) {
        //@note:@here:@todo: not checking bounds.. most likely this will return a VM error if out of bounds on the check.
        if(  _index < identifiedAddress_to_attestationKeccakArray[_identifiedAddress].length) {
            return attestationKeccak_to_attestation[identifiedAddress_to_attestationKeccakArray[_identifiedAddress][_index]].jurisdiction;
        }
        else {
            return 0;
        }
        
    }

    function getIndexedAttestationEffectiveTimeForIdentifiedUser(address _identifiedAddress, uint16 _index) public view returns (uint256 effectiveTime) {
        //@note:@here:@todo: not checking bounds.. most likely this will return a VM error if out of bounds on the check.
        if(_index < identifiedAddress_to_attestationKeccakArray[_identifiedAddress].length) {
            return attestationKeccak_to_attestation[identifiedAddress_to_attestationKeccakArray[_identifiedAddress][_index]].effectiveTime;
        }
        else {
            return 0;
        }
    }

    function getIndexedAttestationExpiryTimeForIdentifiedUser(address _identifiedAddress, uint16 _index) public view returns (uint256 expiryTime) {
        //@note:@here:@todo: not checking bounds.. most likely this will return a VM error if out of bounds on the check.
        if(_index < identifiedAddress_to_attestationKeccakArray[_identifiedAddress].length) {
            return attestationKeccak_to_attestation[identifiedAddress_to_attestationKeccakArray[_identifiedAddress][_index]].expiryTime;
        }
        else {
            return 0;
        }
    }

    function getIndexedAttestationDocumentAvailabilityEncryptedForIdentifiedUser(address _identifiedAddress, uint16 _index) public view returns (bytes32 documentAvailabilityEncrypted) {
        //@note:@here:@todo: not checking bounds.. most likely this will return a VM error if out of bounds on the check.
        return attestationKeccak_to_attestation[identifiedAddress_to_attestationKeccakArray[_identifiedAddress][_index]].documentAvailabilityEncrypted;
    }

    function getGraphConstructableAttestationInKeccakArray(address _identifiedAddress, uint16 _index) public view returns ( bytes32 keccakHash,
                                                                                                                            uint32 trustAnchorIndex,
                                                                                                                            uint16 jurisdiction,
//                                                                                                                            uint256 effectiveTime,
//                                                                                                                            uint256 expiryTime,
                                                                                                                            bool attestationStatusApproved) {
//                                                                                                                            bytes32 documentAvailabilityEncrypted) {
        //@note:@here:@todo: not checking bounds.. most likely this will return a VM error if out of bounds on the check.
        bytes32 attestationKeccakHash = identifiedAddress_to_attestationKeccakArray[_identifiedAddress][_index];
        trustAnchorAttestation storage attestation = attestationKeccak_to_attestation[attestationKeccakHash];

        return (attestationKeccakHash,
                attestation.trustAnchorIndex,
                attestation.jurisdiction,
//                attestation.effectiveTime,
//                attestation.expiryTime,
                attestation.attestationStatusApproved);
//                attestation.documentAvailabilityEncrypted);
    }
    
    function getAttestationStatusApprovedInKeccakArray(address _identifiedAddress, uint16 _index) public view returns (bool attestationStatusApproved) {
        //@note:@here:@todo: not checking bounds.. most likely this will return a VM error if out of bounds on the check.
        if(_index < identifiedAddress_to_attestationKeccakArray[_identifiedAddress].length) {
            return attestationKeccak_to_attestation[identifiedAddress_to_attestationKeccakArray[_identifiedAddress][_index]].attestationStatusApproved;
        }
        else {
            return false;
        }
    }
    
    function getConsentAvailableInKeccakArray(address _identifiedAddress, uint16 _index) public view returns (uint8 consentAvailable) {
        //@note: return number of signatures for this attestation (currently user and trust anchor)
        //@note:@here:@todo: not checking bounds.. most likely this will return a VM error if out of bounds on the check.
        if(_index < identifiedAddress_to_attestationKeccakArray[_identifiedAddress].length) {
            return attestationKeccak_to_attestation[identifiedAddress_to_attestationKeccakArray[_identifiedAddress][_index]].consentAvailable;
        }
        else {
            return 0;
        }
    }

    function getTrustAnchorAddressInKeccakArray(address _identifiedAddress, uint16 _index) public view returns (address trustAnchorAddress) {
        //@note:@here:@todo: not checking bounds.. most likely this will return a VM error if out of bounds on the check.
        if(_index < identifiedAddress_to_attestationKeccakArray[_identifiedAddress].length) {
            return attestationKeccak_to_attestation[identifiedAddress_to_attestationKeccakArray[_identifiedAddress][_index]].trustAnchorAddress;
        }
        else {
            return address(0);
        }
    }
    
    function getAttestationValiditySignaturesInKeccakArray(address _identifiedAddress, uint16 _index) public view returns ( uint8 validityTrustAnchorSignatureV,
                                                                                                                            bytes32[2] validityTrustSignatureRS,
                                                                                                                            uint8 validityUserSignatureV,
                                                                                                                            bytes32[2] validityUserSignatureRS) {
        trustAnchorAttestation storage attestation = attestationKeccak_to_attestation[identifiedAddress_to_attestationKeccakArray[_identifiedAddress][_index]];
        //@note:@here:@todo: not checking bounds.. most likely this will return a VM error if out of bounds on the check.
        return (attestation.attestationValidityTrustAnchorSignatureV,
                attestation.attestationValidityTrustAnchorSignatureRS,
                attestation.attestationValidityUserSignatureV,
                attestation.attestationValidityUserSignatureRS);
    }

    function getAttestationValidationsArrayLengthInKeccakArray(address _identifiedAddress, uint16 _index) public view returns (uint16 arrayLength) {
        return uint16(attestationKeccak_to_attestation[identifiedAddress_to_attestationKeccakArray[_identifiedAddress][_index]].validationsArray.length);
    }

    function getAttestationDataRetrievalsArrayLengthInKeccakArray(address _identifiedAddress, uint16 _index) public view returns (uint16 arrayLength) {
        return uint16(attestationKeccak_to_attestation[identifiedAddress_to_attestationKeccakArray[_identifiedAddress][_index]].dataRetrievalTargetsArray.length);
    }
}