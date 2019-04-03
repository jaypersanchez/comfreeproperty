pragma solidity ^0.4.19;

import "./Interfaces/ITrustAnchorManager.sol";

import "./Administrable.sol";

// The Trust Channel Manager is an interface for Trust Anchors to collaborate and share directed
// financial communications channels in as closee to a friction free way as possible.
//
// Trust Anchors sign up to collaborate on the Trust Channel, assigning rules that must be in place
// to allow for the interface to function. Verifiability of documentation is a key differentiating
// factor from other identity solutions.
//
// Technically, the Trust Channel contract acts as a service-interface aggregator, relying heavily
// on bit-field manipulation to associate the DCG (directed cyclic graph) relations of the
// participating trust anchor efficiently.
//
// This creates bounds on logic, as lookup tables increase linearly. Bloom filters could theoretically
// be utilized to allow a probablistic pathing that might need to have heavier lookups in the future.
//
// Within this flow, the Trust Channels are initially set up by the administrators of this smart contract
// and within each Trust Channel is the ability to add "Trust Channel Administrators", who can manage the membership
// of each Trust Channel.


//@note:@todo:@next: examine the use of a de-facto "global id type" section, with Shyft running the
// attestor component via reading certificate-equivalents from signed messages having a valid
// certificate from some third-party entity.
//
// second forms of identity may be used and collected like PGP methods.

contract TrustChannelManager is Administrable {
    // ** trust channel management ** //

    event EVT_IsTrustChannelAdministrator(address _trustChannelAdministratorAddress,
        address _trustChannelAddress,
        bool isTrustChannelAdministrator);

    event EVT_ReceivedJurisdictionFromTrustAnchor( uint16 jurisdiction,
        address trustAnchorAddress,
        address trustChannelAddress );

    event EVT_ComposedTrustChannelWithTrustAnchor( uint256 composedBitField,
        uint32 trustAnchorIndex,
        uint32 trustChannelIndex,
        address _trustAnchorAddress,
        address _trustChannelAddress );

    event EVT_AddedTrustAnchorToTrustChannel( uint256 ruleStorageIndex,
        uint24 trustChannelLowestSubmapNumber,
        uint24 trustChannelHighestSubmapNumber,
        address _trustAnchorAddress,
        address _trustChannelAddress );

    event EVT_Route(address _senderIdentifiedAddress,
        address _receiverIdentifiedAddress,
        uint256 _amount,
        uint32 _trustChannelIndex);

    enum TrustChannelRules { VerificationPolicyEnforced,
        AllowTransitAcrossOtherChannels,
        AllowTransitAcrossJurisdictions,
        rules_MinimumSyntheticKycLevelRequired,
        NumberOfRules}

    uint8 rules_VerificationPolicyEnforced = 0;
    uint8 rules_AllowTransitAcrossOtherChannels = 1;
    uint8 rules_AllowTransitAcrossJurisdictions = 2;
    uint8 rules_MinimumSyntheticKycLevelRequired = 3;

    //"rulesStorage" keys below substructured such that there are:
    // for every rule type (index R):
    //
    // 0 -> generalized storage
    // R * 2**8 + N = Rule storage N, where N < 256.
    //
    // [0]: must have verification policy
    // [1]: allow transit across other channels
    //  .   [1 * 2**8 + 0] [#256-bit bit field#]: trust channel map A
    //  .   [1 * 2**8 + 1] [#256-bit bit field#]: trust channel map B
    //  .   [1 * 2**8 + 2] [#256-bit bit field#]: trust channel map C
    //  .   [1 * 2**8 + 3] [#256-bit bit field#]: trust channel map D
    //      ...    note: > 2048 possible trust channels, it is not limited in this contract.
    // [2]: allow transit across jurisdiction
    //  .   [2 * 2**8 + 0] [#256-bit bitfield] for jurisdictions allowed under this bit field (0 -> 255)
    //  .   [2 * 2**8 + 1] [#256-bit bitfield] for jurisdictions allowed under this bit field (255 -> 511)
    //  .   [2 * 2**8 + 2] [#256-bit bitfield] for jurisdictions allowed under this bit field (511 -> 767)
    //  .   [2 * 2**8 + 3] [#256-bit bitfield] for jurisdictions allowed under this bit field (767 -> 1023)
    //      ...    note: > 2048 possible jurisdictions, it is not limited in this contract.
    // [3]: minimum synthetic kyc level required
    //  .   [3 * 2**8 + 0] [#16-bit signed integer] kyc level required minimum across all jurisdictions

    //@note: bloom filters aren't considered for the moment while the bit field allows direct comparison.
    //  .   [0] [#256-bit bloom filter#] bloom filter for jurisdiction phase A << within rulesStorage keccack256(trustChannelKeccak, TrustChannelRules.AllowTransitAcrossJurisdiction, "A")
    //          1 in 256**2 chance of collision
    //  .   [1] [#256-bit bloom filter#] bloom filter for jurisdiction phase B << within rulesStorage keccack256(trustChannelKeccak, TrustChannelRules.AllowTransitAcrossJurisdiction, "B")
    //          1 in 256**3 chance of collision
    //  .   [2] [#256-bit bloom filter#] bloom filter for jurisdiction phase C << within rulesStorage keccack256(trustChannelKeccak, TrustChannelRules.AllowTransitAcrossJurisdiction, "C")
    //          1 in 256**4 chance of collision
    //  .   [3] [#256-bit bloom filter#] bloom filter for jurisdiction phase D << within rulesStorage keccack256(trustChannelKeccak, TrustChannelRules.AllowTransitAcrossJurisdiction, "D")

    //minimumSyntheticKyLevelRequired
    struct trustChannelRules {
        bool isActive;
        bytes32 trustChannelKeccak;
        mapping(uint16 => bytes32) rulesStorage;
        bool[8] rulesActive;
    }

    struct trustChannelMap {
        bool isActive;
        mapping(address => bool) trustAnchorAddressExists;
//        uint256[] trustAnchorIndexMapEXBitField;
        uint8 numMembers;

        trustChannelRules channelRules;
    }

    mapping(address => bytes32) trustChannelAddressToTrustChannelKeccak;
    mapping(bytes32 => trustChannelMap) trustChannelKeccakToTrustChannelMap;
    uint32 numTrustChannels;

    //data model for the administrators of each trust channel.
    mapping(address => mapping(address => bool)) trustChannelAdministratorExistsMapping;
    mapping(address => mapping(address => uint64)) trustChannelAdministratorsIndexMapping;
    mapping(address => address[]) trustChannelAdministratorsArray;

    //@note: this mapping is a bit different than the others.. it is a
    //trust anchor address to bitfield*s* that make up a practically unlimited
    //data addressing space. ex:
    //
    //trustAnchorIndexToTrustChannelIndexBitField[0] = 256-bit bit field
    //representing the first 256 trust channels.

    mapping(uint32 => mapping(uint24 => uint256)) trustAnchorIndexToTrustChannelIndexBitField;

    mapping(uint32 => bool) trustAnchorIndexAssociatedToAnyTrustChannels;
    mapping(uint32 => uint24) trustAnchorIndexToTrustChannelLowestSubmapNumber;
    mapping(uint32 => uint24) trustAnchorIndexToTrustChannelHighestSubmapNumber;

    mapping(uint32 => bytes32) trustChannelIndexToTrustChannelKeccak;
    mapping(bytes32 => uint32) trustChannelKeccakToTrustChannelIndex;

    uint16 constant NoJurisdiction = 2 ** 16 - 1;

    address trustAnchorManagerAddress;
    address trustAnchorStorageAddress;

    constructor() public {
        owner = msg.sender;
    }


    //@note:@here:@todo:@next: setup the following two functions to be multisig through Administrable, and write tests
    // to match.

    //returns:
    // 0 = not owner
    // 1 = set trust anchor storage address

    function setTrustAnchorManagerAddress(address _trustAnchorManagerAddress) public returns (uint8 result) {
        if (isAdministrator(msg.sender)) {
            //@note:@here:@todo: stabilize on whether 1 or 2 admins are required to set up, figure out
            //what to do if the storage address is replaced (this would be a "big deal" re: the user's kyc cache graphs)

            require(_trustAnchorManagerAddress != address(0));

            trustAnchorManagerAddress = _trustAnchorManagerAddress;

            //set trust anchor storage address
            return 1;
        } else {
            //not owner
            return 0;
        }
    }

    //returns:
    // 0 = not owner
    // 1 = set trust anchor storage address

    function setTrustAnchorStorageAddress(address _trustAnchorStorageAddress) public returns (uint8 result) {
        if (isAdministrator(msg.sender)) {
            //@note:@here:@todo: stabilize on whether 1 or 2 admins are required to set up, figure out
            //what to do if the storage address is replaced (this would be a "big deal" re: the user's kyc cache graphs)

            require(_trustAnchorStorageAddress != address(0));

            trustAnchorStorageAddress = _trustAnchorStorageAddress;

            //set trust anchor storage address
            return 1;
        } else {
            //not owner
            return 0;
        }
    }

    //returns:
    // 0 = not administrator
    // 1 = trust channel already exists
    // 2 = added trust channel

    function adminSetupTrustChannel(address _trustChannelAddress) public returns (uint8 result) {
        if (isAdministrator(msg.sender)) {

            //@note: @here: @future this should be modified so that an address can own multiple trust channels.
            bytes32 trustChannelKeccak = keccak256(abi.encodePacked(_trustChannelAddress));
            trustChannelMap storage channelMap = trustChannelKeccakToTrustChannelMap[trustChannelKeccak];


            if (channelMap.isActive == false) {
                channelMap.isActive = true;
                channelMap.channelRules.isActive = true;
                channelMap.channelRules.trustChannelKeccak = trustChannelKeccak;
                channelMap.channelRules.rulesActive[uint8(TrustChannelRules.VerificationPolicyEnforced)] = true;
                channelMap.channelRules.rulesActive[uint8(TrustChannelRules.AllowTransitAcrossOtherChannels)] = false;
                //keccack256(trustChannelKeccak, TrustChannelRules.AllowTransitAcrossOtherChannels, "A")
                channelMap.channelRules.rulesActive[uint8(TrustChannelRules.AllowTransitAcrossJurisdictions)] = false;
                //keccack256(trustChannelKeccak, TrustChannelRules.AllowTransitAcrossJurisdiction, "A")

                trustChannelAddressToTrustChannelKeccak[_trustChannelAddress] = trustChannelKeccak;

                trustChannelKeccakToTrustChannelIndex[trustChannelKeccak] = numTrustChannels;
                trustChannelIndexToTrustChannelKeccak[numTrustChannels] = trustChannelKeccak;

                //setup the base administrator for this trust channel.
                trustChannelAdministratorExistsMapping[_trustChannelAddress][msg.sender] = true;
                trustChannelAdministratorsIndexMapping[_trustChannelAddress][msg.sender] = 0;
                trustChannelAdministratorsArray[_trustChannelAddress].push(msg.sender);

                numTrustChannels++;

                //added trust channel
                return 2;
            } else {
                //trust channel already exists
                return 1;
            }
        } else {
            //not administrator
            return 0;
        }
    }

    //returns:
    //false = not trust channel administrator
    //true = is trust channel administrator

    function isTrustChannelAdministrator(address _trustChannelAdministratorAddress,
                                         address _trustChannelAddress) public returns (bool result) {
        emit EVT_IsTrustChannelAdministrator(_trustChannelAdministratorAddress, _trustChannelAddress, trustChannelAdministratorExistsMapping[_trustChannelAddress][_trustChannelAdministratorAddress]);
        if (trustChannelAdministratorExistsMapping[_trustChannelAddress][_trustChannelAdministratorAddress] == true) {
            //is trust channel administrator
            return true;
        } else {
            //not trust channel administrator
            return false;
        }
    }

    //returns:
    //address(0) = no trust channel administrator found
    //[address] = address of trust channel administrator

    function getTrustChannelAdministratorForTrustChannelByIndex(address _trustChannelAddress,
                                                                uint64 _index) public returns (address result) {
        if (trustChannelAdministratorsArray[_trustChannelAddress].length > _index) {
            return trustChannelAdministratorsArray[_trustChannelAddress][_index];
        } else {
            //not no trust channel administrator found
            return address(0);
        }
    }

    //returns:
    // 0 = not trust channel administrator
    // 1 = already a trust channel administrator for this trust channel
    // 1 = set new trust channel administrator for this trust channel

    //@note:@todo:@audit: does this work better if we had a multisig equivalent for the channel administrators?
    function trustChannelAdministratorAddChannelAdministrator(address _newTrustChannelAdministratorAddress,
                                                         address _trustChannelAddress) public returns (uint16 result) {
        if (isTrustChannelAdministrator(msg.sender, _trustChannelAddress) == true) {
            if (isTrustChannelAdministrator(_newTrustChannelAdministratorAddress, _trustChannelAddress) == false) {
                trustChannelAdministratorExistsMapping[_trustChannelAddress][_newTrustChannelAdministratorAddress] = true;
                trustChannelAdministratorsIndexMapping[_trustChannelAddress][_newTrustChannelAdministratorAddress] = uint64(trustChannelAdministratorsArray[_trustChannelAddress].length);
                trustChannelAdministratorsArray[_trustChannelAddress].push(_newTrustChannelAdministratorAddress);

                //set new trust channel administrator for this trust channel
                return 2;
            } else {
                //already a trust channel administrator for this trust channel
                return 1;
            }
        } else {
            //not trust channel administrator
            return 0;
        }
    }

    //returns:
    // 0 = not trust channel administrator
    // 1 = trust channel administrator doesn't exist for this trust channel
    // 1 = trust channel administrator removed for this trust channel

    //@note:@todo:@audit: does this work better if we had a multisig equivalent for the channel administrators?
    //@note:@todo:@test: write tests surrounding this function.
    function trustChannelAdministratorRemoveChannelAdministrator(address _trustChannelAdministratorAddressToRemove,
                                                                 address _trustChannelAddress) public returns (uint16 result) {
        if (isTrustChannelAdministrator(msg.sender, _trustChannelAddress) == true) {
            if (isTrustChannelAdministrator(_trustChannelAdministratorAddressToRemove, _trustChannelAddress) == true) {
                trustChannelAdministratorExistsMapping[_trustChannelAddress][_trustChannelAdministratorAddressToRemove] = false;

                //clear out the trust channel administrator association at a specific index so that the getter for the
                // trust channel administrators at index N returns a zero address.
                uint64 index = trustChannelAdministratorsIndexMapping[_trustChannelAddress][_trustChannelAdministratorAddressToRemove];
                trustChannelAdministratorsArray[_trustChannelAddress][index] = address(0);

                //trust channel administrator removed for this trust channel
                return 2;
            } else {
                //trust channel administrator doesn't exist for this trust channel
                return 1;
            }
        } else {
            //not trust channel administrator
            return 0;
        }
    }

    //returns:
    // 0 = not administrator
    // 1 = not enough administrators have permissioned change
    // 2 = trust channel removed

    //@note:@here:@todo:@next:@audit:@critical: what happens to the trust channel mappings when a trust channel is removed.
    //
    // thoughts; you'd be able to process offline the users affected by that trust channel, and manually remove the trust channel
    // from each, and from all of the trust anchors that it had been associated to. After that, it could be re-assigned.
    // this could be a very heavy gas costs #statisticalmodelling.

    // however, consider that this trust anchor attestation is like a license.

//    function adminRemoveTrustChannel(address _trustChannelAddress) public returns (uint16 result) {
//        if (isAdministrator(msg.sender)) {
//            bytes32 keyKeccak = keccak256("removeTrustChannel", _trustChannelAddress);
//
//            uint16 numPermissions = getPermissionsForMultisignKey(keyKeccak);
//
//            bool permittedToModify;
//
//            if (numPermissions >= maxThreshold) {
//                permittedToModify = true;
//            } else {
//                uint16 numConfirmedPermissions = adminApplyAndGetPermissionsForMultisignKey(keyKeccak);
//
//                if (numConfirmedPermissions >= maxThreshold) {
//                    permittedToModify = true;
//                }
//            }
//
//            if (permittedToModify == true) {
//                bytes32 trustChannelKeccak = keccak256(_trustChannelAddress);
//                trustChannelKeccakToTrustChannelMap[trustChannelKeccak].isActive = false;
//
//                //@note:@here:@security if this function is ill-used by a
//                // malicious admin, the worst they can do is reset the permissions
//                // of the keys, and they have to be the one to execute a key
//                // permissioning to get this far in the stack.
//                adminResetPermissionsForMultisignKey(keyKeccak);
//
//                //trust channel removed
//                return 2;
//
//            } else {
//                //not enough administrators have permissioned change
//                return 1;
//            }
//        } else {
//            //not an administrator
//            return 0;
//        }
//    }

    //returns:
    // 0 = not trust channel administrator
    // 1 = trust channel not active
    // 2 = trust anchor already within mapping
    // 3 = no trust anchor jurisdiction set
    // 4 = trust anchor added to trust channel

    //@note:@next:@todo:@audit: what happens to the existing users of the trust anchor (w / prior attestations) when the
    // trust anchor is associated to this new trust channel. ie are new attestations required?

    function trustChannelAdministratorAddTrustAnchorToTrustChannel( address _trustAnchorAddress,
                                                                    address _trustChannelAddress) public returns (uint8 result) {
        if (isTrustChannelAdministrator(msg.sender, _trustChannelAddress) == true) {
            bytes32 trustChannelKeccak = trustChannelAddressToTrustChannelKeccak[_trustChannelAddress];
            trustChannelMap storage channelMap = trustChannelKeccakToTrustChannelMap[trustChannelKeccak];

            if (channelMap.isActive == true) {
                if (channelMap.trustAnchorAddressExists[_trustAnchorAddress] == false) {

                    //@note: need to check trust anchor jurisdiction in trust anchor manager lookup
                    ITrustAnchorManager trustAnchorManager = ITrustAnchorManager(trustAnchorManagerAddress);
                    uint16 jurisdiction = trustAnchorManager.getTrustAnchorJurisdiction(_trustAnchorAddress);
                    uint32 trustAnchorIndex = trustAnchorManager.getTrustAnchorIndex(_trustAnchorAddress);

                    emit EVT_ReceivedJurisdictionFromTrustAnchor(jurisdiction, _trustAnchorAddress, _trustChannelAddress);

                    if (jurisdiction != NoJurisdiction) {
                        uint32 trustChannelIndex = trustChannelKeccakToTrustChannelIndex[trustChannelKeccak];

                        //separate out the trust channel index number with the sub-mapping. this keeps alignment to 256 bits.
                        //uint24 because the maximum value is the trustChannelIndex (a uint32) shifted over 8 bits.
                        uint24 submapNumber = uint24(trustChannelIndex >> 8);
                        uint8 subIndex = uint8(trustChannelIndex % 256);

                        //when the mapping is done, it is OR'd with the 2(to the power of)trustChannelIndex, subIndex being bounded between 0->2**24-1.
                        //this indicates the trust channel index in a (bounded, but still very very high) address space.

                        trustAnchorIndexToTrustChannelIndexBitField[trustAnchorIndex][submapNumber] |= uint256(2 ** uint256(subIndex));

                        emit EVT_ComposedTrustChannelWithTrustAnchor(trustAnchorIndexToTrustChannelIndexBitField[trustAnchorIndex][submapNumber], trustAnchorIndex, trustChannelIndex, _trustAnchorAddress, _trustChannelAddress);

                        //                        //@note: necessary for trust anchor revocations, and attestation revocation.
//
//                        //separate out the trust anchor submap index with the sub-mapping. this keeps alignment to 256 bits.
//                        uint24 submapNumber = uint24(trustAnchorIndex >> 8);
//                        uint8 subIndex = uint8(trustAnchorIndex % 256);
//
//                        if (channelMap.trustAnchorIndexMapEXBitField.length < (submapNumber + 1)) {
//                            channelMap.trustAnchorIndexMapEXBitField = submapNumber + 1;
//                        }
//                        //@note:@todo:@next: consider the additional complexity if the trust anchor itself is revoked.
//                        channelMap.trustAnchorIndexMapEXBitField[submapNumber] |= (2 ** uint256(subIndex));

                        //and we keep track of the highest channel index for later high-speed compares. for example larger systems
                        //might require more 256 bit table lookup/compares.
                        if (trustAnchorIndexAssociatedToAnyTrustChannels[trustAnchorIndex] == false) {
                            trustAnchorIndexAssociatedToAnyTrustChannels[trustAnchorIndex] = true;
                            trustAnchorIndexToTrustChannelLowestSubmapNumber[trustAnchorIndex] = submapNumber;
                        } else {
                            if (trustAnchorIndexToTrustChannelLowestSubmapNumber[trustAnchorIndex] > submapNumber) {
                                trustAnchorIndexToTrustChannelLowestSubmapNumber[trustAnchorIndex] = submapNumber;
                            }
                        }

                        if (trustAnchorIndexToTrustChannelHighestSubmapNumber[trustAnchorIndex] < submapNumber) {
                            trustAnchorIndexToTrustChannelHighestSubmapNumber[trustAnchorIndex] = submapNumber;
                        }


                        channelMap.channelRules.rulesActive[uint8(TrustChannelRules.AllowTransitAcrossJurisdictions)] = true;

                        //separate out the jurisdiction number with the sub-mapping. this keeps alignment to 256 bits.
                        //@note: reusing "submapNumber" which is uint24, casting to uint8 in further.
                        submapNumber = uint8(jurisdiction >> 8);
                        subIndex = uint8(jurisdiction % 256);
                        //when the mapping is done, it is OR'd with the 2(to the power of)subIndex, subIndex being bounded between 0->255.
                        //this indicates the jurisdiction in a (bounded, but still very very high) address space.

                        uint16 ruleStorageIndex = uint16(2 ** uint256(rules_AllowTransitAcrossJurisdictions)) + uint8(submapNumber);

                        channelMap.channelRules.rulesStorage[ruleStorageIndex] |= bytes32(2 ** uint256(subIndex));

                        channelMap.trustAnchorAddressExists[_trustAnchorAddress] = true;
                        channelMap.numMembers++;

                        emit EVT_AddedTrustAnchorToTrustChannel( ruleStorageIndex,
                                                            trustAnchorIndexToTrustChannelLowestSubmapNumber[trustAnchorIndex],
                                                            trustAnchorIndexToTrustChannelHighestSubmapNumber[trustAnchorIndex],
                                                            _trustAnchorAddress,
                                                            _trustChannelAddress);

                        //trust anchor added to trust channel
                        return 4;
                    } else {

                        //no trust anchor jurisdiction set
                        return 3;
                    }
                } else {
                    //trust anchor already within mapping
                    return 2;
                }
            } else {
                //trust channel not active
                return 1;
            }
        } else {
            //not channel administrator
            return 0;
        }
    }

    //@note:@here:@todo:@next:@test: write tests for this.
    function getTrustChannelLowestSubmapNumberForTrustAnchorIndex(uint32 _trustAnchorIndex) public view returns (uint24 result) {
        return trustAnchorIndexToTrustChannelLowestSubmapNumber[_trustAnchorIndex];
    }

    //@note:@here:@todo:@next:@test: write tests for this.
    function getTrustChannelHighestSubmapNumberForTrustAnchorIndex(uint32 _trustAnchorIndex) public view returns (uint24 result) {
        return trustAnchorIndexToTrustChannelHighestSubmapNumber[_trustAnchorIndex];
    }

    function getTrustChannelIndexBitFieldAtSubmapNumberForTrustAnchorIndex(uint32 _trustAnchorIndex, uint24 submapNumber) public view returns (uint256 result) {
        return trustAnchorIndexToTrustChannelIndexBitField[_trustAnchorIndex][submapNumber];
    }


    //@note: this function performs any necessary notifications across the trust channel routing indicies. If there are event subscribers, most of the logistics can
    // be handled on the app layer instead of the dapp layer. However, automated blockchain accounts, reporting, etc. could do with having specific event subscription
    // calls.

    //returns:
    // 1 -> 2**15 - 1 = kyc levels authorized
    // 0: no routing possible (@note: is this even possible)
    // -1: pseudonymous only
    // -2: bridged kyc only (Civic etc)
    // -3 -> -(2**15 - 1) = bridged kyc modes (@note:@here:@todo:@next: defined these)

    //@note:@todo:@next


    //the routing function is only called when the fully identified trust channel indexes are aligned from a KYC'd user's cache graph.
    //the trust anchors on both the sender and receiver side are guaranteed to exist within this trust channel.
    //
    //if any further rules are required by this trust channel, this function might return false.
    //@note:@todo: other variances such as reporting restrictions might be returned as well from overloaded versions of route.

    //returns:
    // 0 =
    // 1 =

    //@note:@here:@todo:@next:@critical: maybe have this function do a lookup to see if the trust channel has been removed. this would be sorta
    // hacky and I'd prefer if route never got called for invalidated trust channels in the first place (since then the send function
    // needs to perform another lookup)

    function route(uint256 _amount, address _senderIdentifiedAddress, address _receiverIdentifiedAddress, uint32 _trustChannelIndex) public returns (int16 result) {
        trustChannelRules storage channelRules = trustChannelKeccakToTrustChannelMap[trustChannelIndexToTrustChannelKeccak[_trustChannelIndex]].channelRules;

        emit EVT_Route(_senderIdentifiedAddress, _receiverIdentifiedAddress, _amount, _trustChannelIndex);

        if (channelRules.rulesActive[rules_AllowTransitAcrossJurisdictions] == true) {
            // channelRules.rulesActive[rules_AllowTransitAcrossJurisdictions];
            return 1;
        }

        return 1;
    }
}

