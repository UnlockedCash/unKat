// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Test, console} from "forge-std/Test.sol";

import {MockKat} from "./mocks/MockKat.sol";
import {MockDistributor} from "./mocks/MockDistributor.sol";

import {UnKat} from "./../src/UnKat.sol";
import {UnKatVault} from "./../src/UnKatVault.sol";
import {UnKatFactory} from "./../src/UnKatFactory.sol";

contract UnKatTest is Test {
    uint256 constant INIT_OPS_FEE = 900;
    uint256 constant INIT_REF_FEE = 100;

    MockKat kat;
    MockDistributor distributor;
    UnKat unKat;
    UnKatFactory factory;

    function setUp() public {
        kat = new MockKat();
        distributor = new MockDistributor();

        factory = new UnKatFactory(address(kat), address(distributor), INIT_OPS_FEE, INIT_REF_FEE);
        unKat = factory.unKat();
    }

    function testEmpty() public {}
}
