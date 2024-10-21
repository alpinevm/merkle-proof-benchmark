# Merkle Tree Solidity Gas Cost Analysis

Simple test to analyze gas costs for Merkle tree proof verification, based on the [solady](https://github.com/vectorized/solady) implementation.

## Gas Usage by Tree Size

k = proof length, 2^k = leaf count
For any leaf count n, the cost to verify will always be the value for 2^k where 2^(k-1) < n ≤ 2^k

Example: For a leaf count of 11, 2^3 (8) < 11 ≤ 2^4 (16), so k = 4 and the gas cost to verify a proof for a tree of this size would be ~651

| k | Leaf Count | Gas Used |
|---|------------|----------|
| 1 | 2          | 249      |
| 2 | 4          | 383      |
| 3 | 8          | 517      |
| 4 | 16         | 651      |
| 5 | 32         | 785      |
| 6 | 64         | 919      |
| 7 | 128        | 1,053    |
| 8 | 256        | 1,187    |
| 9 | 512        | 1,321    |
| 10 | 1,024     | 1,455    |
| 11 | 2,048     | 1,589    |
| 12 | 4,096     | 1,723    |
| 13 | 8,192     | 1,857    |
| 14 | 16,384    | 1,991    |
| 15 | 32,768    | 2,125    |
| 16 | 65,536    | 2,259    |
