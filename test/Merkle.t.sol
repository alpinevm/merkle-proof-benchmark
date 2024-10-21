// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Test, console} from "forge-std/src/Test.sol";
import {MerkleProofLib} from "solady/src/utils/MerkleProofLib.sol";

contract MerkleProxy {
    function verify(
        bytes32[] memory proof,
        bytes32 root,
        bytes32 leaf
    ) public pure returns (bool) {
        return MerkleProofLib.verify(proof, root, leaf);
    }
}

contract MerkleTest is Test {
    MerkleProxy public merkle;

    function setUp() public {
        merkle = new MerkleProxy();
    }

    // @dev Tests merkle proof verification costs for increasing tree sizes
    function testMerkleProofVerificationCosts() public {
        uint256 maxK = 16;

        for (uint256 k = 1; k <= maxK; k++) {
            uint256 leafCount = 2 ** k;
            bytes32[] memory data = _randomDataWithLength(leafCount);
            bytes32 root = _getRoot(data);
            bytes32 leaf = data[0];
            bytes32[] memory proof = _getProof(data, 0);

            uint256 gasBefore = gasleft();
            bool result = merkle.verify(proof, root, leaf);
            uint256 gasUsed = gasBefore - gasleft();
            assertTrue(result);

            console.log("k:", k);
            console.log("Leaf count:", leafCount);
            console.log("Gas used:", gasUsed);
            console.log("---");
        }
    }

    function _randomDataWithLength(
        uint256 n
    ) internal returns (bytes32[] memory result) {
        result = new bytes32[](n);
        unchecked {
            for (uint256 i; i != n; ++i) {
                result[i] = bytes32(_random());
            }
        }
    }

    // Beyond here is taken from https://github.com/Vectorized/solady/blob/v0.0.259/test/MerkleProofLib.t.sol

    function _getRoot(bytes32[] memory data) private pure returns (bytes32) {
        require(data.length > 1);
        while (data.length > 1) {
            data = _hashLevel(data);
        }
        return data[0];
    }

    function _getProof(
        bytes32[] memory data,
        uint256 nodeIndex
    ) private pure returns (bytes32[] memory) {
        require(data.length > 1);

        bytes32[] memory result = new bytes32[](64);
        uint256 pos;

        while (data.length > 1) {
            unchecked {
                if (nodeIndex & 0x1 == 1) {
                    result[pos] = data[nodeIndex - 1];
                } else if (nodeIndex + 1 == data.length) {
                    result[pos] = bytes32(0);
                } else {
                    result[pos] = data[nodeIndex + 1];
                }
                ++pos;
                nodeIndex /= 2;
            }
            data = _hashLevel(data);
        }
        // Resize the length of the array to fit.
        /// @solidity memory-safe-assembly
        assembly {
            mstore(result, pos)
        }

        return result;
    }

    function _hashLevel(
        bytes32[] memory data
    ) private pure returns (bytes32[] memory) {
        bytes32[] memory result;
        unchecked {
            uint256 length = data.length;
            if (length & 0x1 == 1) {
                result = new bytes32[](length / 2 + 1);
                result[result.length - 1] = _hashPair(
                    data[length - 1],
                    bytes32(0)
                );
            } else {
                result = new bytes32[](length / 2);
            }
            uint256 pos = 0;
            for (uint256 i = 0; i < length - 1; i += 2) {
                result[pos] = _hashPair(data[i], data[i + 1]);
                ++pos;
            }
        }
        return result;
    }

    function _hashPair(
        bytes32 left,
        bytes32 right
    ) private pure returns (bytes32 result) {
        /// @solidity memory-safe-assembly
        assembly {
            switch lt(left, right)
            case 0 {
                mstore(0x0, right)
                mstore(0x20, left)
            }
            default {
                mstore(0x0, left)
                mstore(0x20, right)
            }
            result := keccak256(0x0, 0x40)
        }
    }

    function testEmptyCalldataHelpers() public {
        assertFalse(
            MerkleProofLib.verifyMultiProofCalldata(
                MerkleProofLib.emptyProof(),
                bytes32(0),
                MerkleProofLib.emptyLeaves(),
                MerkleProofLib.emptyFlags()
            )
        );

        assertFalse(
            MerkleProofLib.verifyMultiProof(
                MerkleProofLib.emptyProof(),
                bytes32(0),
                MerkleProofLib.emptyLeaves(),
                MerkleProofLib.emptyFlags()
            )
        );
    }

    function _random() internal returns (uint256 result) {
        uint256 _TESTPLUS_RANDOMNESS_SLOT = 0xd715531fe383f818c5f158c342925dcf01b954d24678ada4d07c36af0f20e1ee;
        uint256 _LPRNG_MULTIPLIER = 0x100000000000000000000000000000051;
        uint256 _LPRNG_MODULO = 0xffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff43;
        /// @solidity memory-safe-assembly
        assembly {
            result := _TESTPLUS_RANDOMNESS_SLOT
            let sValue := sload(result)
            mstore(0x20, sValue)
            let r := keccak256(0x20, 0x40)
            // If the storage is uninitialized, initialize it to the keccak256 of the calldata.
            if iszero(sValue) {
                sValue := result
                calldatacopy(mload(0x40), 0x00, calldatasize())
                r := keccak256(mload(0x40), calldatasize())
            }
            sstore(result, add(r, 1))

            // Do some biased sampling for more robust tests.
            // prettier-ignore
            for {} 1 {} {
                let y := mulmod(r, _LPRNG_MULTIPLIER, _LPRNG_MODULO)
                // With a 1/256 chance, randomly set `r` to any of 0,1,2,3.
                if iszero(byte(19, y)) {
                    r := and(byte(11, y), 3)
                    break
                }
                let d := byte(17, y)
                // With a 1/2 chance, set `r` to near a random power of 2.
                if iszero(and(2, d)) {
                    // Set `t` either `not(0)` or `xor(sValue, r)`.
                    let t := or(xor(sValue, r), sub(0, and(1, d)))
                    // Set `r` to `t` shifted left or right.
                    // prettier-ignore
                    for {} 1 {} {
                        if iszero(and(8, d)) {
                            if iszero(and(16, d)) { t := 1 }
                            if iszero(and(32, d)) {
                                r := add(shl(shl(3, and(byte(7, y), 31)), t), sub(3, and(7, r)))
                                break
                            }
                            r := add(shl(byte(7, y), t), sub(511, and(1023, r)))
                            break
                        }
                        if iszero(and(16, d)) { t := shl(255, 1) }
                        if iszero(and(32, d)) {
                            r := add(shr(shl(3, and(byte(7, y), 31)), t), sub(3, and(7, r)))
                            break
                        }
                        r := add(shr(byte(7, y), t), sub(511, and(1023, r)))
                        break
                    }
                    // With a 1/2 chance, negate `r`.
                    r := xor(sub(0, shr(7, d)), r)
                    break
                }
                // Otherwise, just set `r` to `xor(sValue, r)`.
                r := xor(sValue, r)
                break
            }
            result := r
        }
    }
}
