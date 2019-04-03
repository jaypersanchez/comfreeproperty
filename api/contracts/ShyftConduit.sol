pragma solidity ^0.4.19;

import "./Libraries/SafeMath.sol";

import "./Administrable.sol";

// Shyft Conduit
// con·duit
// /känˌd(y)o͞oət/
// 1. a channel for conveying water or other fluid.

// con·ter·mi·nous
// /känˈtərmənəs/
// 1. sharing a common boundary.

// This contract manages the Shyft inflation organization and delegation to an Administrable distribution by value.
// Because the block reward never changes (only the difficulty parameter), there is no really complex math involved.

// We use linked lists for the Contermious linkages because in the case of a new array, the list can be easily
// associated with the basic mappings without creating extra storage copies.

contract ShyftConduit is Administrable {
    using SafeMath for uint256;

    uint256 constant shyftBlockReward = 2500000000000000000;

    //@note:
    // this is set up such that the distribution amounts (per block) can be set up with a (whitelisted) address.


    struct ContermiousInfo {
        bool whiteListed;

        uint256 whiteShyftedDistributionPercent_leftShifted24Bits;
        uint256 whiteShyftedBalance;

        uint256 lastBlockProcessed;

        //@note: forward linked list.
        address nextLink;
    }

    modifier checkAddressAndValuesArrayLengthsAreEqual(address[] _addresses, uint256[] _values) {
        require(_addresses.length == _values.length);
        _;
    }

    modifier checkIsAdmin() {
        require(isAdministrator(msg.sender));
        _;
    }

    modifier checkForAdminMultisigPermissionsAtOrAboveThreshold(bytes32 _keyKeccak) {
        require(getPermissionsForMultisignKey(_keyKeccak) >= maxThreshold);
        _;
    }

    mapping(address => ContermiousInfo) allContermiousInfo;

    uint16 contermiousCount = 0;

    //@note: contermious address for first of the forward linked list.
    address contermiousZeldaAddress = address(0);
    //@note: nonce for the "setContermiousDistributionAmounts" "_distributionKeyKeccak" input.
    uint256 contermiousGeneration;

    address primeRevocationManagerAddress = address(0);

    constructor() public {
        owner = msg.sender;
    }

    //@note: this function takes in values (n/100%) that are shifted to the left by 24. (2 ^ 24 - 1) = 16777215.
    // this is to apply granularity to the distribution values of 1 in (2 ^ 24) wei equivalents.
    // http://x86asm.net/articles/fixed-point-arithmetic-and-tricks/

    //@note: in the ui that would manage this component, the _distributionKeyKeccak should be the keccak256 of all of
    // the addresses and distribution percentages, along with the current "contermiousGeneration", acting as a nonce.

    //returns:
    // 0 = all distribution percentages added together are over 100%
    // 1 = set contermious distribution amounts

    function setContermiousDistributionAmounts(address[] _contermiousAddresses,
                                               uint256[] _contermiousDistributionPercentages_leftShifted24Bits,
                                               bytes32 _distributionKeyKeccak) public checkForAdminMultisigPermissionsAtOrAboveThreshold(_distributionKeyKeccak)
                                                                                      checkAddressAndValuesArrayLengthsAreEqual(_contermiousAddresses, _contermiousDistributionPercentages_leftShifted24Bits)
                                                                                      returns (uint8 result) {
        integrateAllContermiousDistributionsAndDeWhitelist();

        uint256 totalPercentage_leftShifted24Bits;

        for (uint16 i = 0; i < _contermiousAddresses.length; i++) {
            totalPercentage_leftShifted24Bits = totalPercentage_leftShifted24Bits.add(_contermiousDistributionPercentages_leftShifted24Bits[i]);
        }

        if ((totalPercentage_leftShifted24Bits >> 24) <= 100) {
            for (uint16 j = 0; j < _contermiousAddresses.length; j++) {
                ContermiousInfo storage contermiousInfo = allContermiousInfo[_contermiousAddresses[j]];

                contermiousInfo.whiteShyftedDistributionPercent_leftShifted24Bits = _contermiousDistributionPercentages_leftShifted24Bits[j];
                contermiousInfo.whiteListed = true;

                //@note: create a linked list of all the contermious linkages.
                if (j < _contermiousAddresses.length - 1) {
                    contermiousInfo.nextLink = _contermiousAddresses[j + 1];
                } else {
                    contermiousInfo.nextLink = address(0);
                }
            }

            contermiousCount = uint16(_contermiousAddresses.length);
            //@note: set first address for forward linked list.
            contermiousZeldaAddress = _contermiousAddresses[0];

            contermiousGeneration++;

            adminResetPermissionsForMultisignKey(_distributionKeyKeccak);

            // set contermious distribution amounts
            return 1;
        } else {
            // all distribution percentages added together are over 100%
            return 0;
        }
    }

    // @note: helper function for "setContermiousDistributionAmounts".

    function integrateAllContermiousDistributionsAndDeWhitelist() internal {
        address contermiusAddress = contermiousZeldaAddress;

        for (uint16 i = 0; i < contermiousCount; i++) {
            ContermiousInfo storage contermiousInfo = allContermiousInfo[contermiusAddress];

            uint256 numBlocksToProcess = block.number - contermiousInfo.lastBlockProcessed;

            if (numBlocksToProcess > 0) {
                contermiousInfo.whiteShyftedBalance.add(((contermiousInfo.whiteShyftedDistributionPercent_leftShifted24Bits * numBlocksToProcess * shyftBlockReward) >> 24) / 100);
            }

            contermiousInfo.whiteShyftedDistributionPercent_leftShifted24Bits = 0;

            contermiousInfo.whiteListed = false;

            contermiusAddress = contermiousInfo.nextLink;

            contermiousInfo.nextLink = 0;
        }
    }

    // @note: it's in everyone's best interest to run this function (or the "integrateIndividual" one) every block.

    //returns:
    // 0 = nothing to process
    // 1 -> n = n blocks processed

    function integrateAllContermiousDistributions() internal returns (uint256 result) {
        uint256 highestNumberOfBlocksProcessed = 0;

        address contermiusAddress = contermiousZeldaAddress;

        for (uint16 i = 0; i < contermiousCount; i++) {
            ContermiousInfo storage contermiousInfo = allContermiousInfo[contermiusAddress];

            uint256 numBlocksToProcess = block.number - contermiousInfo.lastBlockProcessed;

            if (numBlocksToProcess > 0) {
                contermiousInfo.whiteShyftedBalance.add(((contermiousInfo.whiteShyftedDistributionPercent_leftShifted24Bits * numBlocksToProcess * shyftBlockReward) >> 24) / 100);

                contermiousInfo.lastBlockProcessed = block.number;

                if (contermiousInfo.lastBlockProcessed > highestNumberOfBlocksProcessed) {
                    highestNumberOfBlocksProcessed = contermiousInfo.lastBlockProcessed;
                }
            }

            contermiusAddress = contermiousInfo.nextLink;
        }

        return highestNumberOfBlocksProcessed;
    }

    //returns:
    // 0 = nothing to process
    // 1 -> n = n blocks processed

    function integrateIndividualContermiousDistribution(address _contermiousAddress) public returns (uint256 result) {
        ContermiousInfo storage contermiousInfo = allContermiousInfo[_contermiousAddress];
        uint256 numBlocksToProcess = block.number - contermiousInfo.lastBlockProcessed;

        if (contermiousInfo.whiteShyftedDistributionPercent_leftShifted24Bits > 0 && numBlocksToProcess > 0) {
            contermiousInfo.whiteShyftedBalance.add(((contermiousInfo.whiteShyftedDistributionPercent_leftShifted24Bits * numBlocksToProcess * shyftBlockReward) >> 24) / 100);
            contermiousInfo.lastBlockProcessed = block.number;

            // n blocks processed
            return numBlocksToProcess;
        } else {
            // nothing to process
            return 0;
        }
    }

    function withdrawIndividualContermiousDistribution(uint256 _value) public {
        require(checkSelfBalance() >= _value);
        require(checkContermiusWhiteShyftedBalance(msg.sender) >= _value);

        allContermiousInfo[msg.sender].whiteShyftedBalance.sub(_value);

        msg.sender.transfer(_value);
    }

    //returns:
    // 0 -> n = this contract's balance

    function checkSelfBalance() public view returns (uint256 value) {
        // this contract's balance
        return address(this).balance;
    }

    //returns:
    // 0 = no shyft kyc contract set
    // or
    // 0 -> n = balance in shyft kyc contract for address

    function checkContermiusWhiteShyftedBalance(address _address) public view returns (uint256 balance) {
        return allContermiousInfo[_address].whiteShyftedBalance;
    }

    //returns:
    // true/false = is whitelisted or not

    function isValidContermiousAddress(address _contermiousAddress) public view returns (bool result) {
        //is whitelisted or not
        return allContermiousInfo[_contermiousAddress].whiteListed;
    }

    // ** prime revocation manager address management & retrieval ** //

    //returns:
    // 0 = not an administrator
    // 1 = only one administrator has permissioned change
    // 2 = prime revocation manager set

    function setPrimeRevocationManagerAddress(address _primeRevocationManagerAddress) public returns (uint8 result) {
        require(_primeRevocationManagerAddress != address(0));

        if (isAdministrator(msg.sender)) {
            bytes32 keyKeccak = keccak256(abi.encodePacked("primeRevocationManagerAddress", _primeRevocationManagerAddress));

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
                primeRevocationManagerAddress = _primeRevocationManagerAddress;

                adminResetPermissionsForMultisignKey(keyKeccak);

                // prime revocation manager set
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
    // false = is not prime revocation manager address
    // true = is prime revocation manager address

    function isPrimeRevocationManager(address _primeRevocationManagerAddress) public returns (bool result) {
        if (primeRevocationManagerAddress == _primeRevocationManagerAddress) {
            //is prime revocation manager address
            return true;
        } else {
            //is not prime revocation manager address
            return false;
        }
    }
}