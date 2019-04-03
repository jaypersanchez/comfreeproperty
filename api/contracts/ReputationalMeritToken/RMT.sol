pragma solidity ^0.4.19;

import '../Libraries/SafeMath.sol';

import "../Interfaces/IErc20.sol";
import "../Interfaces/IErc223.sol";

import "../Administrable.sol";

// RMT (Reputational Merit Token) is the distribution mechanism for the reputation on the Shyft network.
// The purpose is to incentivize early onboarding. this is done through using proportional multipliers per instance
// of distribution.
//
// example:
// if the amount of RMT initially is 100, and the distribution curve is 0.98, the first distribution is
// 100 * 0.98 = 98
// 100 - 98 = 2
// hence 2 is the distribution amount for the first amount allocated.
// the next is (98 - (98 * 0.98)) = 1.96

// all distribution curves are left shifted 24 bits to use a fixed-point like multiplication.
// example: ((100 * (2^24) - (((100 * (2^24)) * (0.98 * (2^24))) / (2^24))) / (2^24) = 98
//
// the tokens themselves are right shifted by 18 places, allowing for proper computation of (tiny) amounts.


// Regions within RMT are as such:
// |.......................|..................|.......................................................................|
//  ^ trust anchors (20%)   ^ bounties (10%)                            ^ future use (70%)

// then, distributions from each region, as new distributors are set up, follow that region's distribution curve.
// >>> trust anchors are the slowest, so for the most part they have minor differences between themselves, and taper off
// in 3-5 years (assuming X trust anchors coming onto the system in a month).
// >>> bounties are faster, tapering off in a year (assuming Y bounties are set out per month).
// >>> future use can have a variable curve structure associated with whatever happens.

// a fun sideproject would be to build out a bunch of subgames categories, with different categories of staking behaviour
// like "loyalist" for those that never move their out of Safe onto another blockchain.

contract RMT is Administrable, IERC20, IERC223, IERC223ReceivingContract {
    using SafeMath for uint256;

    mapping(address => uint256) balances;
    mapping(address => mapping(address => uint256)) allowed;

    uint256 primaryDistributionCurve_leftShifted24Bits;

    //regions
    address[] regionAddresses;
    mapping(address => uint64) regionMapping;
    mapping(address => bool) regionMappingExists;
    // distribution rate
    mapping(address => uint256) regionBaseCurve_leftShifted24Bits;

    //distributions per region
    mapping(address => uint256) currentDistributorsFromRegions;

    //distributors
    address[] distributorAddresses;
    mapping(address => uint64) distributorMapping;
    mapping(address => bool) distributorMappingExists;
    // distribution rate
    mapping(address => uint256) distributorCurve_leftShifted24Bits;

    // distribution per user per distributor
    mapping(address => uint256) currentDistributionsFromDistributor;


    //https://en.wikipedia.org/wiki/Names_of_large_numbers

    // Novemdecillion = 10^60. log2 10^60 = 199 bits in base 2.
    // 199 + 18 decimals of precision + 24 as a bit shift = 241
    // given the state space, there's no reason why a huge amount of "Novems" could be created initially. primary
    // measurements of RMT could be 1 Novem large (10^60).
    // benefits to using such a degree of tokens would be twofold:
    // 1) we'll be using a number both above or below a google, depending on where in the world you ask.
    // 2) the relative supply to donate, show appreciation, etc can be extremely large.
    // in the 256 bits a useful measure of time-spent-using-system.
    // suggested initial amount = 100000000000000000000.

//    function RMT(uint256 _initialRMTAmount18Bits, uint256 _primaryDistributionCurve_percentage18Bits) public {
    constructor(uint256 _primaryDistributionCurve_percentage18Bits) public {
        owner = msg.sender;

        uint256 initialSupply = 10 ** 60;
        totalSupply = initialSupply;

        balances[this] = initialSupply;

        //store distribution curve.
        primaryDistributionCurve_leftShifted24Bits = _primaryDistributionCurve_percentage18Bits << 24;
    }

    //@note: Shyft ownership/administration required.
    //@note: @todo: @next: add Administrable multisig check
    function setupNewRegionWithBaseCurve(address regionAddress, uint256 _regionRMTAmount18Bits, uint256 _newDistributorCurve_percentage18Bits) public {
        regionMapping[regionAddress] = uint64(regionAddresses.length);
        regionMappingExists[regionAddress] = true;
        regionBaseCurve_leftShifted24Bits[regionAddress] = _newDistributorCurve_percentage18Bits << 24;

        balances[this] -= _regionRMTAmount18Bits;
        balances[regionAddress] = _regionRMTAmount18Bits;

        regionAddresses.push(regionAddress);
    }

    //@note: Shyft ownership/administration required.
    //@note: @todo: @next: add Administrable multisig check
    function setupNewDistributionWithCurveInRegion(address _newDistributionAddress, uint256 _newDistributorCurve_percentage18Bits, address _regionAddress) public {
        distributorMapping[_newDistributionAddress] = uint64(distributorAddresses.length);
        distributorMappingExists[_newDistributionAddress] = true;

        distributorCurve_leftShifted24Bits[_newDistributionAddress] = _newDistributorCurve_percentage18Bits << 24;

        //remove the left shifts, and because of the extra 10^18 in the multiplication result, divide by that as well.
        uint256 distributionResult = (((balances[_regionAddress] << 24) * regionBaseCurve_leftShifted24Bits[_regionAddress]) >> 24 >> 24) / (10 ** 18);

        //the result is now a difference between two numbers that have 18 decimal places.
        uint256 distributionAmount = balances[this] - distributionResult;

        balances[_newDistributionAddress] = distributionAmount;
        balances[_regionAddress] -= distributionAmount;

        distributorAddresses.push(_newDistributionAddress);
    }

    //@note: sending to a generalized address, from a distributor.

    //returns
    // 0 = address is not within distribution mapping
    // 1 = invalid target address (cannot send to this contract, a region, or a distributor
    // 2 = distribution successful

    function performDistribution(address _to) public returns (uint8 result) {
        if (distributorMappingExists[msg.sender] == true) {
            if (_to != address(this) && regionMappingExists[_to] == false && distributorMappingExists[_to] == false) {
                uint256 distributionResult = (((balances[msg.sender] << 24) * distributorCurve_leftShifted24Bits[msg.sender]) >> 24 >> 24) / (10 ** 18);
                uint256 distributionAmount = balances[msg.sender] - distributionResult;

                balances[_to] = balances[_to].add(distributionAmount);
                balances[msg.sender] = balances[msg.sender].sub(distributionAmount);

                //distribution successful
                return 2;
            } else {
                //invalid target address (cannot send to this contract, a region, or a distributor
                return 1;
            }
        } else {
            //address is not within distribution mapping
            return 0;
        }
    }

    /**************** ERC 223/20 ****************/

    uint public totalSupply;

    //gets balance for Shyft KYC token type
    function balanceOf(address _who) public view returns (uint) {
        return balances[_who];
    }

    function name() public view returns (string _name) {
        return "Reputational Merit Token";
    }

    function symbol() public view returns (string _symbol) {
        return "RMT";
    }

    function decimals() public view returns (uint8 _decimals) {
        return 18;
    }

    function totalSupply() public view returns (uint256 _supply) {
        return totalSupply;
    }

    function transfer(address _to, uint256 _value) public returns (bool ok) {
        if (_to != address(this) && regionMappingExists[_to] == false && distributorMappingExists[_to] == false) {
            if (balances[msg.sender] >= _value) {
                balances[msg.sender] = balances[msg.sender].sub(_value);
                balances[_to] = balances[_to].add(_value);

                emit Transfer(msg.sender, _to, _value);
                //transfer successful
                return true;
            } else {
                //insufficient balance
                return false;
            }
        } else {
            //invalid target address (cannot send to this contract, a region, or a distributor
            return false;
        }
    }

    function transfer(address _to, uint _value, bytes data) public returns (bool ok) {
        if (data.length == 0) {
            return transfer(_to, _value);
        } else {
            return false;
        }
    }

    function allowance(address _tokenOwner, address _spender) public constant returns (uint remaining) {
        return allowed[_tokenOwner][_spender];
    }

    function approve(address _spender, uint _tokens) public returns (bool success) {
        allowed[msg.sender][_spender] = _tokens;

        emit Approval(msg.sender, _spender, _tokens);

        return true;
    }
}
