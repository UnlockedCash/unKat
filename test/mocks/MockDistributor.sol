// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract MockDistributor {
    bytes32 root;

    constructor() {}

    function setRoot(bytes32 _root) external {
        root = _root;
    }

    function getMerkleRoot() external view returns (bytes32) {
        return root;
    }

    function claim(
        address[] calldata users,
        address[] calldata tokens,
        uint256[] calldata amounts,
        bytes32[][] calldata proofs
    ) external {
        for (uint256 i; i < users.length;) {
            address user = users[i];
            address token = tokens[i];
            uint256 amount = amounts[i];

            // Verifying proof
            bytes32 leaf = keccak256(abi.encode(user, token, amount));
            require(_verifyProof(leaf, proofs[i]));

            ERC20(token).transfer(user, amount);
        }
    }

    function _verifyProof(bytes32 leaf, bytes32[] memory proof) internal view returns (bool) {
        bytes32 currentHash = leaf;
        uint256 proofLength = proof.length;
        for (uint256 i; i < proofLength;) {
            if (currentHash < proof[i]) {
                currentHash = keccak256(abi.encode(currentHash, proof[i]));
            } else {
                currentHash = keccak256(abi.encode(proof[i], currentHash));
            }
            unchecked {
                ++i;
            }
        }
        require(root != bytes32(0));
        return currentHash == root;
    }
}
