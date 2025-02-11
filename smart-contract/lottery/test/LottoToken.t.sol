// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {Test} from "forge-std/Test.sol";
import {LottoToken} from "../src/LottoToken.sol";
import {DeployLottoToken} from "../script/DeployLottoToken.s.sol";

contract LottoTokenTest is Test {
    LottoToken public lottoToken;
    address public owner = address(0x123);
    address public user1 = address(0x456);
    address public user2 = address(0x789);
    uint256 public initialSupply = 1_000_000 * 10 ** 18; // 1 million tokens

    function setUp() public {
        lottoToken = new DeployLottoToken().run(owner);
    }

    function test_Deployment() public {
        vm.prank(owner);
        assertEq(lottoToken.name(), "Lotto");
        assertEq(lottoToken.symbol(), "LOT");
        assertEq(lottoToken.decimals(), 18);
        assertEq(lottoToken.totalSupply(), initialSupply);
        assertEq(lottoToken.balanceOf(owner), initialSupply);
    }

    function test_Transfer() public {
        uint256 transferAmount = 100 * 10 ** 18;

        vm.prank(owner);
        lottoToken.transfer(user1, transferAmount);

        assertEq(lottoToken.balanceOf(owner), initialSupply - transferAmount);
        assertEq(lottoToken.balanceOf(user1), transferAmount);
    }

    function test_Transfer_InsufficientBalance() public {
        uint256 transferAmount = initialSupply + 1;

        vm.prank(owner);
        vm.expectRevert();
        lottoToken.transfer(user1, transferAmount);
    }

    function test_ApproveAndTransferFrom() public {
        uint256 approveAmount = 200 * 10 ** 18;
        uint256 transferAmount = 100 * 10 ** 18;

        vm.prank(owner);
        lottoToken.approve(user1, approveAmount);

        assertEq(lottoToken.allowance(owner, user1), approveAmount);

        vm.prank(user1);
        lottoToken.transferFrom(owner, user2, transferAmount);

        assertEq(lottoToken.balanceOf(owner), initialSupply - transferAmount);
        assertEq(lottoToken.balanceOf(user2), transferAmount);
        assertEq(lottoToken.allowance(owner, user1), approveAmount - transferAmount);
    }

    function test_TransferFrom_InsufficientAllowance() public {
        uint256 approveAmount = 100 * 10 ** 18;
        uint256 transferAmount = 200 * 10 ** 18;

        vm.prank(owner);
        lottoToken.approve(user1, approveAmount);

        vm.prank(user1);
        vm.expectRevert();
        lottoToken.transferFrom(owner, user2, transferAmount);
    }

    function test_TransferFrom_InsufficientBalance() public {
        uint256 approveAmount = initialSupply + 1;
        uint256 transferAmount = initialSupply + 1;

        vm.prank(owner);
        lottoToken.approve(user1, approveAmount);

        vm.prank(user1);
        vm.expectRevert();
        lottoToken.transferFrom(owner, user2, transferAmount);
    }
}
