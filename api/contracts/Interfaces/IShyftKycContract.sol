pragma solidity ^0.4.0;

import "./IErc20.sol";
import "./IErc223.sol";

contract IShyftKycContract is IERC20, IERC223, IERC223ReceivingContract {
    function withdraw(address _to, uint256 _value) public returns (bool ok);
}
