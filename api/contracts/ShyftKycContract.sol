// pragma experimental ABIEncoderV2;

pragma solidity ^0.4.19;

import './Libraries/SafeMath.sol';

import "./Interfaces/IShyftKycContract.sol";

import "./ShyftCacheGraph.sol";
import "./ShyftSafe.sol";

import "./ShyftKycContractRegistry.sol";

// the size of the bloom filters below will determine the probability of any particular attestation bitmap to
// be present in the filter at that location.

// the attestations are mapped by the keccak hash of the totality of the attestation (thus there are only ever
// one or zero elements set at the keccak hash'd map).
// this is creating a correspondence between the attestation itself and another independant variable (the
// keccak hash of the attestation) with a much lower cost of deletion (described below). This cost can even be
// mitigated by keeping a uint8 as the result space of type of this mapping. hence enum {unknown, enabled, disabled}
// can be used to change the remove the kyc record.

//https://ethereum.stackexchange.com/questions/594/what-are-the-limits-to-gas-refunds

// this lowered cost is found within the context of the attestation creation continuum. as the cost to add
// an attestation with all of the resultant lookups (CAL) is much higher than the cost to removed a kyc record
// from this lookup procedure (RAKL), the total expense is always RAKL - CAL. (R)
// this R "value store" can be used to assist in the half-expense of creating new kyc records.
// by deleting members en-mass (through a routing scheme within an enumerated listing for "disabled" records,
// externally from the smart contract), the initial store can be performed with the deletion of other members,
// the number of which deletions corresponding to the maximum gas refund that can be obtained from the creation
// contract.

// this can be handled in the trust anchor machinery itself, correlating to a "smart" update strategy
// similarly this strategy can be applied to the Shyft Bridge, enabling cheaper bridging with other blockchains
// that follow the same evm/evm cost specification.
// similarly this strategy can applied to the cross blockchain attestation formats that Shyft may want to apply
// to say, PolyMath tokens on the Ethereum blockchain.


// common questions:
// q: "why do you use weird return orders what is your ocd miss"
// a: "in order to produce the most legible return orders within the code, everything is documented and cross referenced.
//    tldr; "deal w/ it"

// it should be noted that all payable functions should utilize revert, as they are dealing with assets.


contract ShyftKycContract is DMTrustAnchorAttestation, ShyftSafe, ShyftCacheGraph, IShyftKycContract {
    //@note: due to https://github.com/trufflesuite/truffle-contract/issues/8
    // events will not log from called contracts (in the attestation revocation call for instance).
    // this allows for debugging internally.

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
    event EVT_TrustChannelBitFieldIndex(uint24 trustChannelIndex);
    event EVT_TrustChannelBitFieldIndexEXT(uint32 index,
        uint32 shifter,
        uint32 trustChannelBitFieldWord,
        uint256 trustChannelBitField,
        uint24 trustChannelIndex);

    event EVT_GotHighestSubmapNumbers(uint24 senderHighestSubmapNumber,
        uint24 receiverHighestSubmapNumber);

    event EVT_GotLowestAndHighestTrustChannelSubmapNumber(uint24 lowestTrustChannelSubmapNumber,
        uint24 highestTrustChannelSubmapNumber);

    event EVT_TrustChannelRouted(uint24 trustChannelIndex,
        address _senderIdentifiedAddress,
        address _receiverIdentifiedAddress);


    //@note:@todo:@next: define "user attested identity" into specs
    // it would be good to research the use of dynamic forward contracts.. another contract that has specifications
    // internal to itself (via an interface for example) and could run arbitrary code based on a user supplying the
    // address with the function call. might need to have 1 2 3 4 variable overloads on it for a variety of purposes
    // this could be useful on the front end as another database could have the function names as strings and a
    // web3 interface could inject that into the dynamic call structure.
    //
    // the rationale behind this is that other forms of attestation may rely on things like merkle tree proof
    // equivalents of other blockchains, and custom code might need to be ran in order to compactify the available
    // data into the users cache graph.
    //
    // #hassomethingtodowithshyftbridge

    using SafeMath for uint256;

    event EVT_WithdrawToAddress(address _from, address _to, uint256 _value);

    /* ERC223 events */
    event EVT_ERC223TokenFallback(address _from, uint256 _value, bytes _data);

    // function remove(uint[] array, uint index) internal returns(uint[] value) {
    //     if (index >= array.length) return;

    //     uint[] memory arrayNew = new uint[](array.length-1);
    //     for (uint i = 0; i<arrayNew.length; i++){
    //         if(i != index && i<index){
    //             arrayNew[i] = array[i];
    //         } else {
    //             arrayNew[i] = array[i+1];
    //         }
    //     }
    //     delete array;
    //     return arrayNew;
    // }

    //@note:@here:@todo: this is erc20/223 compatible balances
    // system should be backwards compatible, basic table:
    // 0 = Bitcoin
    //  ..
    //  ..
    // ShyftTokenType = SHYFT

    mapping(address => mapping(uint32 => uint256)) balances;
    mapping(address => mapping(address => mapping(uint32 => uint256))) allowed;

    constructor() public {
        owner = msg.sender;
    }

    /**************** Cache Graph Utilization ****************/

    //return:
    // 0 : no kyc'd address found
    // -1 : no kyc level determined
    // 1 -> 128: local kyc level found

    //@note: assumes "active" attestations
    // also assumes that "dirty" graphs will be rectified in-situ.
    function getLocalKYCLevel(address _identifiedAddress) public returns (int8 result) {
        if (identifiedAddress_to_kycIdentity[_identifiedAddress].cacheGraph.graphStatus == CacheGraphStatus.Enabled) {
            //local kyc level found
            return identifiedAddress_to_kycIdentity[_identifiedAddress].cacheGraph.constructedLocalKycLevel;
        } else if (identifiedAddress_to_kycIdentity[_identifiedAddress].cacheGraph.graphStatus == CacheGraphStatus.Dirty) {
            reconstructCacheGraph(_identifiedAddress);

            //@note:@todo:@next: return the proper data
            return identifiedAddress_to_kycIdentity[_identifiedAddress].cacheGraph.constructedLocalKycLevel;
        } else {
            //     //no kyc'd address found
            return 0;
        }

        // //@note: here's the bloom filter in action, acting as a global aggregate of the whole. checks for
        // // zero value mean absolutely zero active attestations, without needing to check any external
        // // arrays.

        // if (documentActiveAggregateBloomFilter > 0) {
        //     //no bits set in "active" bloom filter, hence no valid KYC level.
        //     return 0;
        // } else {

        // }
    }

    //returns:
    //@note:@todo:@next: update.
    // 0 : no kyc'd address found
    // -1 : no kyc level determined
    // 1-128: relative kyc level found

    //@note: assumes "active" and "active+consented", trust channel routes
    // also assumes that "dirty" graphs will not be passed in.
    function getRelativeKYCLevelOnlyClean(uint256 _amount,
    //                                    uint256 _senderSafeAmount,
                                          address _senderIdentifiedAddress,
                                          address _receiverIdentifiedAddress,
    //                                    bool _requireMinimumAssets,
    //                                    bool _requireBiometrics,
    //                                    uint256 _senderSafeAmount,
                                          bool _requiredConsentFromAllParties) public returns (int16 result) {
        //we avoid this check due to the "only clean" status, which is two compares and two storage reads
        // if (identifiedAddress_to_kycIdentity[_senderIdentifiedAddress].cacheGraph.graphStatus == CacheGraphStatus.Enabled
        // && identifiedAddress_to_kycIdentity[_receiverIdentifiedAddress].cacheGraph.graphStatus == CacheGraphStatus.Enabled) {

        int16 relativeKycLevel;

        uint32 trustChannelIndex;

        if (_requiredConsentFromAllParties == true) {
            trustChannelIndex = getActiveConsentedTrustChannelBitFieldForPair(_senderIdentifiedAddress, _receiverIdentifiedAddress);
        } else {
            trustChannelIndex = getActiveTrustChannelBitFieldForPair(_senderIdentifiedAddress, _receiverIdentifiedAddress);
        }

        if (trustChannelIndex != NoTrustChannel) {
            ITrustChannelManager trustChannelManager = ITrustChannelManager(trustChannelManagerAddress);

            relativeKycLevel = trustChannelManager.route(_amount, _senderIdentifiedAddress, _receiverIdentifiedAddress, trustChannelIndex);
        }

//        ITrustAnchorStorage trustAnchorStorage = ITrustAnchorStorage(trustAnchorStorageAddress);

        return relativeKycLevel;//identifiedAddress_to_kycIdentity[_identifiedAddress].cacheGraph.constructedLocalKycLevel;

        // //@note: here's the bloom filter in action, acting as a global aggregate of the whole. checks for
        // // zero value mean absolutely zero active attestations, without needing to check any external
        // // arrays.

        // if (documentActiveAggregateBloomFilter > 0) {
        //     //no bits set in "active" bloom filter, hence no valid KYC level.
        //     return 0;
        // } else {

        // }
    }

    //results:
    // 0 = zero kyc detected or error with kyc level
    // 1 = not enough kyc to transfer
    // 2 = not enough balance
    // 3 = can transfer successfully
    // 4 = won't pay for dirty cache cleaning

    function getKycCanSend(uint256 _amount, uint32 _bip32X_type, address _senderIdentifiedAddress, address _receiverIdentifiedAddress, bool _payForDirty) public returns (uint8 result) {
        if (identifiedAddress_to_kycIdentity[_senderIdentifiedAddress].cacheGraph.graphStatus == CacheGraphStatus.Dirty ||
        identifiedAddress_to_kycIdentity[_receiverIdentifiedAddress].cacheGraph.graphStatus == CacheGraphStatus.Dirty) {
            if (!_payForDirty) {
                //won't pay for dirty cache cleaning
                return 4;
            }

            //@note:@todo:@next: add cleaning step.. this could be prohibitively expensive, and so should be watched for. similarly, work could be done
            // to only check attestations from certain jurisdictions. the dirty flags could be made to be easier to process using floating indexes
            // with dirty elements. passing compacted trust channels across with dirty flags would be able to be AND'd effectively.
        }

        //@note: @todo:
        // add favourable jurisdiction checks here ([@phase3: trust channel optimizations])
        // add IEV checks here.. relative KYC level must be above _X_?

        //this is used to check for minimum reserves when transacting across blockchains. This can create a de-facto "accredited investor" status if there
        // is enough crypto and/or crypto assets held in the Safe balance of the sender.

        //other sources of confirmation: external data from the blockchain
        //                               immediate biometric signature
        //                               other user behaviours (local ai)
        //                               conservator concierge (cloud ai)

        int16 relativeKYCLevel = getRelativeKYCLevelOnlyClean(_amount, _senderIdentifiedAddress, _receiverIdentifiedAddress, true);
        // int8 kycSenderAddressLevel = getKYCLevel(_senderIdentifiedAddress);
        // int8 kycReceiverAddressLevel = getKYCLevel(_receiverIdentifiedAddress);

//        uint256 safeBalanceSender = getSafeBalance(_senderIdentifiedAddress, _bip32X_type);

        //@note:@todo:@next: updated and fix return codes.
        if (relativeKYCLevel < 0) {
            if (relativeKYCLevel > 1) {
//                if (safeBalanceSender != 0 && safeBalanceSender > _amount) {

                    //can transfer successfully
                return 3;
//                } else {
//                    //not enough balance
//                    return 2;
//                }
            } else {
                //not enough kyc to transfer
                return 1;
            }
        } else {
            //error with kyc level
            return 0;
        }
    }

    /**************** Shyft Safe ****************/

    //@note:@todo:@next: check whether tx.origin is actually the best way to do this...

    //@note:@here: this is from ShyftSafe.sol inheritance
    // basic rules are: if you have it, and you're asked to hold it, remove it from your supply and place it into safe's.

    //returns
    // 0 = could not hold : 0
    // 1 = held : balance of this contract
    function child_overload_doHoldSafe(uint256 amount, uint32 bip32X_type) internal returns (uint8 result, uint256 balanceResult) {
        //@note: using tx.origin here.. might be an issue in serenity.
        if (balances[tx.origin][bip32X_type] >= amount) {
            balances[tx.origin][bip32X_type] = balances[tx.origin][bip32X_type].sub(amount);
            safeBalances[tx.origin][bip32X_type] = safeBalances[tx.origin][bip32X_type].add(amount);
            //held : balance of this contract
            return (1, balances[tx.origin][bip32X_type]);
        } else {
            //could not hold : 0
            return (0, 0);
        }
    }

    //@note:@here: this is from ShyftSafe.sol inheritance
    // basic rules are: if you have it, and you're asked to hold it, remove it from your safe and place it into free supply.

    //returns:
    // 0 = could not free
    // 1 = freed
    function child_overload_doFreeSafe(uint256 amount, uint32 bip32X_type) internal returns (uint8 result) {
        //@note: using tx.origin here.. might be an issue in serenity.
        if (safeBalances[tx.origin][bip32X_type] >= amount) {
            balances[tx.origin][bip32X_type] = balances[tx.origin][bip32X_type].add(amount);
            safeBalances[tx.origin][bip32X_type] = safeBalances[tx.origin][bip32X_type].sub(amount);
            //freed
            return 1;
        } else {
            //could not free
            return 0;
        }
    }

    /**************** Shyft KYC balances, fallback, send, receive, and withdrawal ****************/
    
    // mutex lock, prevent recursion in functions that use external function calls
    bool locked;
    // new variables needed for upgradability
    bool public hasBeenUpdated;
    address public nextContract;
    address public registryAddr;

    modifier mutex {
        if (locked) revert();
        locked = true;
        _;
        locked = false;
    }

    modifier onlyOwner {
        require(msg.sender == owner);
        _;
    }

    modifier onlyRegistry {
        require(msg.sender == registryAddr);
        _;
    }

    // @note: in token related functions, we need to update which contract the user's tokens are in
    // by calling registry contract and update tokenLocation[msg.sender]
    // not sure if we need to implement in /every/ token function
    // I think we would need to if tokens somehow end up being directly sent to this contract
    // despite there being an updated one
    // if all withdraws go through the registry, it should keep track of where the tokens are ok


    // new function needed for upgradability
    function update(address _addr) onlyRegistry public returns (bool) {
        hasBeenUpdated = true;
        nextContract = _addr;
        return true;
    }
    
    // new function needed for upgradability
    function setRegistry (address _addr) onlyOwner public returns (bool) {
        registryAddr = _addr;
        return true;
    }

    function registryAddr() public returns (address){
        return registryAddr;
    }

    // delete after testing
    function whoIsOrigin() public returns (address){
        return tx.origin;
    }

    function withdrawAll(address _to) public returns (uint) {
        uint _bal = balances[tx.origin][ShyftTokenType];
        withdraw(_to, _bal);
        return _bal;
    }
    
    //gets balance for Shyft KYC token type & synthetics
    function getBalanceBip32X(address _identifiedAddress, uint32 _bip32X_type) public view returns (uint256 balance)  {
        return balances[_identifiedAddress][_bip32X_type];
    }

    //fallback function applies value to Shyft KYC token type

    // fallback runs out of gas when called by a contract
    // limited to 2300 gas
    // idk if this is implementation is sketchy due to the external call, 
    // but we need to move the tokens if the contract is updated

    function () public payable {
        if (hasBeenUpdated) {
            // burn tokens in this contract
            uint _bal = balances[tx.origin][ShyftTokenType];

            //@note:@here:@todo:@next:@critical:
            // tx.origin: possible security issue?
            balances[tx.origin][ShyftTokenType] = 0;
            // call registry so that tokens are forwarded and token location within registry is updated
            registryAddr.call.value(_bal + msg.value).gas(90000)(); 
        } else {
            balances[tx.origin][ShyftTokenType] = balances[tx.origin][ShyftTokenType].add(msg.value);
        }
    }

    //returns
    // 3 = successful transfer (from getKycCanSend)
    // kycCanSendResult = transfer cannot be processed due to incorrect kyc levels or insufficient balance. (from getKycCanSend)

    function kycSend(uint _amount, uint32 _bip32X_type, address _identifiedAddress, bool _payForDirty) public returns (uint8 result) {
        if (balances[msg.sender][_bip32X_type] >= _amount) {
            uint8 kycCanSendResult = getKycCanSend(_amount, _bip32X_type, msg.sender, _identifiedAddress, _payForDirty);

            //getKycCanSend return 3 = can transfer successfully
            if (kycCanSendResult == 3) {
                transferFunds(_amount, _bip32X_type, msg.sender, _identifiedAddress);
                //successful transfer (from getKycCanSend)
                return 3;
            }

            //transfer cannot be processed due to incorrect kyc levels or insufficient balance. (from getKycCanSend)
            return kycCanSendResult;
        } else {
            //must revert here because of the transactional nature of this function.
            revert();
        }
    }

    function transferFunds(uint _amount, uint32 _bip32X_type, address _from, address _to) internal {
        if (_bip32X_type == ShyftTokenType) {
            balances[_from][_bip32X_type] = balances[_from][_bip32X_type].sub(_amount);
            balances[_to][_bip32X_type] = balances[_to][_bip32X_type].add(_amount);
        }
    }


    //@note: this function withdraws the native fuel (Shyft fuel, Ether, et al) to an address.
    // because of the transactional nature, this contract may "revert".

    //returns:
    // true = success

    // @note: changed msg.sender to tx.origin
    function withdraw(address _to, uint256 _value) mutex public returns (bool ok) {
        if (balances[tx.origin][ShyftTokenType] >= _value) {
            uint codeLength;
            bytes memory empty;

            if (hasBeenUpdated) {
                    registryAddr.call.value(_value).gas(20000);
                    ok = true; // instead of explicitly returning, assign return value to variable 
                                // allows the code after the _; in the mutex modifier to be run
            }

            //retrieve the size of the code on target address, this needs assembly
            assembly {
                codeLength := extcodesize(_to)
            }

            balances[tx.origin][ShyftTokenType] = balances[tx.origin][ShyftTokenType].sub(_value);
            balances[_to][ShyftTokenType] = balances[_to][ShyftTokenType].add(_value); // let me know if this shouldn't be here

            if (codeLength > 0) {

                //@note:@research:
                //@note:@todo:@next: what I'd like to do here is have a check for a built-in registry maintained
                // by Shyft et all, with the ability to trigger the fallback of that function.
                //
                // this fallback function would check for this contract's (or others that Shyft's KYC Contract
                // are updated to support) address, and allow for the tokens in this contract to burnt
                // (synthetics only), and throwing in the event that this is not supported, and adding those
                // synthetics to the receiving contract.
                //
                // this would allow for users to upgrade their *tokens*, not the contract itself; this should
                // work well since the protocol base address structures are never going to encounter this,
                // and withdrawing to an account will function indefinitely (allowing sending those native fuel
                // tokens to new Shyft KYC Contract addresses.)

                IERC223ReceivingContract receiver = IERC223ReceivingContract(_to);
                receiver.tokenFallback(tx.origin, _value, empty);

                //@note: @here: @todo: this will need to be updated. currently auto-sending the fuel itself to
                // the destination contract address to support contracts like the Shyft Conduit.

                //@note: this line may throw a revert error if _to is a contract address
                // since fallback function is limited to 2300 gas, only enough to emit an event
                //_to.transfer(_value); doesn't work

                //alternative _to.transfer()
                //we need this much gas to execute the fallback of ShyftKycContract
                //could leave gas empty to forward as much gas as needed
                //this will fail when sending to contracts with fallback functions that consume more than 20000 gas
                if( !_to.call.value(_value).gas(20000)() ) {
                    revert();
                }

                // there is a possible security issue with external function calls sending ether, 
                // especially when sending extra gas
                // possible re-entrancy attack
                // probably won't happen since we decrement balance before this line, but recursion still possible.
            } else {
                //@note: this is going to a regular account. the existing balance has already been reduced,
                // and as such the only thing to do is to send the actual Shyft fuel (or Ether, etc) to the
                // target address.

                _to.transfer(_value);

                //event... this is not named EVT_xyz because of the inheritance requirement.
                emit EVT_WithdrawToAddress(tx.origin, _to, _value);
            }

            //event... this is not named EVT_xyz because of the inheritance requirement.
            emit EVT_WithdrawToAddress(tx.origin, _to, _value);
            // want to make sure contract hasn't been tricked into transferring out more fuel than it should
            // assert(this.balance >= totalSupply); // we never set totalSupply so idk if this is useful
            ok = true;
        } else {
            ok = false;
        }
    }

    /**************** ERC 223 reciever ****************/

    function tokenFallback(address _from, uint _value, bytes _data){
        //@note:@research:
        //@note:@todo:@next: what I'd like to do here is have a check for a built-in registry maintained
        // by Shyft et all, with the ability to trigger the fallback of that function.
        //
        // this fallback function would check for this contract's (or others that Shyft's KYC Contract
        // are updated to support) address, and allow for the tokens in this contract to burnt
        // (synthetics only), and throwing in the event that this is not supported, and adding those
        // synthetics to the receiving contract.
        //
        // this would allow for users to upgrade their *tokens*, not the contract itself; this should
        // work well since the protocol base address structures are never going to encounter this,
        // and withdrawing to an account will function indefinitely (allowing sending those native fuel
        // tokens to new Shyft KYC Contract addresses.)

        emit EVT_ERC223TokenFallback(_from, _value, _data);
    }

    /**************** ERC 223/20 ****************/

    uint public totalSupply;

    //gets balance for Shyft KYC token type
    function balanceOf(address _who) public view returns (uint) {
        return balances[_who][ShyftTokenType];
    }

    function name() public view returns (string _name) {
        return "Shyft";
    }

    function symbol() public view returns (string _symbol) {
        //@note: "SFT" is the 3 letter variant
        return "SHFT";
    }

    function decimals() public view returns (uint8 _decimals) {
        return 18;
    }

    function totalSupply() public view returns (uint256 _supply) {
        return totalSupply;
    }

    //for the following, we assume the transfer is only for [ShyftTokenType] tokens.
    function transfer(address _to, uint256 _value) public returns (bool ok) {
        if (balances[msg.sender][ShyftTokenType] >= _value) {
            uint codeLength;
            bytes memory empty;

            //retrieve the size of the code on target address, this needs assembly
            assembly {
                codeLength := extcodesize(_to)
            }

            balances[msg.sender][ShyftTokenType] = balances[msg.sender][ShyftTokenType].sub(_value);

            balances[_to][ShyftTokenType] = balances[_to][ShyftTokenType].add(_value);


            if (codeLength > 0) {

                //a vm error will occur if this index is accessed without setting the length first.
                //@note:@todo:@next: explicit check for contract format?
                IERC223ReceivingContract receiver = IERC223ReceivingContract(_to);
                receiver.tokenFallback(msg.sender, _value, empty);
            }

            //event... this is not named EVT_xyz because of the inheritance requirement.
            emit Transfer(msg.sender, _to, _value, empty);

            return true;
        } else {
            return false;
        }
    }
    
    function transfer(address _to, uint _value, bytes data) public returns (bool ok) {
        if (balances[msg.sender][ShyftTokenType] >= _value) {
            uint codeLength;

            //retrieve the size of the code on target address, this needs assembly
            assembly {
                codeLength := extcodesize(_to)
            }

            balances[msg.sender][ShyftTokenType] = balances[msg.sender][ShyftTokenType].sub(_value);

            balances[_to][ShyftTokenType] = balances[_to][ShyftTokenType].add(_value);


            if (codeLength > 0) {

                //a vm error will occur if this index is accessed without setting the length first.
                //@note:@todo:@next: explicit check for contract format?
                IERC223ReceivingContract receiver = IERC223ReceivingContract(_to);
                receiver.tokenFallback(msg.sender, _value, data);
            }

            //event... this is not named EVT_xyz because of the inheritance requirement.
            emit Transfer(msg.sender, _to, _value, data);

            return true;
        } else {
            return false;
        }
    }

    function allowance(address _tokenOwner, address _spender) public constant returns (uint remaining) {
       return allowed[_tokenOwner][_spender][ShyftTokenType];
    }

    //@note:@warning: this function is broken.
    function approve(address _spender, uint _tokens) public returns (bool success) {
        allowed[msg.sender][_spender][ShyftTokenType] = _tokens;

        //user a has 20 tokens allowed from zero :: no incentive to frontrun

        //user a has +2 tokens allowed from 20 :: frontrunning would deplete 20 and add 2 :: incentive there.

        emit Approval(msg.sender, _spender, _tokens);

        return true;
    }

    function transferFrom(address _from, address _to, uint _tokens) public returns (bool success) {
        if (allowed[_from][_to][ShyftTokenType] >= _tokens && balances[_from][ShyftTokenType] >= _tokens) {
            allowed[_from][_to][ShyftTokenType] = allowed[_from][_to][ShyftTokenType].sub(_tokens);

            balances[_from][ShyftTokenType] = balances[_from][ShyftTokenType].sub(_tokens);
            balances[_to][ShyftTokenType] = balances[_to][ShyftTokenType].add(_tokens);

            emit Transfer(_from, _to, _tokens);

            return true;
        } else {
            return false;
        }
    }

}
