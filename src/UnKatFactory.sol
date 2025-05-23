// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {Clones} from "@openzeppelin/contracts/proxy/Clones.sol";
import {Distributor} from "merkl-contracts/contracts/Distributor.sol";

import {UnKat} from "./UnKat.sol";
import {UnKatVault} from "./UnKatVault.sol";

struct Fees {
    uint128 opsFee;
    uint128 referralFee;
}

contract UnKatFactory is Ownable {
    uint256 constant BPS = 10_000;
    uint256 public constant MAX_TOTAL_FEES = 1500; //15% max

    ERC20 public immutable kat;
    UnKat public immutable unKat;
    address public immutable unKatVaultImplementation;

    bool public isEnabled;
    Fees private fees;
    address[] private vaults;
    mapping(address => bool) public isVault;
    mapping(address => address) public userVault;
    mapping(address => bool) public authorizedReferral;

    /// @notice constructor
    /// @param _kat Address of the kat token
    /// @param _merklDistributor Address of the Merkl distributor
    /// @param _opsFee Initial ops fee share
    /// @param _referralFee  Initial referral fee share
    constructor(address _kat, address _merklDistributor, uint256 _opsFee, uint256 _referralFee) Ownable(msg.sender) {
        kat = ERC20(_kat);
        unKat = new UnKat(_kat);
        unKatVaultImplementation = address(new UnKatVault(kat, unKat, Distributor(_merklDistributor)));

        require(_opsFee + _referralFee <= MAX_TOTAL_FEES, "FeesToHigh");
        fees = Fees({opsFee: uint128(_opsFee), referralFee: uint128(_referralFee)});
    }

    /// @notice Deploy a vault for msg.sender, only one vault per sender
    /// @param _referral Address of the referral
    /// @return Address of the newly created vault
    function deployVault(address _referral) external returns (address) {
        require(isEnabled, "NotEnabled");
        require(authorizedReferral[_referral], "NonAuthorizedReferral");
        require(userVault[msg.sender] == address(0), "AlreadyHasVault");

        address vault = Clones.clone(unKatVaultImplementation);
        UnKatVault(vault).init(msg.sender, _referral);

        userVault[msg.sender] = vault;
        isVault[vault] = true;
        vaults.push(vault);

        return vault;
    }

    /// @notice Set authorized for a referral address
    /// @param _referral Address of the referral
    /// @param _isEnabled True to enable the referral address, otherwise false
    function setAuthorizedReferral(address _referral, bool _isEnabled) external onlyOwner {
        authorizedReferral[_referral] = _isEnabled;
    }

    /// @notice Set isEnabled, allows deploying new vaults and depositing into these vaults. Will be set to false when kat is unlocked to slowly wind down the protocol
    /// @param _isEnabled True to enable the vault deployments/deposits, otherwise false
    function setIsEnabled(bool _isEnabled) external onlyOwner {
        isEnabled = _isEnabled;
    }

    /// @notice Set the fees for the protocol, cannot be greater than 15% combined
    /// @param _opsFee Ops fee share
    /// @param _referralFee Referral fee share
    function setFees(uint256 _opsFee, uint256 _referralFee) external onlyOwner {
        require(_opsFee + _referralFee <= MAX_TOTAL_FEES, "FeesToHigh");
        fees = Fees({opsFee: uint128(_opsFee), referralFee: uint128(_referralFee)});
    }

    /// @notice Get the fees for the protocol
    /// @return Fees of the protocol
    function getFees() external view returns (Fees memory) {
        return fees;
    }

    /// @notice Get a slice of the vaults array
    /// @param indexStart Index to start from
    /// @param indexStop Index to stop at
    /// @return A slice of the vaults array
    function getVaults(uint256 indexStart, uint256 indexStop) external view returns (address[] memory) {
        address[] memory slice = new address[](indexStop - indexStart);
        for (uint256 i = 0; i < slice.length; i++) {
            slice[i] = vaults[indexStart + i];
        }

        return slice;
    }
}
