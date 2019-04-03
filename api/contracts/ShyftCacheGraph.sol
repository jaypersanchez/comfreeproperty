pragma solidity ^0.4.19;

import "./Interfaces/ITrustChannelManager.sol";
import "./Interfaces/ITrustAnchorStorage.sol";
import "./Interfaces/IShyftCacheGraph.sol";

import "./DebroujinBitUtils.sol";

/* ShyftCacheGraph.sol

    further ideas for parallelization:

    ex: 20 bits
    if there were 5 parameters say
    and the debroujin indexes were still the best way to find the items
    but you wanted a specific set of searches (active, consented, biometric, insured,
    reputation boundary condition reached)

    01000011000100001000

    bound. insur. biome. conse. active
    0100 | 0011 | 0001 | 0110 | 1101

    whatever the final result would be of the cache graph in this sense, the 256 bit word would only contain information
    about the # trust channels / # of parameters. ie. 4 parameters and 256 / 4 = 64 trust channels.

    obviously, the debroujin index would want to be a 64 bit version in that case.

    in any case, assuming active is required, all of the bits are then AND'd with a repeating version of

    1101 | 1101 | 1101 | 1101 | 1101
  & 0100 | 0011 | 0001 | 0110 | 1101
    --------------------------------
  = 0100 | 0001 | 0001 | 0100 | 1101

  the combined "active and consented" is within the (lower endian system) 6th index.

  accounts would both do this procedure with their existing mappings depending on the parameters to be searched, what
  the submap range tolerance would be (if any) for the combinations, and then the comparison would happen within a slice
  of that data range.


  this system would probably be the fastest equivalent of "look up the parameters at runtime and also be able to
  change the parameters without needing to revoke and recompile".

  not sure what the actual cost would look like however.

*/

contract ShyftCacheGraph is DebroujinBitUtils, IShyftCacheGraph {
    event EVT_UpdatingCacheGraph(address _identifiedAddress,
        uint16 updateLength,
        uint16 oldAttestationKeccakArrayLength,
        uint16 attestationKeccakArrayLength);
    event EVT_DoCompileCacheGraph(address _identifiedAddress,
        uint32 i,
        uint16 idx);
    event EVT_DoConditionallyRemoveTrustChannelEXBitFields(address _identifiedAddress,
        uint32 trustAnchorIndex,
        bytes32 keccakHash);
    event EVT_GotAttestationStatus(address _identifiedAddress,
        bool attestationStatusApproved,
        bool didChangeApprovedStatus,
        uint16 attestationIndex,
        bool attestationHasAlreadyBeenProcessed);
    event EVT_CompareTime(uint256 _effectiveTime,
        uint256 blockTimestamp,
        uint256 _expiryTime,
        bool isActive);
    event EVT_DoCompileCacheGraphTrustChannelEXBitFields(address _identifiedAddress,
        bytes32 keccakHash,
        bool consentAvailable);
    event EVT_GetActiveTrustChannelEXBitFieldLength(
        uint24 senderLowestSubmapNumber,
        uint24 senderHighestSubmapNumber,
        uint24 receiverLowestSubmapNumber,
        uint24 receiverHighestSubmapNumber,
        uint256 senderBitfield,
        uint256 receiverBitfield,
        uint256 andedBitField);
    event EVT_GotBitFieldFromTrustAnchor(address trustAnchorAddress,
        uint32 trustAnchorIndex,
        uint256 bitField);

    event EVT_TrustChannelBitFieldWords(uint32 bitFieldWords);
    event EVT_TrustChannelBitFieldIndex(uint32 trustChannelIndex);
    event EVT_TrustChannelBitFieldIndexEXT(uint32 index,
        uint32 shifter,
        uint32 trustChannelBitFieldWord,
        uint256 trustChannelBitField,
        uint32 trustChannelIndex);

    event EVT_GotHighestSubmapNumbers(uint24 senderHighestSubmapNumber,
        uint24 receiverHighestSubmapNumber);

    event EVT_GotLowestAndHighestTrustChannelSubmapNumber(uint24 lowestTrustChannelSubmapNumber,
        uint24 highestTrustChannelSubmapNumber);

    event EVT_TrustChannelRouted(uint32 trustChannelIndex,
        address _senderIdentifiedAddress,
        address _receiverIdentifiedAddress);

    enum CacheGraphStatus { Unknown, Enabled, Dirty, Disabled }

//    struct cacheGraphTrustAnchorListItem {
//        uint16 trustAnchorIndex;
//        //@note: forward linked list.
//        address nextLink;
//    }
//
    struct kycCacheGraph {
        bool exists;

        CacheGraphStatus graphStatus;
        //a list of the keccak hashes that correspond to lookups within the main Trust Anchor Reference contract.
        bytes32[] attestationKeccakArray;

        //array to next link in the trust anchors linked list. items are added based on the trust anchor index.
        mapping(uint32 => uint32) allTrustAnchorsThatHaveAttestedNextLinkMapping;

        //mapping for checks of whether the trust anchor previously existing for this identifiedAddress.
        mapping(uint32 => bool) allTrustAnchorIndexExistsMapping;

        //@note: I'm using underscores because I want to have easily readability when the camel case variable names get
        // this long.
        uint16 currentTrustAnchorsLinkedList_length;
        uint32 currentTrustAnchorLinkedList_zeldaIndex;
        uint32 currentTrustAnchorLinkedList_finalIndex;

        address[] allTrustAnchorsThatHaveAttested;

        mapping(uint32 => uint16) trustAnchorIndexToCountMap;
//        mapping(uint32 => mapping(uint32 => uint256)) trustAnchorEXBitField;

        mapping(uint32 => mapping(uint24 => uint256)) trustAnchorTrustChannelIndexEXBitField;
        mapping(uint32 => uint24) trustAnchorTrustChannelIndexEXBitFieldLowestSubmapNumber;
        mapping(uint32 => uint24) trustAnchorTrustChannelIndexEXBitFieldHighestSubmapNumber;

        //@note: for compilation processes.
        mapping(uint16 => bool) attestationHasAlreadyBeenProcessed;
        mapping(uint16 => bool) attestationPreviousApprovedStatus;

        //@note: these are too heavy for processing at the moment. another solution is found with the EX bit fields.
        //filters via keccak hash. *can be dirty*

        //attestation jurisdictions.
//        mapping(bytes32 => uint16) attestationJurisdictionMap;
//        mapping(bytes32 => bytes32) attestationStatusActiveMap;
//        mapping(bytes32 => bytes32) attestationStatusRevokedMap;
//        mapping(bytes32 => address) attestationTrustAnchorAddressMap;
//        mapping(bytes32 => bytes32) attestationTrustAnchorKeccakMap;

        //bit fields for documents. *can be dirty*
        // @note: hasJurisdictionBits is the bit field that contains whether the *indexable attestation space*
        // contains an attestation at this address
//        uint256 hasJurisdictionBits;
//        uint256 activeBits;
//        uint256 pendingBits;
//        uint256 expiredBits;
//        uint256 revokedBits;
//        uint256 documentAvailabilityBits;

        //note: these two bit fields record the active/active+consented status of that jurisdiction as the bit
        //index, for comparison across trust channels.

//        uint256 active_jurisdictionBits;
//        uint256 active_consented_jurisdictionBits;

//        mapping(uint16 => bytes32[]) activeJurisdictionAttestationArray;
//        mapping(uint16 => bytes32[]) activeConsentedJurisdictionAttestationArray;


        //extended bit fields (each 256-bit uint256 in the array is an index of 256 trust channels),
        //we use DebroujinBitUtils later on to do calculations and quick searches of this bit field.
        mapping(uint24 => uint256) activeTrustChannelEXBitField;
        mapping(uint24 => uint256) activeConsentedTrustChannelEXBitField;

        //we store the highest index as well for further quick calculations

        uint24 activeTrustChannelLowestSubmapNumber;
        uint24 activeTrustChannelHighestSubmapNumber;

        uint24 activeConsentedTrustChannelLowestSubmapNumber;
        uint24 activeConsentedTrustChannelHighestSubmapNumber;

        //bit fields for signature status. *can be dirty*
//        uint256 attestationValidityTrustAnchorSignatureAvailabilityBits;
//        uint256 attestationValidityUserSignatureAvailabilityBits;

        //maps out "material changes"
//        uint256 materialChangeBitField;

        //this is a bitwise or filter across all of the documents that are attested to this address.
        //it enables the quick detection of whether an address contains the specific documents.
//        bytes32 allDocumentsBitwiseOrFilter;
//        bytes32 activeDocumentsBitwiseOrFilter;

        //[@phase3] adds support for trust channels, where users can add multiple trust anchors and
        //run aggregator functions to prove their access to other institutions in collaborating
        //channels. 256 * 8 trust channels = 2048 total trust channels in map, probably a few bytes
        //reserved for auxiliary purposes.
//        bytes32[8] trustChannelMap;

        //[@phase3] add support for constructing the local view of the kyc level through disclosure of previous
        //activities on this trust channel.
        int8 constructedLocalKycLevel;
    }

    struct kycIdentity {
        // the kyc address keccak which is the hash of the corresponding look up table of the identity cache graph component of this struct.
        bytes32 kycIdentityKeccak;
        kycCacheGraph cacheGraph;
    }

    //@note: this comes into play when performing the cachegraph reconstruction phases.
    uint16 maxAttestationProcessingLimit = 32;

    //@note: this is the highest trust channel index (in this case a submap of such, each submap representing 256 trust channels) that
    // can be mapped, based on the lowest submap returned from the trust channel manager.
    uint16 maxNumberOfTrustChannelSubmapCompares = 8;

    uint32 constant NoTrustChannel = 2 ** 32 - 1;

    mapping(address => kycIdentity) identifiedAddress_to_kycIdentity;

    address internal trustAnchorStorageAddress = address(0);
    address internal trustChannelManagerAddress = address(0);

    address owner;

    //returns:
    // false = not owner
    // true = is owner

    //@note:@todo:@next:@audit: should this contract have "Administrable" style multisig involved for the setting
    // of the contract relationships?

    function isOwner() internal view returns (bool result) {
        if (msg.sender == owner) {
            //is owner
            return true;
        } else {
            //not owner
            return false;
        }
    }

    //returns:
    // 0 = not owner
    // 1 = set trustAnchorStorage

    function setTrustAnchorStorageAddress(address _trustAnchorStorageAddress) public returns (uint8 result) {
        if (isOwner()) {
            require(_trustAnchorStorageAddress != address(0));

            //@note:@todo:@next:@audit: what happens to the existing attestations when we change these relationships?
            // example: 1) should they all be revoked?
            //  or 2) should all of their consent be revoked?
            //  etc.
            trustAnchorStorageAddress = _trustAnchorStorageAddress;

            //set trustAnchorStorageAddress
            return 1;
        } else {
            //not owner
            return 0;
        }
    }

    //returns:
    // 0 = not owner
    // 1 = set trustChannelManagerAddress

    function setTrustChannelManagerAddress(address _trustChannelManagerAddress) public returns (uint8 result) {
        if (isOwner()) {
            require(_trustChannelManagerAddress != address(0));

            //@note:@todo:@next:@audit: what happens to the existing attestations when we change these relationships?
            // example: 1) should they all be revoked?
            //  or 2) should all of their consent be revoked?
            //  etc.
            trustChannelManagerAddress = _trustChannelManagerAddress;

            //set trustChannelManagerAddress
            return 1;
        } else {
            //not owner
            return 0;
        }
    }

    //@note:@safety: the worst that can happen is that a user clears their own
    // cache graph and it's marked dirty.

    //     function flashDeleteCacheGraph(address _identifiedAddress) internal {
    //         if (msg.sender == _identifiedAddress) {
    //             for (uint8 i = 0; i < identifiedAddress_to_kycIdentity[_identifiedAddress].cacheGraph.attestationKeccakArray.length; i++) {
    //                 delete identifiedAddress_to_kycIdentity[_identifiedAddress].cacheGraph.attestationJurisdictionMap[identifiedAddress_to_kycIdentity[_identifiedAddress].cacheGraph.attestationKeccakArray[i]];
    //                 delete identifiedAddress_to_kycIdentity[_identifiedAddress].cacheGraph.attestationStatusActiveMap[identifiedAddress_to_kycIdentity[_identifiedAddress].cacheGraph.attestationKeccakArray[i]];
    //                 delete identifiedAddress_to_kycIdentity[_identifiedAddress].cacheGraph.attestationStatusRevokedMap[identifiedAddress_to_kycIdentity[_identifiedAddress].cacheGraph.attestationKeccakArray[i]];
    //                 delete identifiedAddress_to_kycIdentity[_identifiedAddress].cacheGraph.attestationTrustAnchorAddressMap[identifiedAddress_to_kycIdentity[_identifiedAddress].cacheGraph.attestationKeccakArray[i]];
    //                 delete identifiedAddress_to_kycIdentity[_identifiedAddress].cacheGraph.attestationTrustAnchorKeccakMap[identifiedAddress_to_kycIdentity[_identifiedAddress].cacheGraph.attestationKeccakArray[i]];
    //             }

    //             delete identifiedAddress_to_kycIdentity[_identifiedAddress].cacheGraph.attestationKeccakArray;

    //             delete identifiedAddress_to_kycIdentity[_identifiedAddress].cacheGraph.hasJurisdictionBits;
    //             delete identifiedAddress_to_kycIdentity[_identifiedAddress].cacheGraph.activeBits;
    //             delete identifiedAddress_to_kycIdentity[_identifiedAddress].cacheGraph.pendingBits;
    //             delete identifiedAddress_to_kycIdentity[_identifiedAddress].cacheGraph.expiredBits;
    //             delete identifiedAddress_to_kycIdentity[_identifiedAddress].cacheGraph.revokedBits;
    //             delete identifiedAddress_to_kycIdentity[_identifiedAddress].cacheGraph.documentAvailabilityBits;

    //             delete identifiedAddress_to_kycIdentity[_identifiedAddress].cacheGraph.active_jurisdictionBits;
    //             delete identifiedAddress_to_kycIdentity[_identifiedAddress].cacheGraph.active_consented_jurisdictionBits;

    //             //@note:@todo:@here: iterate through jurisdictions and clear mapping?
    //             //delete identifiedAddress_to_kycIdentity[_identifiedAddress].cacheGraph.jurisdictionAttestationArray;

    //             //activeTrustChannelEXBitField

    //             delete identifiedAddress_to_kycIdentity[_identifiedAddress].cacheGraph.attestationValidityTrustAnchorSignatureAvailabilityBits;
    //             delete identifiedAddress_to_kycIdentity[_identifiedAddress].cacheGraph.attestationValidityUserSignatureAvailabilityBits;

    //             delete identifiedAddress_to_kycIdentity[_identifiedAddress].cacheGraph.materialChangeBitField;

    //             delete identifiedAddress_to_kycIdentity[_identifiedAddress].cacheGraph.allDocumentsBitwiseOrFilter;
    //             delete identifiedAddress_to_kycIdentity[_identifiedAddress].cacheGraph.activeDocumentsBitwiseOrFilter;

    //             delete identifiedAddress_to_kycIdentity[_identifiedAddress].cacheGraph.trustChannelMap;

    //             delete identifiedAddress_to_kycIdentity[_identifiedAddress].cacheGraph.constructedLocalKycLevel;

    //             identifiedAddress_to_kycIdentity[_identifiedAddress].cacheGraph.graphStatus = CacheGraphStatus.Dirty;
    //         }
    //     }

    //returns:
    // 0 = no updates needed
    // 1 = compilation needs to be complete
    // 2 = recompiled hash graph

    function reconstructCacheGraph(address _identifiedAddress) public returns (uint8 result) {
        ITrustAnchorStorage trustAnchorStorage = ITrustAnchorStorage(trustAnchorStorageAddress);

        // bytes32[] storage attestationKeccakArray = trustAnchorStorage.identifiedAddress_to_attestationKeccakArray(_identifiedAddress);
        // bytes32[] storage attestationKeccakArray = trustAnchorStorage.getAttestationKeccakArrayForIdentifiedAddress(_identifiedAddress);

        uint16 attestationKeccakArrayLength = trustAnchorStorage.getAttestationKeccakArrayLengthForIdentifiedAddress(_identifiedAddress);

        //@note: 256 bit bitfield max
        if (attestationKeccakArrayLength > 2<<8 - 1) {
            attestationKeccakArrayLength = 2<<8 - 1;
        }

        uint16 oldAttestationKeccakArrayLength = uint16(identifiedAddress_to_kycIdentity[_identifiedAddress].cacheGraph.attestationKeccakArray.length);


        //@note:@here:@todo: I'm pretty sure this should be set to a linked list to be able to look through dirty attestations.

        //check if it is required to append to the entire
        //@note: currently will not update (pending, active, expired, revoked) statuses.
        if (oldAttestationKeccakArrayLength != attestationKeccakArrayLength) {
            //@note: @here: @todo: do progressive testing to see how this functions.
            //changing this will make the hardcoded uintX values potentially incorrect.
            bool requiresFurtherReconstruction;

            //for the update here, since they are sequential attestations, the calculation is easy.
            uint16 updateLength = uint16(attestationKeccakArrayLength - oldAttestationKeccakArrayLength);

            if (updateLength >= maxAttestationProcessingLimit) {
                updateLength = maxAttestationProcessingLimit;
                requiresFurtherReconstruction = true;
            }

//            EVT_UpdatingCacheGraph(_identifiedAddress, updateLength, oldAttestationKeccakArrayLength, attestationKeccakArrayLength);

            //@note: @here: @todo: check if a limit is necessary here. max inclusions should be explicitly guarded against.
            for (uint16 i = 0; i < updateLength; i++) {
                uint16 idx = oldAttestationKeccakArrayLength + i;

//                EVT_DoCompileCacheGraph(_identifiedAddress, i, idx);
                compileCacheGraph(_identifiedAddress, idx);
            }

            if (requiresFurtherReconstruction == false) {
                //recompiled full hash graph
                return 2;
            } else {
                //compilation needs to be complete
                return 1;
            }
        } else {
            //no updates needed
            return 0;
        }
    }

    function compileCacheGraphTrustChannelEXBitFieldsAdditive(address _identifiedAddress, bytes32 _keccakHash, bool _consentAvailable) internal {
        ITrustAnchorStorage trustAnchorStorage = ITrustAnchorStorage(trustAnchorStorageAddress);
        ITrustChannelManager trustChannelManager = ITrustChannelManager(trustChannelManagerAddress);

        address trustAnchorAddress = trustAnchorStorage.getAttestationTrustAnchorAddress(_keccakHash);
        uint32 trustAnchorIndex = trustAnchorStorage.getAttestationTrustAnchorIndex(_keccakHash);

        uint24 lowestTrustChannelSubmapNumber = trustChannelManager.getTrustChannelLowestSubmapNumberForTrustAnchorIndex(trustAnchorIndex);
        uint24 highestTrustChannelSubmapNumber = trustChannelManager.getTrustChannelHighestSubmapNumberForTrustAnchorIndex(trustAnchorIndex);

        kycCacheGraph storage cacheGraph = identifiedAddress_to_kycIdentity[_identifiedAddress].cacheGraph;

//        EVT_GotLowestAndHighestTrustChannelSubmapNumber(lowestTrustChannelSubmapNumber, highestTrustChannelSubmapNumber);

        //@note:@todo:@next:@audit: this definitely needs to be bounds tested, as it corresponds to the numbers of loops below. upper end estimation
        //could have to do with gas spent so far (msg.gas), though this might be difficult to test/suggest to users.

        //cap number of compares of the trust channel submaps
        if (highestTrustChannelSubmapNumber - lowestTrustChannelSubmapNumber > maxNumberOfTrustChannelSubmapCompares) {
            highestTrustChannelSubmapNumber = lowestTrustChannelSubmapNumber + maxNumberOfTrustChannelSubmapCompares;
        }

        uint256 bitField;

        //@note:@todo:@gas: do estimations here.. uint24 (2**24) is way too many to iterate through.
        for (uint24 i = lowestTrustChannelSubmapNumber; i < highestTrustChannelSubmapNumber + 1; i++) {
            bitField = trustChannelManager.getTrustChannelIndexBitFieldAtSubmapNumberForTrustAnchorIndex(trustAnchorIndex, i);

//            EVT_GotBitFieldFromTrustAnchor(trustAnchorAddress, trustAnchorIndex, bitField);

            if (bitField != 0) {
                if (cacheGraph.trustAnchorTrustChannelIndexEXBitFieldLowestSubmapNumber[trustAnchorIndex] > i) {
                    cacheGraph.trustAnchorTrustChannelIndexEXBitFieldLowestSubmapNumber[trustAnchorIndex] = i;
                }

                if (cacheGraph.trustAnchorTrustChannelIndexEXBitFieldHighestSubmapNumber[trustAnchorIndex] > i) {
                    cacheGraph.trustAnchorTrustChannelIndexEXBitFieldHighestSubmapNumber[trustAnchorIndex] = i;
                }

                cacheGraph.trustAnchorTrustChannelIndexEXBitField[trustAnchorIndex][i] = bitField;

                cacheGraph.activeTrustChannelEXBitField[i] |= bitField;
                if (cacheGraph.activeTrustChannelLowestSubmapNumber > lowestTrustChannelSubmapNumber) {
                    cacheGraph.activeTrustChannelLowestSubmapNumber = lowestTrustChannelSubmapNumber;
                }
                if (cacheGraph.activeTrustChannelHighestSubmapNumber < highestTrustChannelSubmapNumber) {
                    cacheGraph.activeTrustChannelHighestSubmapNumber = highestTrustChannelSubmapNumber;
                }

                if (_consentAvailable) {
                    cacheGraph.activeConsentedTrustChannelEXBitField[i] |= bitField;

                    if (cacheGraph.activeConsentedTrustChannelLowestSubmapNumber > lowestTrustChannelSubmapNumber) {
                        cacheGraph.activeConsentedTrustChannelLowestSubmapNumber = lowestTrustChannelSubmapNumber;
                    }
                    if (cacheGraph.activeConsentedTrustChannelHighestSubmapNumber < highestTrustChannelSubmapNumber) {
                        cacheGraph.activeConsentedTrustChannelHighestSubmapNumber = highestTrustChannelSubmapNumber;
                    }
                }
            }
        }
    }

    //@note: the condition is that:
    // 1) the trust anchor by index is no longer associated to this account.
    // 2) there are no trust anchors that have attested to this account that share the trust channels associated to this trust anchor.

    function conditionallyRemoveCacheGraphTrustChannelTrustAnchorIndexEXBitField(address _identifiedAddress, uint32 _sourceTrustAnchorIndex) internal {
//        ITrustAnchorStorage trustAnchorStorage = ITrustAnchorStorage(trustAnchorStorageAddress);
//        ITrustChannelManager trustChannelManager = ITrustChannelManager(trustChannelManagerAddress);
        kycCacheGraph storage cacheGraph = identifiedAddress_to_kycIdentity[_identifiedAddress].cacheGraph;

        //check that the trust anchor by index is no longer associated to this account.
        if (cacheGraph.trustAnchorIndexToCountMap[_sourceTrustAnchorIndex] == 0) {

            //amalgamated map for use in comparisons
            uint256 baseTrustAnchorChannelMap;
            uint256 amalgamatedTrustAnchorChannelMap;
            uint256 comparisonTrustAnchorChannelMap;

            bool submapsExhausted;

            //get the lower bound of the trust channel map checks.
            uint24 submapNumber = cacheGraph.trustAnchorTrustChannelIndexEXBitFieldLowestSubmapNumber[_sourceTrustAnchorIndex];

            while (submapsExhausted == false) {

                //get the trust anchor's channel map.
                baseTrustAnchorChannelMap = cacheGraph.trustAnchorTrustChannelIndexEXBitField[_sourceTrustAnchorIndex][submapNumber];

                //@note:@todo:@here:@next: I wonder if this could be pulled out into a subfunction anyone could call.. the mapping is
                //most likely going to be done once per trust anchor in this user's cachegraph.. but it would have to be done for
                // all other trust anchors that are added to this channel.

                //create a composite trust anchor channel map of all the trust anchors except this one.
                if (baseTrustAnchorChannelMap == 0) {
                    //skip this comparison because this submap has no trust channels within it.
                } else {
                    uint32 curTrustAnchorIndex = cacheGraph.currentTrustAnchorLinkedList_zeldaIndex;

                    //create a composite trust anchor channel map of all the trust anchors except this one.
                    for (uint16 i = 0; i < cacheGraph.currentTrustAnchorsLinkedList_length; i++) {
                        if (curTrustAnchorIndex != _sourceTrustAnchorIndex) {
                            //update the amalgamated trust channel map
                            //@note:@here:@todo:@next: implement the following line?
//                            if (cacheGraph.trustAnchorTrustChannelIndexEXBitField[curTrustAnchorIndex][submapNumber] == 0) { //ignore this next part.
                            amalgamatedTrustAnchorChannelMap |= cacheGraph.trustAnchorTrustChannelIndexEXBitField[curTrustAnchorIndex][submapNumber];

                            //reassociate the linked list.
                            //@note:
                            // 1) the case of currentTrustAnchorLinkedList_zeldaIndex == _sourceTrustAnchorIndex && currentTrustAnchorsLinkedList_length == 1
                            //    will be taken care of because when currentTrustAnchorsLinkedList_length == 0, compileCacheGraph will set the currentTrustAnchorsLinkedList_length = 1
                            //    and set the currentTrustAnchorLinkedList_zeldaIndex to the trustAnchorIndex at that point.
                            // 2) the case of currentTrustAnchorLinkedList_finalIndex == _sourceTrustAnchorIndex, the length will simply be reduced by 1 and this is definitely
                            //    the last link in the linked list.
                            // 2) the case of currentTrustAnchorLinkedList_zeldaIndex != _sourceTrustAnchorIndex, the curTrustAnchorIndex != _sourceTrustAnchorIndex, so the
                            //    allTrustAnchorsThatHaveAttestedNextLinkMapping[curTrustAnchorIndex] is set to allTrustAnchorsThatHaveAttestedNextLinkMapping[_sourceTrustAnchorIndex],
                            //    which may or may not have been set up depending on whether currentTrustAnchorLinkedList_finalIndex == _sourceTrustAnchorIndex. if it has been set up,
                            //    the _sourceTrustAnchorIndex is in middle of the linked list somewhere, and thus the allTrustAnchorsThatHaveAttestedNextLinkMapping[curTrustAnchorIndex] should
                            //    now equal allTrustAnchorsThatHaveAttestedNextLinkMapping[_sourceTrustAnchorIndex]. otherwise, because the currentTrustAnchorsLinkedList_length is - 1 after
                            //    everything, currentTrustAnchorLinkedList_finalIndex is also set to curTrustAnchorIndex.

                            if (cacheGraph.allTrustAnchorsThatHaveAttestedNextLinkMapping[curTrustAnchorIndex] == _sourceTrustAnchorIndex) {
                                if (cacheGraph.currentTrustAnchorsLinkedList_length == i - 1) {
                                    cacheGraph.currentTrustAnchorLinkedList_finalIndex = curTrustAnchorIndex;
                                } else {
                                    cacheGraph.allTrustAnchorsThatHaveAttestedNextLinkMapping[curTrustAnchorIndex] = cacheGraph.allTrustAnchorsThatHaveAttestedNextLinkMapping[_sourceTrustAnchorIndex];
                                }

                                cacheGraph.allTrustAnchorsThatHaveAttestedNextLinkMapping[_sourceTrustAnchorIndex] = 2**32-1;
                            }

                            curTrustAnchorIndex = cacheGraph.allTrustAnchorsThatHaveAttestedNextLinkMapping[curTrustAnchorIndex];
                        } else {
                            //otherwise do nothing, as all the cases have been account for in the "if" corresponding to this "else".
                        }
                    }

                    //@note:@todo:@next:@audit: is the allTrustAnchorsThatHaveAttestedNextLinkMapping[_sourceTrustAnchorIndex] always removed? what happens in the case of only this address being the source address?
                    // I think this may be correct in the logic as the above "reassociate the linked list." covers this.
                    cacheGraph.currentTrustAnchorsLinkedList_length--;


                    //for example 1000100101 as the trust channels associated to the base trust anchor.
                    //            1101111011 as the amalgamated trust channels.
                    //            0000000100 is trust channel that must be removed.

                    //procedure:  1000100101
                    //bitwise AND 1101111011
                    //result is   1000100001, this is the trust channels that are the same, from the base trust channel
                    //                        and the amalgamated trust channels.
                    //
                    //then,       1000100101
                    //bitwise XOR 1000100001
                    //result is   0000000100, which is the trust channel that must be removed.

                    //to remove the bit from the user's trust channel mapping, we take the result, negate it
                    // (invert the bits) and then AND this with the trust channels from the user.

                    //procedure:     0000000100
                    //bitwise negate 1111111011
                    //
                    //then,          1111111011
                    //bitwise AND    _user's trust channel mapping_
                    //the result will  be now correctly formed.

                    //

                    //perform a bitwise AND on the amalgamated and base trust channel maps, and bitwise negate the result.
                    comparisonTrustAnchorChannelMap = ~(baseTrustAnchorChannelMap ^ (amalgamatedTrustAnchorChannelMap & baseTrustAnchorChannelMap));

                    //check if the comparison map is zero (no trust channels need to be removed)
                    if (comparisonTrustAnchorChannelMap == 0) {

                    } else {
                        cacheGraph.activeTrustChannelEXBitField[submapNumber] &= comparisonTrustAnchorChannelMap;
                        cacheGraph.activeConsentedTrustChannelEXBitField[submapNumber] &= comparisonTrustAnchorChannelMap;
                    }
                }

                submapNumber++;

                //see if the upper bound of the trust channel map check has been reached.
                if (submapNumber > cacheGraph.trustAnchorTrustChannelIndexEXBitFieldHighestSubmapNumber[_sourceTrustAnchorIndex]) {
                    submapsExhausted = true;
                } else {
                    continue;
                }
            }
        } else {
            //trust anchor still has a valid attestation to this account.
//            return 0;
        }
    }
//         //returns:
//         // 0 = signatures do not have a matching address
//         // 1 = signature does not have the attestor address
//         // 2 = addresses match
//
//         function checkConsentSignatures(address _identifiedAddress, uint _idx, bytes32 _keccakHash) internal view returns (uint8 result) {
//             ITrustAnchorStorage trustAnchorStorage = ITrustAnchorStorage(trustAnchorStorageAddress);
//
//             bytes32[2] memory attestationValidityTrustAnchorSignatureRS;
//             uint8 attestationValidityTrustAnchorSignatureV;
//             bytes32[2] memory attestationValidityUserSignatureRS;
//             uint8 attestationValidityUserSignatureV;
//
//             (attestationValidityTrustAnchorSignatureV,
//              attestationValidityTrustAnchorSignatureRS,
//              attestationValidityUserSignatureV,
//              attestationValidityUserSignatureRS) = trustAnchorStorage.getAttestationValiditySignaturesInKeccakArray(_identifiedAddress, uint8(_idx));
//
//             address recoveredAddressTrustAnchor = ecrecover(_keccakHash, attestationValidityTrustAnchorSignatureV, attestationValidityTrustAnchorSignatureRS[0], attestationValidityTrustAnchorSignatureRS[1]);
//             address recoveredAddressUserSignature = ecrecover(_keccakHash, attestationValidityUserSignatureV, attestationValidityUserSignatureRS[0], attestationValidityUserSignatureRS[1]);
//
//             if (recoveredAddressTrustAnchor == recoveredAddressUserSignature) {
//                 if (recoveredAddressTrustAnchor == trustAnchorStorage.getTrustAnchorAddressInKeccakArray(_identifiedAddress, uint8(_idx))) {
//                     //addresses match
//                     return 2;
//                 } else {
//                     //signature does not have the attestor address
//                     return 1;
//                 }
//             } else {
//                 //signatures do not have a matching address
//                 return 0;
//             }
//         }

//    //returns:
//    // 0 = no complete consent available
//    // 1 = consent available
//
//    function compileCacheGraphConsent(address _identifiedAddress, uint _idx, bytes32 _keccakHash, uint16 _jurisdiction) internal returns (bool result) {
//        ITrustAnchorStorage trustAnchorStorage = ITrustAnchorStorage(trustAnchorStorageAddress);
//
//        kycCacheGraph storage cacheGraph = identifiedAddress_to_kycIdentity[_identifiedAddress].cacheGraph;
//
//        //if (checkConsentSignatures(_identifiedAddress, _idx, _keccakHash))
//        //check for 2 signatures (trust anchor and user) for attestation
//        if (trustAnchorStorage.getConsentAvailableInKeccakArray(_identifiedAddress, uint8(_idx)) == 2) {
//            cacheGraph.active_consented_jurisdictionBits |= uint256(_jurisdiction);
//            cacheGraph.activeConsentedJurisdictionAttestationArray[_jurisdiction].push(_keccakHash);
//
//            //consent available
//            return true;
//        }
//
//        //no complete consent available
//        return true;
//    }

//    //returns:
//    // isActive = effectiveTime <= now <= expiryTime;
//
//    function compileCacheGraphTime(address _identifiedAddress, uint256 _effectiveTime, uint256 _expiryTime, uint _idx) internal returns (bool result) {
//        bool isActive;
//
//        kycCacheGraph storage cacheGraph = identifiedAddress_to_kycIdentity[_identifiedAddress].cacheGraph;
//
//        //@note: safeMath not required. (thurs feb 22 2018) = 01011010011100100101100010000000 in binary, which is still
//        // which is 32 bits. #functionmaynotworkattheendoftimesoonlyuseitbeforethen.
//        uint256 blockTime = block.timestamp * 1000;
//
//        if (_effectiveTime > blockTime) {
//            cacheGraph.pendingBits |= uint256(_idx);
//        } else if (_effectiveTime <= blockTime && (_expiryTime == 0 || _expiryTime > blockTime)) {
//            isActive = true;
//            cacheGraph.activeBits |= uint256(_idx);
//        } else {
//            cacheGraph.expiredBits |= uint256(_idx);
//        }
//
//        EVT_CompareTime(_effectiveTime, blockTime, _expiryTime, isActive);
//
//        return isActive;
//    }

    //@note: this can be done for each index, and should help to compile lists.

    function compileCacheGraph(address _identifiedAddress, uint16 _idx) public {
        ITrustAnchorStorage trustAnchorStorage = ITrustAnchorStorage(trustAnchorStorageAddress);

        bytes32 keccakHash;
        uint32 trustAnchorIndex;
        uint16 jurisdiction;
        bool attestationStatusApproved;

        (keccakHash,
         trustAnchorIndex,
         jurisdiction,
         attestationStatusApproved) = trustAnchorStorage.getGraphConstructableAttestationInKeccakArray(_identifiedAddress, uint8(_idx));

        kycCacheGraph storage cacheGraph = identifiedAddress_to_kycIdentity[_identifiedAddress].cacheGraph;

        if (cacheGraph.exists == false) {
            cacheGraph.exists = true;

            cacheGraph.activeTrustChannelLowestSubmapNumber = 2**24-1;
            cacheGraph.activeTrustChannelHighestSubmapNumber;

            cacheGraph.activeConsentedTrustChannelLowestSubmapNumber = 2**24-1;
            cacheGraph.activeConsentedTrustChannelHighestSubmapNumber;
        }

        bool didChangeApprovedStatus;

        //check whether this attestation has already been processed.
        if (cacheGraph.attestationHasAlreadyBeenProcessed[_idx] == true) {
            //@note: if the attestation has already been processed and its status has changed, modify the counter.
            // otherwise, don't modify the counter.
            if (cacheGraph.attestationPreviousApprovedStatus[_idx] == false && attestationStatusApproved == true) {
                cacheGraph.trustAnchorIndexToCountMap[trustAnchorIndex]++;
                didChangeApprovedStatus = true;
            } else if (cacheGraph.attestationPreviousApprovedStatus[_idx] == true && attestationStatusApproved == false) {
                cacheGraph.trustAnchorIndexToCountMap[trustAnchorIndex]--;
                didChangeApprovedStatus = true;
            }
        } else {
            //if this is the first time this trustAnchorIndex has been included in this cache graph, set its lowest trust channel
            // submap index to 2**24-1.
            if (cacheGraph.trustAnchorIndexToCountMap[trustAnchorIndex] == 0) {
                cacheGraph.trustAnchorTrustChannelIndexEXBitFieldLowestSubmapNumber[trustAnchorIndex] = 2**24 -1;
            }

            cacheGraph.trustAnchorIndexToCountMap[trustAnchorIndex]++;

            //check whether this trust anchor has attested before.
            if (cacheGraph.allTrustAnchorIndexExistsMapping[trustAnchorIndex] == true) {
//                //get the current (soon to be previous) length of all the trust anchor that have ever attested to this contract.
//                uint16 previousAllTrustAnchorNextLinkArrayLength = uint16(cacheGraph.allTrustAnchorsThatHaveAttestedNextLinkArray.length);
//
//                //increase that length because we're going to modify it next.
//                cacheGraph.allTrustAnchorsThatHaveAttestedNextLinkArray.length++;
//
//                //set the next array index in the array to have the trust anchor's index.
//                cacheGraph.allTrustAnchorsThatHaveAttestedNextLinkArray[previousAllTrustAnchorNextLinkArrayLength] = trustAnchorIndex;
            } else {
                cacheGraph.allTrustAnchorIndexExistsMapping[trustAnchorIndex] = true;
            }

            //if there are currently no members in the linked list, set this as the zelda index. there's no need to setup
            //the allTrustAnchorsThatHaveAttestedNextLinkMapping array since this is the only item in the linked list.
            if (cacheGraph.currentTrustAnchorsLinkedList_length == 0) {
                cacheGraph.currentTrustAnchorLinkedList_zeldaIndex = trustAnchorIndex;

                cacheGraph.currentTrustAnchorsLinkedList_length = 1;
            } else {
                //otherwise, set the previous final trust anchor in the linked list to have the next link as this trust anchor's index.
                cacheGraph.allTrustAnchorsThatHaveAttestedNextLinkMapping[cacheGraph.currentTrustAnchorLinkedList_finalIndex] = trustAnchorIndex;
            }

            //increase the length of the list.
            cacheGraph.currentTrustAnchorsLinkedList_length++;

            //update the final index in the linked list.
            cacheGraph.currentTrustAnchorLinkedList_finalIndex = trustAnchorIndex;

            didChangeApprovedStatus = true;
        }

//        EVT_GotAttestationStatus(_identifiedAddress, attestationStatusApproved, didChangeApprovedStatus, _idx, cacheGraph.attestationHasAlreadyBeenProcessed[_idx]);

        if (didChangeApprovedStatus == true) {
            if (attestationStatusApproved) {
                //@note: might be too expensive
                // checkConsentSignatures(_identifiedAddress, _idx, keccakHash);
//                bool consentAvailable = compileCacheGraphConsent(_identifiedAddress, _idx, keccakHash, jurisdiction);

                //@note: full consent is from user + trust anchor.
                bool consentAvailable = (trustAnchorStorage.getConsentAvailableInKeccakArray(_identifiedAddress, uint8(_idx)) == 2);

//                EVT_DoCompileCacheGraphTrustChannelEXBitFields(_identifiedAddress, keccakHash, consentAvailable);

                //check if this attestation index has already been processed.
                if (cacheGraph.attestationHasAlreadyBeenProcessed[_idx] == false) {
                    //set the attestationHasAlreadyBeenProcessed for this attestation index to true.
                    cacheGraph.attestationHasAlreadyBeenProcessed[_idx] = true;

                    //@note: this is additive-only.
                    compileCacheGraphTrustChannelEXBitFieldsAdditive(_identifiedAddress, keccakHash, consentAvailable);
                }
            } else {
                //@note: the removal of trust anchor's attestation may have changed the trust channels associated to
                // this account. in this case, the trust channel itself may need to be removed from the previously
                // compiled EX bits.
                if (cacheGraph.attestationHasAlreadyBeenProcessed[_idx] == true) {
//                    EVT_DoConditionallyRemoveTrustChannelEXBitFields(_identifiedAddress, trustAnchorIndex, keccakHash);

                    conditionallyRemoveCacheGraphTrustChannelTrustAnchorIndexEXBitField(_identifiedAddress, trustAnchorIndex);
                } else {
                    //if it's false, there's nothing that needs to be done, since it wouldn't be in the compiled EX bits.
                }
            }
        }

        cacheGraph.attestationPreviousApprovedStatus[_idx] = attestationStatusApproved;
    }


    //@note:@here:@todo:@next@funtest1: this doesn't return the trust channel index.. not exactly. it returns...

    //@note: any function calling this should be aware that it will return 0 in the case where there are no set bits.
    //returns:
    // 0->255 = trust channel sub index.

    function getTrustChannelSubIndexFromBitField(uint256 trustChannelBitField) public returns (uint8 result) {
        //@reference:@checkwhenupdating: from TrustChannelManager.sol's bit field creation process
        //
        // uint16 trustChannelIndex = trustChannelKeccakToTrustChannelIndex[trustChannelKeccak];
        //
        // //separate out the trust channel index number with the sub-mapping. this keeps alignment to 256 bits.
        // uint8 submapNumber = uint8(trustChannelIndex >> 8);
        // uint8 subIndex = uint8(trustChannelIndex % 256);
        //
        // bytes32 composedBitField = trustAnchorAddressToTrustChannelIndexBitField[_trustAnchorAddress][submapNumber];
        //
        //@reference: this is the general pattern.
        // using least significant bit, the subindex
        // 0100       0000        0000        0000       0000       0000       0000       0100
        // 1's subIndex = 30                                                              1's subIndex = 3
        //
        //@reference: like so
        // uint32 active32BitWord3 = uint32((activeJurisdictionBitField & (uint256(32 ** 2 - 1) << 128)) >> 128);
        // uint32 active32BitWord4 = uint32((activeJurisdictionBitField & (uint256(32 ** 2 - 1) << 96)) >> 96);
        // uint32 active32BitWord5 = uint32((activeJurisdictionBitField & (uint256(32 ** 2 - 1) << 64)) >> 64);
        // uint32 active32BitWord6 = uint32((activeJurisdictionBitField & (uint256(32 ** 2 - 1) << 32)) >> 32);

        uint256 bitMask = uint256(2 ** 32 - 1);
        uint8 trustChannelSubIndex;

        //@note: updating the first 32 bits immediately.. consider it as a L1 cache for the trust anchors, which assumes
        // clustering around the primary initial trust channels.
        uint32 trustChannelBitFieldWords_7 = uint32(trustChannelBitField & bitMask);

        emit EVT_TrustChannelBitFieldWords(trustChannelBitFieldWords_7);
        if (trustChannelBitFieldWords_7 != 0) {
            trustChannelSubIndex = uint8(rightmost_index(trustChannelBitFieldWords_7));

            emit EVT_TrustChannelBitFieldIndex(trustChannelSubIndex);
        } else {
            //compare the rest as required
            uint32 trustChannelBitFieldWord;
            uint8 shifter;

            for (uint8 i = 6; i >= 0; i--) {
                //@reference: when i = 0 (the first 32 bit word) the bitmask must be shifted by 224, AND'd with the trust channel bit field,
                // and then shifted back to be referenced as a 32 bit index.
                // Max value is 224 = 32 * (7-0)

                shifter = (32 * (7 - i));

                trustChannelBitFieldWord = uint32((trustChannelBitField & (bitMask << shifter)) >> shifter);

                if (trustChannelBitFieldWord != 0) {
                    trustChannelSubIndex = uint8(rightmost_index(trustChannelBitFieldWord) + shifter);

                    emit EVT_TrustChannelBitFieldIndexEXT(i, shifter, trustChannelBitFieldWord, trustChannelBitField, trustChannelSubIndex);

                    break;
                }
            }
        }

        return trustChannelSubIndex;
    }

    //@note: the following two functions (getActiveConsentedTrustChannelBitFieldForPair & getActiveTrustChannelBitFieldForPair) are very
    // similarly structured, but as these functions will be called often, they are split out into two separate function calls to avoid
    // "stack too deep" issues.

    //@note:@here:@todo:@next@funtest1: this doesn't return the trust channel index.. not exactly. it returns...
    // @funtest1: fix this function to return the proper trust channel index!

    //returns:
    // NoTrustChannel = no trust channel found
    // 0->2**32 - 2 = trust channel found at index

    function getActiveConsentedTrustChannelBitFieldForPair(address _senderIdentifiedAddress, address _receiverIdentifiedAddress) internal returns (uint32 result) {
        kycCacheGraph storage senderCacheGraph = identifiedAddress_to_kycIdentity[_senderIdentifiedAddress].cacheGraph;
        kycCacheGraph storage receiverCacheGraph = identifiedAddress_to_kycIdentity[_receiverIdentifiedAddress].cacheGraph;

        uint24 senderLowestSubmapIndex = senderCacheGraph.activeConsentedTrustChannelLowestSubmapNumber;
        uint24 senderHighestSubmapIndex = senderCacheGraph.activeConsentedTrustChannelHighestSubmapNumber;

        uint24 receiverLowestSubmapIndex = receiverCacheGraph.activeConsentedTrustChannelLowestSubmapNumber;
        uint24 receiverHighestSubmapIndex = receiverCacheGraph.activeConsentedTrustChannelHighestSubmapNumber;

        uint256 trustChannelBitField;

        uint32 trustChannelIndex;

        //check for first index accessible to both parties.
        //this is the most efficient form of trust channel matching.
        if (senderHighestSubmapIndex == 0 || receiverHighestSubmapIndex == 0) {
            //it is, so no need to loop,
            trustChannelBitField = uint256(senderCacheGraph.activeConsentedTrustChannelEXBitField[0]);
            trustChannelBitField &= uint256(receiverCacheGraph.activeConsentedTrustChannelEXBitField[0]);

            if (trustChannelBitField != 0) {
                trustChannelIndex = getTrustChannelSubIndexFromBitField(trustChannelBitField);

                emit EVT_TrustChannelRouted(trustChannelIndex, _senderIdentifiedAddress, _receiverIdentifiedAddress);

                //trust channel found at index
                return trustChannelIndex;
            } else {
                //no trust channel found
                return NoTrustChannel;
            }
        } else {
            //get the lowest and highest index that both sender/receiver are party to.
            uint24 lowestSearchableSubmapIndex = senderLowestSubmapIndex;
            uint24 highestSearchableSubmapIndex = senderHighestSubmapIndex;

            if (receiverLowestSubmapIndex < lowestSearchableSubmapIndex) {
                lowestSearchableSubmapIndex = receiverLowestSubmapIndex;
            }
            if (receiverHighestSubmapIndex > highestSearchableSubmapIndex) {
                highestSearchableSubmapIndex = receiverHighestSubmapIndex;
            }

            emit EVT_GotLowestAndHighestTrustChannelSubmapNumber(lowestSearchableSubmapIndex, highestSearchableSubmapIndex);

            //search by pages
            //@note:@here:@audit: if this overflows (the "highestSearchableSubmapIndex + 1") there could be an issue.
            // however, at that point the submap is at 2**24-1, which means the entire trust channel mapping is completely
            // filled. that's an enormous amount of gas to set up, and would either mean the network is completely
            // massively operational, or there's been a serious breach of an administrator for the trust channel
            // manager contract. this contract's owner can explicitly change this trust channel manager relationship.

            for (uint24 i = lowestSearchableSubmapIndex; i < highestSearchableSubmapIndex + 1; i++) {
                trustChannelBitField = uint256(senderCacheGraph.activeConsentedTrustChannelEXBitField[i]);
                trustChannelBitField &= uint256(receiverCacheGraph.activeConsentedTrustChannelEXBitField[i]);

                if (trustChannelBitField != 0) {
                    trustChannelIndex = getTrustChannelSubIndexFromBitField(trustChannelBitField) + (i * 256);

                    emit EVT_TrustChannelRouted(trustChannelIndex, _senderIdentifiedAddress, _receiverIdentifiedAddress);

                    //trust channel found at index
                    return trustChannelIndex;
                }
            }

            //no trust channel found
            return NoTrustChannel;
        }
    }

    //@note:@here:@todo:@next@funtest1: this doesn't return the trust channel index.. not exactly. it returns...
    // @funtest1: fix this function to return the proper trust channel index!

    //returns:
    // NoTrustChannel = no trust channel found
    // 0->2**32 - 2 = trust channel found at index

    function getActiveTrustChannelBitFieldForPair(address _senderIdentifiedAddress, address _receiverIdentifiedAddress) public returns (uint32 result) {
        kycCacheGraph storage senderCacheGraph = identifiedAddress_to_kycIdentity[_senderIdentifiedAddress].cacheGraph;
        kycCacheGraph storage receiverCacheGraph = identifiedAddress_to_kycIdentity[_receiverIdentifiedAddress].cacheGraph;

        uint24 senderLowestSubmapIndex = senderCacheGraph.activeTrustChannelLowestSubmapNumber;
        uint24 senderHighestSubmapIndex = senderCacheGraph.activeTrustChannelHighestSubmapNumber;

        uint24 receiverLowestSubmapIndex = receiverCacheGraph.activeTrustChannelLowestSubmapNumber;
        uint24 receiverHighestSubmapIndex = receiverCacheGraph.activeTrustChannelHighestSubmapNumber;

        emit EVT_GotHighestSubmapNumbers(senderHighestSubmapIndex, receiverHighestSubmapIndex);

        uint256 trustChannelBitField;

        uint32 trustChannelIndex;

        //check for first index accessible to both parties.
        //this is the most efficient form of trust channel matching.
        if (senderHighestSubmapIndex == 0 || receiverHighestSubmapIndex == 0) {
            //it is, so no need to loop.
            trustChannelBitField = senderCacheGraph.activeTrustChannelEXBitField[0];
            trustChannelBitField &= receiverCacheGraph.activeTrustChannelEXBitField[0];

            emit EVT_GetActiveTrustChannelEXBitFieldLength(
                senderCacheGraph.activeTrustChannelLowestSubmapNumber,
                senderCacheGraph.activeTrustChannelHighestSubmapNumber,
                receiverCacheGraph.activeTrustChannelLowestSubmapNumber,
                receiverCacheGraph.activeTrustChannelHighestSubmapNumber,
                senderCacheGraph.activeTrustChannelEXBitField[0],
                receiverCacheGraph.activeTrustChannelEXBitField[0],
                trustChannelBitField);

            if (trustChannelBitField != 0) {
                trustChannelIndex = getTrustChannelSubIndexFromBitField(trustChannelBitField);

                emit EVT_TrustChannelRouted(trustChannelIndex, _senderIdentifiedAddress, _receiverIdentifiedAddress);

                //trust channel found at index
                return trustChannelIndex;
            } else {
                //no trust channel found
                return NoTrustChannel;
            }
        } else {
            //get the lowest and highest index that both sender/receiver are party to.
            uint24 lowestSearchableSubmapIndex = senderLowestSubmapIndex;
            uint24 highestSearchableSubmapIndex = senderHighestSubmapIndex;

            if (receiverLowestSubmapIndex < lowestSearchableSubmapIndex) {
                lowestSearchableSubmapIndex = receiverLowestSubmapIndex;
            }
            if (receiverHighestSubmapIndex > highestSearchableSubmapIndex) {
                highestSearchableSubmapIndex = receiverHighestSubmapIndex;
            }

            emit EVT_GotLowestAndHighestTrustChannelSubmapNumber(lowestSearchableSubmapIndex, highestSearchableSubmapIndex);

            //search by pages
            //@note:@here:@audit: if this overflows (the "highestSearchableSubmapIndex + 1") there could be an issue.
            // however, at that point the submap is at 2**24-1, which means the entire trust channel mapping is completely
            // filled. that's an enormous amount of gas to set up, and would either mean the network is completely
            // massively operational, or there's been a serious breach of an administrator for the trust channel
            // manager contract. this contract's owner can explicitly change this trust channel manager relationship.

            for (uint24 i = lowestSearchableSubmapIndex; i < highestSearchableSubmapIndex + 1; i++) {
                trustChannelBitField = senderCacheGraph.activeTrustChannelEXBitField[i];
                trustChannelBitField &= receiverCacheGraph.activeTrustChannelEXBitField[i];

                emit EVT_GetActiveTrustChannelEXBitFieldLength(
                    senderCacheGraph.activeTrustChannelLowestSubmapNumber,
                    senderCacheGraph.activeTrustChannelHighestSubmapNumber,
                    receiverCacheGraph.activeTrustChannelLowestSubmapNumber,
                    receiverCacheGraph.activeTrustChannelHighestSubmapNumber,
                    senderCacheGraph.activeTrustChannelEXBitField[i],
                    receiverCacheGraph.activeTrustChannelEXBitField[i],
                    trustChannelBitField);

                if (trustChannelBitField != 0) {
                    trustChannelIndex = getTrustChannelSubIndexFromBitField(trustChannelBitField) + (i * 256);

                    emit EVT_TrustChannelRouted(trustChannelIndex, _senderIdentifiedAddress, _receiverIdentifiedAddress);

                    //trust channel found at index
                    return trustChannelIndex;
                }
            }

            //no trust channel found
            return NoTrustChannel;
        }
    }

//    //@note: because this function is set to public and having people's attestations marked to dirty on a whim is
//    // bad news, we require this attestation's revocation call come from the Trust Anchor Storage itself.
//
//    //returns:
//    // 0 = message does not originate trust anchor storage
//    // 1 = attestation marked dirty
//
//    function markAttestationAsDirty(address _identifiedAddress, uint8 _idx) public returns (uint8 result) {
//        if (msg.sender == trustAnchorStorageAddress) {
//            kycCacheGraph storage cacheGraph = identifiedAddress_to_kycIdentity[_identifiedAddress].cacheGraph;
//
//            cacheGraph.graphStatus = CacheGraphStatus.Dirty;
//
////            trustAnchorStorage.getGraphConstructableAttestationInKeccakArray(_identifiedAddress, uint8(_idx));
//
//            //attestation marked dirty
//            return 1;
//        } else {
//            //message does not originate trust anchor storage
//            return 0;
//        }
//    }
}
