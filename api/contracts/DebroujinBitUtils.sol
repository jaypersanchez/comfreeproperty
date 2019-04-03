pragma solidity ^0.4.19;

// 2018 Shyft Inc.
// Author: Chris F.
//
//
// This contract is solidity translated from I believe C, from a source on the internet
// discovered whilst searching for bit hacks.
// this clever Debroujin Sequence is something like "for every three bit sliding window
// the pattern does not equal the binary equivalent of another three bit sliding window"
// ...
// the cool part is, this seemingly random string of logic strung together actually is a
// completely valid mathematical marvel that allows us to create a lookup table of this
// string of 1's and 0's, and with one AND, one multiply, one right shift, and 3 assignments
// into memory, we can get the rightmost bit (lower endian systems).
//
// shifting is defined in solidity as:
// "case Token::SHL:
//		m_context << Instruction::SWAP1 << u256(2) << Instruction::EXP << Instruction::MUL;"
// (https://github.com/ethereum/solidity/pull/1487/commits/b8b4f5e9f9a89eac1218551b5da322b41c7813f4)
// and EXP is defined in the evm gas cost manual as:
// "If exponent is 0, gas used is 10. If exponent is greater than 0, gas used is 10 plus 10
//  times a factor related to how large the log of the exponent is."
// (https://docs.google.com/spreadsheets/d/1n6mRqkBz3iWcOlRem_mO09GtSKEKrAsfO7Frgx18pNU/edit#gid=0)
//
// so the total cost is 3 + 5 + ( 10 + (0 ..> 4 * 10) ) for an average cost of 8 + 30 = 38 gas.
// not bad!!
// the general strategy afterwards is to AND the resultant bit with the field set to zero and
// each of the other 31 bits set to 1, to reduce that bit out of the field. then this operation
// can be ran again to find the next rightmost bit set.
//
// clever use of this allows for a very large field size, and when properly pre-calculated
// (say for example in the Shyft KYC smart contract) sparse fields can be compared with very
// little cost compared to direct array iteration.
//
//
// To reverse a 32 bit string (sometimes necessary depending on other operations) we can do
// 10 shifts, 8 ANDs, and 6 ors, with 3 assignments into memory.
//
// one more assignment can be used (which is not to allow for in-solidity debugging.

contract DebroujinBitUtils {
    uint32 debruijn32 = 0x077CB531;
    /* debruijn32 = 0000 0111 0111 1100 1011 0101 0011 0001 */
    /* table to convert debruijn index to standard index */
    uint32[32] index32;
    /* routine to initialize index32 */

    //returns:
    // true

    function setupDebroujinTable() public returns (bool result){
        for (uint8 i = 0; i < 32; i++) {
            index32[ (debruijn32 << i) >> 27 ] = i;
        }

        return true;
    }
    
    /* compute index of rightmost 1 */
    function rightmost_index(uint32 b) public view returns (uint32 result)
    {
        b &= -b;
        b *= debruijn32;
        b >>= 27;
        // uint32 value = b;
        return index32[b];
    }
    
    function reverse_bits(uint32 n) public pure returns (uint32 result) {
        // note: mutating formal parameter
        n = ((n & uint32(0x55555555)) << 1) | ((n >> 1) & 0x55555555);
        n = ((n & 0x33333333) << 2) | ((n >> 2) & 0x33333333);
        n = ((n & 0x0F0F0F0F) << 4) | ((n >> 4) & 0x0F0F0F0F);

//        uint32 value = (n >> 24) | ((n >> 8) & 0xFF00) | ((n & 0xFF00) << 8) | (n << 24);
        return (n >> 24) | ((n >> 8) & 0xFF00) | ((n & 0xFF00) << 8) | (n << 24);
    }

    function numberOfSetBits(uint32 i) public pure returns (uint32 result) {
        // note: mutating formal parameter
        i = i - ((i >> 1) & 0x55555555);
        i = (i & 0x33333333) + ((i >> 2) & 0x33333333);
        return (((i + (i >> 4)) & 0x0F0F0F0F) * 0x01010101) >> 24;
    }
}
