// pragma experimental ABIEncoderV2;

pragma solidity ^0.4.19;

import "./Interfaces/ITrustAnchorManager.sol";
import "./Interfaces/IShyftConduit.sol";

import "./ECRecovery.sol";
import "./Administrable.sol";

// ** TrustAnchorReference.sol ** //
// 2018 Shyft. all rights reserved.
// Author Chris Forrester

// context:
// TrustAnchorReference is the basic building block for the trust anchor referencing in the logical kyc caching within the Shyft blockchain.
// This generally relates to a series of map reductions and lists, however in this case we're doing an O(n) lookup within a technically massive
// address space. So to return the proper data we simply do a series of hash comparisons, one per lookup field, and see if a value within this
// space is nonzero, thus indicating a membership class. Further requirements for queries can utilize this format for lookups.

// Admins of this contract are able to be set in order to allow for better management practices.
// Bounties are set on http://www.shyft.network/bounties/TrustAnchorReference.sol for any glitches. Please do literally all the work and send a
// pull request with your divine salvation. #<3s


// patterns used:
// owner pattern.
// administrator pattern.

// irregular usages:
//
// (1) structure:
// hash table based mirrored data accessors for maximum read with a bit of write overhead.
// (1) rationale:
// most contracts depend on this and keeping two hash tables in memory constantly when > 90% of transactions should eventually be using the kyc
// database to at least trigger friendly events re: reputation token is a useful thing.

// compatibility:
// fully ethereum EVM compliant.

// future work:
// research into cost/benefit of upgradability.
// further caching and improvement of read performance/cost.

//@note:@todo:@next: add multisig to the onboard/approve/demotions?

contract TrustAnchorManager is Administrable, ITrustAnchorManager {
    //Events for Trust Anchor-specific metadata updates. This does not necessarily affect the active status or the jurisdiction fields in the
    //Trust Anchors' attestations.
    event EVT_JurisdictionDoesRequireChange( address trustAnchorAddress );
    event EVT_GettingJurisdictionFromTrustAnchor( uint16 jurisdiction, address trustAnchorAddress );

    enum TrustAnchorAccess { Unknown, Onboarded, Verified, Demoted }

    //trust anchors
    mapping (address => TrustAnchorAccess) trustAnchorAccess;
    mapping (address => uint32) trustAnchorIndexes;

    uint32 numTrustAnchors;

    //jurisdictions
    mapping (address => uint16) jurisdictions;
    mapping (address => uint16) jurisdictionsRequiringChange;

    uint16 constant NoJurisdiction = 2 ** 16 - 1;

    //@note:@here:@genesis: this address is hardcoded based on the shyft conduit address which can be
    // pre-generated when a known genesis block and/or creator address of a shyft conduit is known.

    address shyftConduitAddress = address(0x9DB76b4BbAEa76dfdA4552B7B9d4e9D43aBC55FD);

    constructor() public {
        owner = msg.sender;
    }
    
    // ** trust anchor primary management ** //

    //result:
    // 0 = not administrator
    // 1 = trust anchor not unknown state
    // 2 = trust anchor onboarded

    function onboardTrustAnchor(address _trustAnchorAddress) public returns (uint8 result) {
        if (isAdministrator(msg.sender)) {
            if (trustAnchorAccess[_trustAnchorAddress] == TrustAnchorAccess.Unknown) {
                trustAnchorAccess[_trustAnchorAddress] = TrustAnchorAccess.Onboarded;
                //trust anchor onboarded
                return 2;
            } else {
                //trust anchor not unknown state
                return 1;
            }
        } else {
            //not administrator
            return 0;
        }
    }
    
    //result:
    // 0 = not administrator
    // 1 = trust anchor not onboarded
    // 2 = trust anchor verified

    function verifyTrustAnchor(address _trustAnchorAddress) public returns (uint8 result) {
        if (isAdministrator(msg.sender)) {
            if (trustAnchorAccess[_trustAnchorAddress] == TrustAnchorAccess.Onboarded ||
                trustAnchorAccess[_trustAnchorAddress] == TrustAnchorAccess.Demoted) {
                trustAnchorAccess[_trustAnchorAddress] = TrustAnchorAccess.Verified;
                jurisdictions[_trustAnchorAddress] = NoJurisdiction;

                if (trustAnchorIndexes[_trustAnchorAddress] == 0) {
                    trustAnchorIndexes[_trustAnchorAddress] = numTrustAnchors;
                    numTrustAnchors++;
                }

                //trust anchor verified
                return 2;
            } else {
                //trust anchor not onboarded;
                return 1;
            }
        } else {
            //not administrator
            return 0;
        }
    }
    
    //other magic
    
    //result:
    // 0 = not administrator
    // 1 = trust anchor not verified status
    // 2 = trust anchor successfully demoted

    function demoteTrustAnchor(address _trustAnchorAddress) public returns (uint8 result) {
        if (isAdministrator(msg.sender)) {
            if (trustAnchorAccess[_trustAnchorAddress] != TrustAnchorAccess.Verified) {
                trustAnchorAccess[_trustAnchorAddress] = TrustAnchorAccess.Demoted;

                //trust anchor successfully demoted
                return 2;
            } else {
                //trust anchor not verified status
                return 1;
            }
        } else {
            //not administrator
            return 0;
        }

    }

    //result:
    // false = not verified
    // true = is verified

    function isTrustAnchorVerified(address _trustAnchorAddress) public view returns (bool result) {
        if (trustAnchorAccess[_trustAnchorAddress] == TrustAnchorAccess.Verified) {
            //is verified
            return true;
        } else {
            //not verified
            return false;
        }
    }

    //result:
    // 0 -> 2^32-1 = index of trust anchor
    function getTrustAnchorIndex(address _trustAnchorAddress) public view returns (uint32 result) {
        return trustAnchorIndexes[_trustAnchorAddress];
    }


    // ** jurisdictions management ** //

    // @note: by default, jurisdictions can be set once by the Trust Anchor using
    // their private key, then subsequent attempts to change require
    // verification from the contract administrators.

    //result:
    // 0 = not verified
    // 1 = jurisdiction already set, now waiting for approval
    // 2 = trust anchor jurisdiction has been set up first time

    function setupTrustAnchorJurisdiction(uint16 _newJurisdiction) public returns (uint8 result) {
        if (isTrustAnchorVerified(msg.sender) == true) {
            if (jurisdictions[msg.sender] == NoJurisdiction) {
                jurisdictions[msg.sender] = _newJurisdiction;

                //trust anchor jurisdiction has been set up first time
                return 2;
            } else {
                jurisdictionsRequiringChange[msg.sender] = _newJurisdiction;
                emit EVT_JurisdictionDoesRequireChange(msg.sender);

                //jurisdiction already set, now waiting for approval
                return 1;
            }
        } else {
            //not verified
            return 0;
        }
    }

    //result:
    // 0 = not administrator
    // 1 = no trust anchor found
    // 2 = no jurisdiction change necessary
    // 3 = jurisdiction change occurred

    function approveChange(address _trustAnchorAddress) public returns (uint8 result) {
        if (isAdministrator(msg.sender)) {
            //@note:@here:@next:@todo: set up a multi-signature requirement for approval?
            if (jurisdictions[_trustAnchorAddress] != 0) {
                if (jurisdictionsRequiringChange[_trustAnchorAddress] != 0 &&
                    jurisdictionsRequiringChange[_trustAnchorAddress] != jurisdictions[_trustAnchorAddress]) {
                    jurisdictions[_trustAnchorAddress] = jurisdictionsRequiringChange[_trustAnchorAddress];
                    //@note: @here: this would cause this call to fail with a "Error: base fee exceeds gas limit" error.
                    //not sure why.
                    //delete jurisdictionsRequiringChange[_trustAnchor];

                    //jurisdiction change occurred
                    return 3;
                } else {
                    //no jurisdiction change necessary
                    return 2;
                }
            } else {
                //no trust anchor found
                return 1;
            }
        } else {
            //not administrator
            return 0;
        }
    }

    //@note: only for valid trust anchors, this will return 0 for invalid trust anchors due to the storage
    // characteristics of the ethereum virtual machine.

    //result:
    // 0 -> 2 ** 16 - 2 = jurisdiction found
    // 2 ** 16 - 1 = no jurisdiction found

    function getTrustAnchorJurisdiction(address _trustAnchorAddress) public returns (uint16 result) {
        //jurisdiction found, or 2 ** 31 - 1 is no jurisdiction set

        emit EVT_GettingJurisdictionFromTrustAnchor(jurisdictions[_trustAnchorAddress], _trustAnchorAddress);

        return jurisdictions[_trustAnchorAddress];
    }

    // ** prime revocation manager address retrieval ** //

    function isPrimeRevocationManager(address _primeRevocationManagerAddress) public returns (bool result) {
        IShyftConduit shyftConduit = IShyftConduit(shyftConduitAddress);

        if (shyftConduit.isPrimeRevocationManager(_primeRevocationManagerAddress) == true) {
            return true;
        } else {
            return false;
        }
    }
}
