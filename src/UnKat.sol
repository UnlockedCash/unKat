// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {UnKatFactory, Fees} from "./UnKatFactory.sol";
import {UnKatVault} from "./UnKatVault.sol";

contract UnKat is ERC20 {
    uint256 constant BPS = 10_000;
    UnKatFactory public immutable factory;
    ERC20 public immutable kat;

    /// @notice constructor
    /// @param _kat Address of the official kat token
    constructor(address _kat) ERC20("unlocked Kat", "unKat") {
        factory = UnKatFactory(msg.sender);
        kat = ERC20(_kat);
    }

    /// @notice Mint unKat while kat is locked minus the factory fee, only callable by a valid vault
    /// @param receiver Address receiving the unKat tokens
    /// @param amount Amount of unKat tokens to mint
    function mint(address receiver, uint256 amount) external {
        require(factory.isVault(msg.sender), "onlyVaultCanMint");

        Fees memory fees = factory.getFees();
        uint256 opsFeeAmount = amount * fees.opsFee / BPS;
        uint256 referralFeeAmount = amount * fees.referralFee / BPS;

        _mint(factory.owner(), opsFeeAmount);
        _mint(UnKatVault(msg.sender).referral(), referralFeeAmount);
        _mint(receiver, amount - opsFeeAmount - referralFeeAmount);
    }

    /// @notice Redeem unKat for kat tokens 1-1, callable by anyone
    /// @param receiver Address receiving the kat tokens
    /// @param amount Amount of unKat tokens to redeem
    function redeem(address receiver, uint256 amount) external {
        _burn(msg.sender, amount);
        kat.transfer(receiver, amount);
    }
}
