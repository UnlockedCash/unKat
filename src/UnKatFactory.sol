// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

import {UnKat} from "./UnKat.sol";

struct Fees {
    uint128 opsFee;
    uint128 referralFee;
}

contract UnKatFactory is Ownable {
    uint256 constant BPS = 10_000;
    uint256 public constant MAX_TOTAL_FEES = 1500; //15% max

    ERC20 public immutable kat;
    UnKat public immutable unKat;

    bool public isEnabled;
    Fees private fees;
    mapping(address => bool) public isVault;
    mapping(address => address) public userVault;
    mapping(address => bool) public authorizedReferral;

    constructor(address _kat, uint256 _opsFee, uint256 _referralFee) Ownable(msg.sender) {
        kat = ERC20(_kat);
        unKat = new UnKat(_kat);

        require(_opsFee + _referralFee <= MAX_TOTAL_FEES, "FeesToHigh");
        fees = Fees({opsFee: uint128(_opsFee), referralFee: uint128(_referralFee)});
    }

    function deployVault(address _referral) external {
        //TODO
    }

    function setAuthorizedReferral(address _referral, bool _isEnabled) external onlyOwner {
        authorizedReferral[_referral] = _isEnabled;
    }

    function setIsEnabled(bool _isEnabled) external onlyOwner {
        isEnabled = _isEnabled;
    }

    function setFees(uint256 _opsFee, uint256 _referralFee) external onlyOwner {
        require(_opsFee + _referralFee <= MAX_TOTAL_FEES, "FeesToHigh");
        fees = Fees({opsFee: uint128(_opsFee), referralFee: uint128(_referralFee)});
    }

    function getFees() external view returns (Fees memory) {
        return fees;
    }
}
