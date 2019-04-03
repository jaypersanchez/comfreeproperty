pragma solidity ^0.4.19;

contract DMTrustAnchorAttestation {
    // Notes on mutability:
    // in regards to the mutability of elements within a struct, potentially all of these could be mutable.
    // identifiedAddress can be replaced with a replacement address, expiryTime can be updated, etc.
    // as such there's a bit field which tracks which elements are dirty, for both comparison and updating into
    // filters at auditing time. Since only things like the expiryTime and identifiedAddress being updated will
    // cause any change in the active status of the attestation, juridiction doesn't need to be updated when
    // querying for the public data field, for example.
    //
    // the creation of the initial keccak256 hash for each of these attestations take:
    // trust anchor address
    // identified address
    // jurisdiction
    // effective time
    // expiry time
    // documents[first index, which is the bitmap of the documents]
    // document availability address
    // public data field[first index, which is the number of times this attestation has changed]
    //
    // this keccak hash is used to index this attestation *no matter how many times it has changed*.
    // the nonce in the hash means that it can never be collided with, with the proper smart contract guards in place.

    // The Jurisdiction field is set as a uint16, and while this may seem low (65536 limit) because of the nature of
    // the searches and compilation later on, there's still a loop limit involved in each 256 bit word comparison.
    // this is maximum 30-50 per call using enormous amounts of gas, which isn't the situation we want to see happen.
    //
    // Generally, each search should hit a match within the first two word comparisons (512 "correct" answers) which
    // indicate 512 main channels, with secondary channels baking in their own trust channel traversal maps, leading
    // to most users having access through the central hubs, and thus have low fees.
    //
    // Interestingly enough, this same mechanism could allow central trust channels to receive a split for the fees
    // for the longer range ones, dependant on how much the user saved with this easier traversal.

    struct trustAnchorAttestation {
        bool attestationStatusApproved;
        
        bytes32 keccakHash;
        address trustAnchorAddress;
        uint32 trustAnchorIndex;

        address identifiedAddress;
        uint16 jurisdiction;
        uint64 effectiveTime;
        uint64 expiryTime;
        bytes publicData;

        bytes documentsEncrypted;
        bytes32 documentAvailabilityEncrypted;

        bytes32[2] attestationValidityTrustAnchorSignatureRS;
        uint8 attestationValidityTrustAnchorSignatureV;
        bytes32[2] attestationValidityUserSignatureRS;
        uint8 attestationValidityUserSignatureV;
        
        uint8 consentAvailable;

        mapping(address => bool) validations;
        address[] validationsArray;

        mapping(address => bool) dataRetrievalTargets;
        address[] dataRetrievalTargetsArray;

        uint16 fieldsDirtyBitMap;
    }

    struct graphCacheableTrustAnchorAttestation {
        bytes32 keccakHash;

        address identifiedAddress;
        uint16 jurisdiction;
        uint64 effectiveTime;
        uint64 expiryTime;

        bytes32 documentAvailabilityEncrypted;

        // bytes32 trustAnchorPublicAddressEncrypted;
    }
}

