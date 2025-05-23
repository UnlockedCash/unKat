// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Initializable} from "@openzeppelin/contracts/proxy/utils/Initializable.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {ERC721} from "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import {ERC721Holder} from "@openzeppelin/contracts/token/ERC721/utils/ERC721Holder.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {Distributor} from "merkl-contracts/contracts/Distributor.sol";

import {UnKat} from "./UnKat.sol";
import {UnKatFactory} from "./UnKatFactory.sol";

contract UnKatVault is Initializable, Ownable, ERC721Holder {
    using SafeERC20 for ERC20;

    ERC20 public immutable kat;
    UnKat public immutable unKat;
    Distributor public immutable merklDistributor;
    UnKatFactory public immutable factory;

    address public referral;
    uint256 public unKatMinted;

    /// @notice implementation constructor
    /// @param _kat Kat token address
    /// @param _unKat UnKat token address
    /// @param _merklDistributor Merkl Distributor address
    constructor(ERC20 _kat, UnKat _unKat, Distributor _merklDistributor) Ownable(msg.sender) {
        _disableInitializers();
        kat = _kat;
        unKat = _unKat;
        merklDistributor = _merklDistributor;
        factory = UnKatFactory(msg.sender);
    }

    /// @notice Init the vault clone
    /// @param _owner Owner of the vault
    /// @param _referral Referral address
    function init(address _owner, address _referral) external initializer {
        _transferOwnership(_owner);
        referral = _referral;
    }

    /// @notice Deposit an ERC20 in the vault
    /// @param token Address of the token
    /// @param amount Amount of tokens to deposit
    function depositERC20(ERC20 token, uint256 amount) external {
        require(factory.isEnabled(), "NotEnabled");
        token.safeTransferFrom(msg.sender, address(this), amount);
    }

    /// @notice Deposit an ERC721/NFT in the vault
    /// @param token Address of the NFT
    /// @param tokenId Id of the NFT to deposit
    function depositERC721(ERC721 token, uint256 tokenId) external {
        require(factory.isEnabled(), "NotEnabled");
        token.safeTransferFrom(msg.sender, address(this), tokenId);
    }

    /// @notice Withdraw an ERC20 from the vault
    /// @param token Address of the token
    /// @param receiver Address receiving the tokens
    /// @param amount Amount of tokens to withdraw
    function withdrawERC20(ERC20 token, address receiver, uint256 amount) external onlyOwner {
        token.safeTransfer(receiver, amount);
    }

    /// @notice Withdraw an ERC721/NFT from the vault
    /// @param token Address of the NFT
    /// @param receiver Address receiving the NFT
    /// @param tokenId Id of the NFT to withdraw
    function withdrawERC721(ERC721 token, address receiver, uint256 tokenId) external onlyOwner {
        token.safeTransferFrom(address(this), receiver, tokenId);
    }

    /// @notice Mint unKat according to kat owned by the vault on the Merkl distributor
    /// @param receiver Address receiving the unKat tokens
    /// @param amount Amount of kat owned by the vault on the Merkl distributor
    /// @param proofs Merkle proofs to validate the kat amount Owned
    function mintUnKatReward(address receiver, uint256 amount, bytes32[] calldata proofs) external onlyOwner {
        require(amount > 0.1e18, "KatAmountTooSmall"); //allow claiming only once accumulated over 0.1 kat to protect against dust vaults that may not be worth claiming and result in unbacked unKat
        require(block.timestamp > merklDistributor.endOfDisputePeriod(), "Dispute period");

        bytes32 leaf = keccak256(abi.encode(address(this), kat, amount));
        require(_verifyProof(leaf, proofs), "InvalidProofs");

        uint256 newUnKatToMint = amount - unKatMinted;
        unKatMinted = amount;

        unKat.mint(receiver, newUnKatToMint);
    }

    /// @notice Claim kat from the Merkl Distributor once it gets unlocked by the DAO/after 6 months
    /// @param amount Amount of Kat tokens owned by the vault on the Merkl distributor
    /// @param proofs Merkle proofs to validate the kat amount Owned
    function claimKatFromMerkl(uint256 amount, bytes32[][] calldata proofs) external {
        address[] memory users_ = new address[](1);
        users_[0] = address(this);
        address[] memory tokens_ = new address[](1);
        tokens_[0] = address(kat);
        uint256[] memory amounts_ = new uint256[](1);
        amounts_[0] = amount;
        merklDistributor.claim(users_, tokens_, amounts_, proofs);

        uint256 balance = kat.balanceOf(address(this));
        kat.safeTransfer(address(unKat), balance);
    }

    /// @notice Claim any other token than kat that may have been rewarded to the vault on the Merkl distributor
    /// @param receiver Address to send the rewards to
    /// @param amount Amount of tokens to claim
    /// @param token Address of the token to claim
    /// @param proofs Merkle proofs to validate the token amount Owned
    function claimOtherRewardFromMerkl(address receiver, uint256 amount, address token, bytes32[][] calldata proofs)
        external
        onlyOwner
    {
        require(token != address(kat), "InvalidToken");

        address[] memory users_ = new address[](1);
        users_[0] = address(this);
        address[] memory tokens_ = new address[](1);
        tokens_[0] = token;
        uint256[] memory amounts_ = new uint256[](1);
        amounts_[0] = amount;

        uint256 prevBalance = ERC20(token).balanceOf(address(this));

        merklDistributor.claim(users_, tokens_, amounts_, proofs);

        uint256 received = ERC20(token).balanceOf(address(this)) - prevBalance; //only send received in case reward token is same as token farming kat rewards
        ERC20(token).safeTransfer(receiver, received);
    }

    /// @notice Multicall function to allow user to use the vault as a normal wallet as long as it doesn't interact with kat, unKat and Merkl distributor contracts, useful for:
    /// - updating univ3 positions
    /// - withdrawing multiple tokens at once
    /// - claiming rewards on a different protocol than Merkl
    /// @param targets Addresses to be called
    /// @param data Data to pass on each call
    function multiCall(address[] calldata targets, bytes[] calldata data) external onlyOwner {
        require(targets.length == data.length, "target length != data length");

        bytes[] memory results = new bytes[](data.length);

        for (uint256 i; i < targets.length; i++) {
            require(
                targets[i] != address(merklDistributor) && targets[i] != address(unKat) && targets[i] != address(kat)
                    && targets[i] != address(factory) && targets[i] != address(this),
                "InvalidTarget"
            );
            (bool success, bytes memory result) = targets[i].call(data[i]);
            require(success, "CallFailed");
            results[i] = result;
        }
    }

    ///@notice Verify the proofs and amount with the Merkl distributor root
    /// @param leaf Leaf compute from the user address, amount and token to use for root computation
    /// @param proof Proofs to use with the leaf to compute the root
    /// @return Return true if valid leaf, otherwise false
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
        bytes32 root = merklDistributor.getMerkleRoot();
        require(root != bytes32(0));
        return currentHash == root;
    }
}
