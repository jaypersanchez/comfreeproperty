pragma solidity ^0.4.19;

import "./Interfaces/IShyftBridgeUtilsProver.sol";

import "./Libraries/MerklePatriciaProof.sol";

import "./Administrable.sol";

import "./EIP20.sol";

import "./ShyftSafe.sol";

contract ShyftBridge is Administrable {

    address public shyftSafeAddress = address(0);

    ShyftSafe shyftSafe;

    event EVT_RootStorage(address indexed chain, uint256 indexed start,
        uint256 indexed end, bytes32 headerRoot);

    event EVT_TransitAsset(address indexed shyftSafe, address indexed toChain,
        uint32 indexed bip32X_type, uint256 amount, address tokenAddr,
        address fromChain);

    event EVT_WithdrawAsset(address indexed shyftSafe, address indexed fromChain,
        uint32 indexed bip32X_type, uint256 amount, address tokenAddr);

    event EVT_TokenAdded(address indexed fromChain, uint32 indexed bip32X_type_orig,
        uint32 indexed bip32X_type_new);

    event EVT_TokenAssociated(address indexed toChain, uint32 indexed bip32X_type_from,
        uint32 indexed bip32X_type_to);

    event EVT_Initialized(address addr);

    // The user prepares a withdrawal with Safe data and then releases it with a withdraw.
    struct Withdrawal {
        uint32 bip32X_type;
        address fromChain;
        address safeAddress;
        uint256 amount;
        bytes32 txRoot;
    }
    mapping(address => Withdrawal) public pendingWithdrawals; // remove public when done testing.

    mapping(address => bytes32[]) roots;

    // Tracking the last block for each bridge network
    mapping(address => uint256) lastBlock;

    // Tokens need to be associated between chains.
    // This should work for EVM-compatible tokens but not other BIP32 Tokens
    // bip32_type => tokenAddress
    // fromChainAddress => (oldTokenAddress => newTokenAddress)
    //
    mapping (uint32 => address) bip32_tokens;
    mapping(address => mapping(address => address)) tokens;

    constructor() public {
        owner = msg.sender;
        setPrimaryAdministrator(msg.sender);

        emit EVT_Initialized(msg.sender);
        // we need to pass in shyftSafeAddress; this always reverts.
        /*shyftSafeAddress = _addr;
        uint256 result = setShyftSafeAddress(shyftSafeAddress);

        if(result == 2) {
          shyftSafe = ShyftSafe(shyftSafeAddress);
        }
        else {
          //revert();
        }*/
    }

    //@note:@here:@next: is this still needed?
    // sketchy function for testing
    function init(address _addr) public returns (uint) {
        uint256 result = setShyftSafeAddress(_addr);

        //if(result == 2) {
        shyftSafeAddress = _addr;
        shyftSafe = ShyftSafe(_addr);
        //}

        return result;
    }

    function validateSafe(address _addr) public {
        bytes32 keyKeccak = keccak256(abi.encodePacked("shyftSafeAddress", _addr));
        adminApplyAndGetPermissionsForMultisignKey(keyKeccak);
    }

    // @dev: Since we are assuming Shyft is honest, there's no need to propose a root.
    // Thus, we can simply set an appropriate root.
    //
    // @dev: This function saves a hash to an append-only array of block header hashes
    // associated with the given origin chain address-id.
    //
    // @param _root , the root we want to add
    // @param _chainId, the bridged network from which the header root comes from
    // @param _end, index to ensure that we are indeed adding blocks
    function addRoot(bytes32 _root, address _chainId, uint256 _end) public returns (bool){
        // Make sure we are adding blocks
        assert(_end > lastBlock[_chainId] + 1);

        // Add the header roots
        roots[_chainId].push(_root);

        // Log that Shyft has added a root
        emit EVT_RootStorage(_chainId, lastBlock[_chainId] + 1, _end, _root);
        lastBlock[_chainId] = _end;
        return true;
    }

    // @dev: Create a token and map it to an existing one on the origin chains
    //
    // @param _newToken, index of the new token we want to add
    // @param _origToken, index of the token we want to associate with the new token
    // @param _fromChain, address of the chain that we are currently on
    //
    // TODO: May need to create a modifier so that only the Safe/Administrator calls this function
    function addToken(uint32 _newToken, uint32 _origToken, address _fromChain) public payable returns (bool){
        require(isAdministrator(msg.sender));
        // Ether is represented as address(1). We don't need to map the entire supply
        // because actors need ether to do anything on this chain. We'll assume
        // the accounting is managed off-chain.
        if(bip32_tokens[_newToken] != address(1)){
            assert(bip32_tokens[_newToken] != address(0));
            EIP20 t = EIP20(bip32_tokens[_newToken]);
            t.transferFrom(msg.sender, address(this), t.totalSupply());
            tokens[_fromChain][bip32_tokens[_origToken]] = bip32_tokens[_newToken];

        }
        emit EVT_TokenAdded(_fromChain, _origToken, _newToken);
        return true;

    }

    // @dev: Forward association. Map an existing token to a token on the destination chain.
    //
    // @param _newToken, address of the token we want to exchange on the _toChain
    // @param _origToken, address of the token we are currently using on this chain
    // @param _toChain, address of the chain we want to transfer tokens to
    //
    // TODO: May need to create a modifier so that only the Safe/Administrator calls this function
    function associateToken(uint32 _newToken, uint32 _origToken, address _toChain) public returns (bool){
        require(isAdministrator(msg.sender));
        tokens[_toChain][bip32_tokens[_newToken]] = bip32_tokens[_origToken];
        emit EVT_TokenAssociated(_toChain, _origToken, _newToken);
        return true;
    }

    //returns:
    // 0 = not an administrator
    // 1 = only one administrator has permissioned change
    // 2 = shyft safe set

    function setShyftSafeAddress(address _shyftSafeAddress) public returns (uint8 result) {
        require(_shyftSafeAddress != address(0));

        if (isAdministrator(msg.sender)) {
            bytes32 keyKeccak = keccak256(abi.encodePacked("shyftSafeAddress", _shyftSafeAddress));

            uint16 numPermissions = adminApplyAndGetPermissionsForMultisignKey(keyKeccak);

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
                shyftSafeAddress = _shyftSafeAddress;

                adminResetPermissionsForMultisignKey(keyKeccak);

                // shyft safe set
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

    // @note: a (wallet) user calls this function to begin the process of "transiting" (moving) their assets across
    // blockchains.
    //
    // the user needs to have assets currently within their Safe hold(s). as long as the asset is with their Safe hold(s)
    // it is guaranteed to be a balance they can transit. in order to induce a proper locking mechanism, the asset has a
    // minimum block confirmation of 6 blocks
    // returns:

    function transitAsset(
        uint32 _bip32X_type,
        uint256 _value,
        uint32 _holdIndex,
        bytes _logsBloom,
        address _toChainId) public returns (uint8 result) {
        // Prove that the asset is in the user's safe hold
        bool assetIsInSafe = proveSafeBalanceForType(_logsBloom, _value, _bip32X_type, _holdIndex);

        // Check if the safe is freed or if the safe is still timelocked
        if(assetIsInSafe){
            uint8 freeSafeHoldRes = shyftSafe.freeSafeHold(_holdIndex);
            if(freeSafeHoldRes == 1) {
                // Safe is still timelocked, so make a deposit bound for a particular chain
                EIP20 t = EIP20(bip32_tokens[_bip32X_type]);
                t.transferFrom(shyftSafeAddress, address(this), _value);
                emit EVT_TransitAsset(shyftSafeAddress, _toChainId, _bip32X_type, _value, bip32_tokens[_bip32X_type], address(this));
                return 1;
            } else {
                // The keep's hold array shouldn't be less than the given _holdIndex
                assert(freeSafeHoldRes != 0);

                // Either the safe hold couldn't be freed or the safe hold could be freed
                if(freeSafeHoldRes == 2){
                    revert();

                    return 2;

                } else {
                    // Hold array was freed
                    return 3;
                }

            }

        } else {
            // Asset not in safe
            return 0;
        }

    }
    // @dev: This function proves that the event EVT_heldSafeBalanceForType has occurred.
    // Source: https://github.com/figs999/Ethereum/blob/master/EventStorage.sol
    //
    // @param _logsBloom, bloom filter for the block in which the event occurred
    // @param _amount, the amount of a particular asset that was added to the safe
    // @param _bip32X_type, the asset that was added to the safe
    // @param _holdIndex, the index of the holdArray in which the asset was deposited in the safe
    function proveSafeBalanceForType(
        bytes _logsBloom,
        uint256 _amount,
        uint32 _bip32X_type,
        uint32 _holdIndex) public view returns (bool) { //change back to internal after testing

        bytes32 eventTopic = keccak256(abi.encodePacked(keccak256(abi.encodePacked("EVT_heldSafeBalanceForType(uint256, uint32, uint256, uint256)"))));
        bytes32 topicShyftAddress = keccak256(abi.encodePacked(shyftSafeAddress));
        bytes32 topicAmount = keccak256(abi.encodePacked(keccak256(abi.encodePacked(_amount))));
        bytes32 topicBIP32Token = keccak256(abi.encodePacked(keccak256(abi.encodePacked(_bip32X_type))));
        bytes32 topicHoldIndex = keccak256(abi.encodePacked(keccak256(abi.encodePacked(_holdIndex))));

        bool foundInLogs = true;

        for(uint b = 0; b < 8; b++) {
            bytes32 bloom = 0;
            for(uint i = 0; i < 6; i += 2){
                assembly {
                    if eq(mod(byte(i, topicShyftAddress), 8), b) {
                        bloom := or(bloom, exp(2, byte(add(1,i), topicShyftAddress)))
                    }

                    if eq(mod(byte(i, eventTopic), 8), b) {
                        bloom := or(bloom, exp(2, byte(add(1, i), eventTopic)))
                    }

                    if eq(mod(byte(i, topicAmount), 8), b) {
                        bloom := or(bloom, exp(2, byte(add(1,i), topicAmount)))
                    }

                    if eq(mod(byte(i, topicBIP32Token), 8), b) {
                        bloom := or(bloom, exp(2, byte(add(1, i), topicBIP32Token)))
                    }

                    if eq(mod(byte(i, topicHoldIndex), 8), b) {
                        bloom := or(bloom, exp(2, byte(add(1,i), topicHoldIndex)))
                    }
                }
            }

            assembly {
                if gt(bloom, 0) {
                    let bloomAnd := and(mload(add(_logsBloom, mul(0x20, sub(8,b)))), bloom)
                    let equal := eq(bloomAnd, bloom)

                    if eq(equal, 0) {
                        b := 8
                        foundInLogs := 0
                    }
                }
            }
        }

        return foundInLogs;
    }

    function stringToBytes(string _str) returns (bytes res) {
        assembly {
            let res := 0
            let s := mload(_str)
        }
    }
    /*
    function proveFreedSafeHold(
      bytes _rlpFreeSafeHoldTx,
      bytes _path,
      bytes _parentNodes,
      bytes _logsBloom,
      bytes _holdIndex,

      ) internal returns (bool) {

        return false;

    }

    function proveSafeHoldTimeLocked() internal returns (bool) {

      return false;
    }*/

    // @dev: Prepares the withdrawal of an asset in a destination chain
    //
    // @params _bip32X_type, asset user wants to withdraw
    // @param _value, amount of the asset user wants to withdraw
    // @param _fromChain, the chain on which user deposited the asset
    // @param _txRoot, the transaction root of the block in the "from" chain in which the deposit was made
    // @param _path, path in which the deposited transaction block resides in. It is generated off-chain.
    // @param _parentNodes, list of parent nodes in the deposit transaction
    // @param _rlpDepositTx, rlp-encoded Deposit transaction data

    function prepareWithdrawalOfAsset(
        uint32 _bip32X_type,
        uint256 _value,
        address _fromChain,
        bytes32 _txRoot,
        bytes _path,
        bytes _parentNodes,
        bytes _rlpDepositTx)
    public returns (bool){

        // Prove the transaction root
        // If on an EVM-compatile chain, use MerklePatriciaProof
        // Otherwise, it should be sufficient to use prove
        require(MerklePatriciaProof.verify(_rlpDepositTx, _path, _parentNodes, _txRoot) == true);

        Withdrawal memory w;
        w.bip32X_type = _bip32X_type;
        w.fromChain = _fromChain;
        w.safeAddress = shyftSafeAddress;
        w.amount = _value;
        w.txRoot = _txRoot;

        pendingWithdrawals[shyftSafeAddress] = w;

        return true;

    }

    // @dev: This function let's the user withdraw their assets into their ShyftSafe on the new chain
    // @param _proof, Merkle proof
    // @param _blockNum, block number of the block containing the deposit on the bridged chain
    // @param _timestamp, timestamp of the block containing the deposit on the bridged chain
    // @param _previousHeader, modified header of the block containing the deposit
    // @param _rootIndex, index of the header root on the origin chain
    function withdrawAsset(bytes _proof,
        uint256 _blockNum,
        uint256 _timestamp,
        bytes32 _previousHeader,
        uint _rootIndex)
    public returns (bool){

        Withdrawal memory w = pendingWithdrawals[shyftSafeAddress];

        // Prove that the user has the correct header
        bytes32 leaf = keccak256(abi.encodePacked(_previousHeader, _timestamp, _blockNum, w.txRoot));
        assert(prove(_proof, leaf, roots[w.fromChain][_rootIndex]) == true);

        // Withdraw Tokens
        EIP20 t = EIP20(bip32_tokens[w.bip32X_type]);
        t.transfer(shyftSafeAddress, w.amount);


        // Event for withdrawal
        emit EVT_WithdrawAsset(shyftSafeAddress, w.fromChain, w.bip32X_type, w.amount, bip32_tokens[w.bip32X_type]);
        delete pendingWithdrawals[shyftSafeAddress];

        return true;
    }

    // @dev: Checks if a given address is a ShyftSafe address
    // returns:
    // true = is shyftSafe
    // false = not shyftSafe
    function isShyftSafe(address _potentialShyftSafeAddress) internal view returns (bool result) {
        return (shyftSafeAddress == _potentialShyftSafeAddress);
    }


    // @dev: Verifies a Merkle proof proving the existence of a leaf in a merkle tree.
    //
    // @param _proof Merkle proof containing sibling hashed on the branch from the leaf to the root
    // @param _root Merkle root
    // @param _leaf Leaf of Merkle tree
    function prove(bytes _proof, bytes32 _leaf, bytes32 _root) public pure returns (bool proven) {
        require(_proof.length % 32 == 0);

        uint i;
        bytes32 computedHash;
        bytes32 proofElement;

        computedHash = keccak256(abi.encodePacked(_leaf));
        for(i = 32; i <= _proof.length; i += 32){
            assembly {
                proofElement := mload(add(_proof, i))
            }

            if (computedHash < proofElement) {
                computedHash = keccak256(abi.encodePacked(computedHash, proofElement));
            } else {
                computedHash = keccak256(abi.encodePacked(proofElement, computedHash));
            }
        }

        return computedHash == _root;
    }
}
