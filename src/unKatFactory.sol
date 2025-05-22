// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "@openzeppelin/contracts/access/Ownable.sol";

contract UnKatFactory is Ownable {

    uint256 constant BPS = 10_000;
    uint256 constant MAX_FEE = 1500; //15% max

    bool public isEnabled;
    uint256 public fee; //todo add referral fee + inside unKat mint()
    mapping (address => bool) public isVault;
    mapping (address => address) public userVault;

    constructor() Ownable(msg.sender) {

    }
}