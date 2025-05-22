// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {UnKatFactory} from "./unKatFactory.sol";

contract UnKat is ERC20 {

    uint256 constant BPS = 10_000;
    UnKatFactory immutable factory;
    ERC20 immutable kat;
    
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

        uint256 fee = factory.fee();
        uint256 feeAmount = amount * fee / BPS;

        _mint(receiver, amount - feeAmount);
        _mint(factory.owner(), feeAmount);
    }

    /// @notice Redeem unKat for kat tokens 1-1, callable by anyone
    /// @param receiver Address receiving the kat tokens
    /// @param amount Amount of unKat tokens to redeem
    function redeem(address receiver, uint256 amount) external {
        _burn(msg.sender, amount);
        kat.transfer(receiver, amount);
    }
}
