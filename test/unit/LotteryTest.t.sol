// SPDX-License-Identifier: MIT

pragma solidity ^0.8.19;

import {DeployLottery} from "../../script/DeployLottery.s.sol";
import {HelperConfig} from "../../script/HelperConfig.s.sol";
import {Test, console} from "forge-std/Test.sol";
import {Lottery} from "../../src/Lottery.sol";

contract LotteryTest is Test {
    Lottery public lottery;

    function setUp() external {
        DeployLottery deployer = new DeployLottery();
        lottery = deployer.run();
    }

    function testRaffleInitializesInOpenState() public view {
        assert(lottery.getRaffleState() == Lottery.Status.ONGOING);
    }
}
