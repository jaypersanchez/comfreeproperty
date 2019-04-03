pragma solidity ^0.4.19;

// Administrable Contract:
//
// The basic keyed permission access is done with a multiple signing & revocation certificiate mechanism.
// Built to be as light-weight as possible and still provide the flexibility required to manage full stack
// dapp integrations.
//
// Maximum capacity is 7 administrators. Threshold is at 2/7(max). Expectations are 2 out of 3.
// @note:@todo:@next: set up option for changing the threshold. would need to be very careful about promote/Revoked
//  steps.

// @note:@security:@safety: This function needs to be fully vetted and edge cases examined & documented.

contract Administrable {
    enum AdministratorAccess { Unknown, Promoted, Demoted }
    enum KeyPermissionAccess { Unknown, Signed, Revoked, Reset }
    
    uint8 maxAdministrators = 7;
    uint8 maxThreshold = 2;
    uint8 constant minimumThreshold = 2;
    uint8 constant minimumAdministrator = 7;

    struct keyPermissions {
        mapping(address => KeyPermissionAccess) administratorSignatures;
        address[] administrators;

        uint8 permissionLevel;
    }

    address public owner;

    //administrators
    mapping (address => uint8) administrationRevocationVoting;
    mapping (address => AdministratorAccess) administrators;
    uint8 numAdministrators;

    mapping (bytes32 => keyPermissions) administratorMultisignPermissionedKeys;
    mapping (address => bytes32[]) administrator_to_multisignPermissionedKeysArray;

    // ** administrator management ** //
    function getUserDefinedMaxThreshold() public view returns(uint8) {
        return maxThreshold;
    }

    function getUserDefinedMaxAdministrator() public view returns(uint8) {
        return maxAdministrators;
    }

    function getAdminAccessValue(address _administratorAddress) public returns(uint _access) {
        return uint(administrators[_administratorAddress]);
    }

    /*
    * Allow users to increased threshold
    * make sure the administrable address changing the threshold has proper promotion 
    * and current admin rights has not been revoked
    * 0 = not owner
    * 1 = administrators must be greater than currently set minimum administrators
    * 2 = threshold changed
    */
    function changeCurrentAdminThreshold(uint8 _valueThreshold) public returns(uint8 result) {
        if(isAdministrator(msg.sender)) {
            require(administrators[msg.sender] == AdministratorAccess.Promoted);
            if( _valueThreshold > minimumAdministrator ) { 
                maxAdministrators = _valueThreshold;
                return 2;
            }
            if( _valueThreshold < maxThreshold  ) { 
                //in this case, there has to be more administrator than the currently set maxThreshold
                return 1;
            }
        }
        else {
           return 0;
        }
       
    }//changeCurrentAdminThreshold

    /*
    * Allow users to increased threshold
    * make sure the administrable address changing the threshold has proper promotion 
    * and current admin rights has not been revoked
    * 0 = not owner
    * 1 = must be greater than current minimum threshold setting AND less than currently set maximum administrator
    * 2 = threshold changed
    */
    function changeCurrentThreshold(uint8 _valueThreshold) public returns(uint8 result) {

       /** Check to make sure that the user operating this contract is an administrator **/ 
       if( isAdministrator(msg.sender) ) {
            require(administrators[msg.sender] == AdministratorAccess.Promoted);
       
            if( (_valueThreshold < minimumThreshold) &&  (_valueThreshold > maxAdministrators) ) {
                return 2;
                maxThreshold = _valueThreshold;
            } else {
                //must be greater than current minimum threshold setting AND less than currently set maximum administrator
                return 1; 
            }
        }
        else {
            return 0;
        }
       
    }//changeCurrentThreshold


    //result:
    // 0 = not owner
    // 1 = already set first administrator
    // 2 = setup first administrator
    function setPrimaryAdministrator(address _newAdministratorAddress) public returns (uint8 result) {
        if (msg.sender == owner) {
            if (numAdministrators == 0)
            {
                administrators[_newAdministratorAddress] = AdministratorAccess.Promoted;
                numAdministrators++;

                //setup first administrator
                return 2;
            } else {

                //already set first administrator
                return 1;
            }
        } else {

            //not owner
            return 0;
        }
    }

    //result:
    // 0 = not administrator
    // 1 = administrator already set
    // 2 = new administrator set
    function setAdministrator(address _newAdministratorAddress) public returns (uint8 result) {
        if (isAdministrator(msg.sender)) {
            if (administrators[_newAdministratorAddress] != AdministratorAccess.Promoted) {
                administrators[_newAdministratorAddress] = AdministratorAccess.Promoted;
                numAdministrators++;

                //new administrator set
                return 2;
            } else {
                //administrator already set
                return 1;
            }
        } else {
            //not administrator
            return 0;
        }
    }

    //result:
    // 0 = not owner
    // 1 = administrator already inactive
    // 2 = added vote to revoke administrator
    // 3 = revoked administrator
    function revokeAdministrator(address _revokeAdministratorAddress) public returns (uint8 result) {
        if (isAdministrator(msg.sender)) {
            if (administrators[_revokeAdministratorAddress] == AdministratorAccess.Promoted) {
                bytes32 keyKeccak = keccak256(abi.encodePacked("administrationRevocationVote"));
                
                //@note: @here: admin consensus set at maxThreshold minimum
                uint16 multisignResult = adminApplyAndGetPermissionsForMultisignKey(keyKeccak);
                
                if (multisignResult >= maxThreshold) {
                    administrators[_revokeAdministratorAddress] = AdministratorAccess.Demoted;
                    numAdministrators--;
                    
                    //revoked administrator
                    return 3;
                } else {
                    //added vote to revoke administrator
                    return 2;
                }
            } else {
                //administrator already inactive
                return 1;
            }
        } else {
            //not administrator
            return 0;
        }
    }
    
    function checkForCleanupAfterRevocation(address _revokeAdministratorAddress) internal view returns (uint8 result) {
        if (isAdministrator(msg.sender)) {
            if  (administrators[_revokeAdministratorAddress] == AdministratorAccess.Demoted) {
                //check for permission level decreases across all permissioned keys
                for (uint i = 0; i < administrator_to_multisignPermissionedKeysArray[_revokeAdministratorAddress].length; i++) {
                    bytes32 keyKeccack = administrator_to_multisignPermissionedKeysArray[_revokeAdministratorAddress][i];
                    
                    //permission levels will decrease if it's below or at the maximum threshold level.
                    if (administratorMultisignPermissionedKeys[keyKeccack].permissionLevel <= maxThreshold) {
                        //cannot be cleaned up without disrupting permissioned keys
                        return 3;
                    } 
                }
                
                //can be cleaned up without disrupting permissioned keys
                return 2;
            } else {
                //administrator not revoked
                return 1;
            }
        } else {
            //not administrator
            return 0;
        }
    }
    
    function cleanupAfterRevocation(address _revokeAdministratorAddress) internal returns (uint8 result) {
        if (isAdministrator(msg.sender)) {
            if  (administrators[_revokeAdministratorAddress] == AdministratorAccess.Demoted) {
                for (uint i = 0; i < administrator_to_multisignPermissionedKeysArray[_revokeAdministratorAddress].length; i++) {
                    bytes32 keyKeccack = administrator_to_multisignPermissionedKeysArray[_revokeAdministratorAddress][i];
                    
                    administratorMultisignPermissionedKeys[keyKeccack].administratorSignatures[_revokeAdministratorAddress] = KeyPermissionAccess.Revoked;
                    administratorMultisignPermissionedKeys[keyKeccack].permissionLevel--;
                }
                
                //cleaned up
                return 2;
            } else {
                //cannot clean up
                return 1;
            }
        } else {
            //not administrator
            return 0;
        }
    }

    //result
    // 0 to maxAdministrators = #confirmations
    function getPermissionsForMultisignKey(bytes32 _keyKeccak) internal view returns (uint16 result) {
        //(one to the maxAdministrators) #confirmations
        return administratorMultisignPermissionedKeys[_keyKeccak].permissionLevel;
    }

    //result
    // 0 = not administrator
    // 1 = signature not found
    // 2 = signature found
    // 3 = access revoked
    function adminGetSelfConfirmedFromMultisignKey(bytes32 _keyKeccak) internal view returns (uint16 result) {
        if (isAdministrator(msg.sender)) {
            if (administratorMultisignPermissionedKeys[_keyKeccak].administratorSignatures[msg.sender] == KeyPermissionAccess.Revoked) {
                //access revoked
                return 3;
            } else if (administratorMultisignPermissionedKeys[_keyKeccak].administratorSignatures[msg.sender] == KeyPermissionAccess.Signed) {
                //signature found
                return 2;
            } else {
                //signature not found
                return 1;
            }
        } else {
            //not administrator
            return 0;
        }
    }
    
    
    //result
    // 0 = not administrator
    // 1 to maxAdministrators = #confirmations
    function adminApplyAndGetPermissionsForMultisignKey(bytes32 _keyKeccak) internal returns (uint16 result) {
        if (isAdministrator(msg.sender)) {
            if (administratorMultisignPermissionedKeys[_keyKeccak].permissionLevel < maxAdministrators &&
                (administratorMultisignPermissionedKeys[_keyKeccak].administratorSignatures[msg.sender] == KeyPermissionAccess.Unknown ||
                administratorMultisignPermissionedKeys[_keyKeccak].administratorSignatures[msg.sender] == KeyPermissionAccess.Reset)) {
                // increase permission level of the key, apply signature.
                administratorMultisignPermissionedKeys[_keyKeccak].permissionLevel++;
                administratorMultisignPermissionedKeys[_keyKeccak].administratorSignatures[msg.sender] = KeyPermissionAccess.Signed;

                administratorMultisignPermissionedKeys[_keyKeccak].administrators.push(msg.sender);
                administrator_to_multisignPermissionedKeysArray[msg.sender].push(_keyKeccak);
            }
            
            //(one to the maxAdministrators) #confirmations
            return administratorMultisignPermissionedKeys[_keyKeccak].permissionLevel;
        } else {
            //not administrator
            return 0;
        }
    }
    
    //result
    // 0 = not administrator
    // 1 = already reset
    // 2 = reset correctly
    function adminResetPermissionsForMultisignKey(bytes32 _keyKeccak) internal returns (uint8 result) {
        if (isAdministrator(msg.sender)) {
            if (administratorMultisignPermissionedKeys[_keyKeccak].permissionLevel != 0) {
                //remove administrator references
                for (uint i = 0; i < administratorMultisignPermissionedKeys[_keyKeccak].administrators.length; i++) {
                    administratorMultisignPermissionedKeys[_keyKeccak].administratorSignatures[administratorMultisignPermissionedKeys[_keyKeccak].administrators[i]] = KeyPermissionAccess.Reset;
                }

                
                //delete the main holding array
                // delete administratorMultisignPermissionedKeys[_keyKeccak].administrators;
                administratorMultisignPermissionedKeys[_keyKeccak].administrators.length = 0;

                //and reset the permission level
                // delete administratorMultisignPermissionedKeys[_keyKeccak].permissionLevel;
                administratorMultisignPermissionedKeys[_keyKeccak].permissionLevel = 0;

                //reset correctly
                return 2;
            } else {
                //already reset
                return 1;
            }
        } else {
            //not administrator
            return 0;
        }
    }
    
    //returns:
    // false = not over threshold
    // true = is over threshold
    function isConfirmationsIsOverThreshold(uint8 _confirmationNumber) internal view returns (bool result) {
        if (_confirmationNumber >= maxThreshold) {
            //is over threshold
            return true;
        } else {
            //not over threshold
            return false;
        }
    }

    //result: (internal because any derived contracts would probably want this.)
    // true = is administrator
    // false = either administrator unset or demoted
    function isAdministrator(address _administratorAddress) public view returns (bool result) {
        if (administrators[_administratorAddress] == AdministratorAccess.Promoted) {
            //is administrator
            return true;
        } else {
            // either administrator unset or demoted
            return false;
        }
    }

    function getMsgSender() public view returns(address) {
        return msg.sender;
    }
}