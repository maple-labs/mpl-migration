// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity 0.8.7;

import { TestUtils } from "../../modules/contract-test-utils/contracts/test.sol";

import { MockERC20 } from "../../modules/erc20/contracts/test/mocks/MockERC20.sol";

import { Migrator } from "../Migrator.sol";

contract MigratorTest is TestUtils {

    uint256 public constant OLD_SUPPLY = 10_000_000 ether;

    Migrator  migrator;
    MockERC20 oldToken;
    MockERC20 newToken;

    function setUp() external {
        oldToken = new MockERC20("Old Token", "OT", 18);
        newToken = new MockERC20("New Token", "NT", 18);

        migrator = new Migrator(address(oldToken), address(newToken));

        // Mint new token to migrator
        newToken.mint(address(migrator), OLD_SUPPLY);
    }

    function test_migration(uint256 amount_) external {
        amount_ = constrictToRange(amount_, 1, OLD_SUPPLY);

        // Mint amount of old token
        oldToken.mint(address(this), amount_);

        // Approve
        oldToken.approve(address(migrator), amount_);

        assertEq(oldToken.balanceOf(address(this)),     amount_);
        assertEq(oldToken.balanceOf(address(migrator)), 0);
        assertEq(oldToken.allowance(address(this),      address(migrator)), amount_);
        assertEq(newToken.balanceOf(address(this)),     0);
        assertEq(newToken.balanceOf(address(migrator)), OLD_SUPPLY);

        migrator.migrate(amount_);

        assertEq(oldToken.balanceOf(address(this)),     0);
        assertEq(oldToken.balanceOf(address(migrator)), amount_);
        assertEq(oldToken.allowance(address(this),      address(migrator)), 0);
        assertEq(newToken.balanceOf(address(this)),     amount_);
        assertEq(newToken.balanceOf(address(migrator)), OLD_SUPPLY - amount_);
    }

    function test_partialMigration(uint256 amount_, uint256 partialAmount_) external {
        amount_        = constrictToRange(amount_,        2, OLD_SUPPLY);
        partialAmount_ = constrictToRange(partialAmount_, 1, amount_ - 1);

        // Mint amount of old token
        oldToken.mint(address(this), amount_);

        // Approve partial
        oldToken.approve(address(migrator), partialAmount_);

        assertEq(oldToken.balanceOf(address(this)),     amount_);
        assertEq(oldToken.balanceOf(address(migrator)), 0);
        assertEq(oldToken.allowance(address(this),      address(migrator)), partialAmount_);
        assertEq(newToken.balanceOf(address(this)),     0);
        assertEq(newToken.balanceOf(address(migrator)), OLD_SUPPLY);

        migrator.migrate(partialAmount_);

        assertEq(oldToken.balanceOf(address(this)),     amount_ - partialAmount_);
        assertEq(oldToken.balanceOf(address(migrator)), partialAmount_);
        assertEq(oldToken.allowance(address(this),      address(migrator)), 0);
        assertEq(newToken.balanceOf(address(this)),     partialAmount_);
        assertEq(newToken.balanceOf(address(migrator)), OLD_SUPPLY - partialAmount_);

        uint256 remaining = amount_ - partialAmount_;

        oldToken.approve(address(migrator), remaining);

        migrator.migrate(remaining);

        assertEq(oldToken.balanceOf(address(this)),     0);
        assertEq(oldToken.balanceOf(address(migrator)), amount_);
        assertEq(oldToken.allowance(address(this),      address(migrator)), 0);
        assertEq(newToken.balanceOf(address(this)),     amount_);
        assertEq(newToken.balanceOf(address(migrator)), OLD_SUPPLY - amount_);
    }

    function test_zeroAmount() external {
        uint256 amount_ = 0;

        vm.expectRevert("M:M:ZERO_AMOUNT");
        migrator.migrate(amount_);

        amount_ = 1;

        oldToken.mint(address(this), amount_);
        oldToken.approve(address(migrator), amount_);

        migrator.migrate(amount_);

        assertEq(oldToken.balanceOf(address(this)),     0);
        assertEq(oldToken.balanceOf(address(migrator)), amount_);
        assertEq(oldToken.allowance(address(this),      address(migrator)), 0);
        assertEq(newToken.balanceOf(address(this)),     amount_);
        assertEq(newToken.balanceOf(address(migrator)), OLD_SUPPLY - amount_);
    }

    function test_failWithoutApprove(uint256 amount_) external {
        amount_ = constrictToRange(amount_, 1, OLD_SUPPLY);

        // Mint amount of old token
        oldToken.mint(address(this), amount_);

        vm.expectRevert("M:M:TRANSFER_FROM_FAILED");
        migrator.migrate(amount_);

        // Approve
        oldToken.approve(address(migrator), amount_);

        migrator.migrate(amount_);

        assertEq(oldToken.balanceOf(address(this)),     0);
        assertEq(oldToken.balanceOf(address(migrator)), amount_);
        assertEq(oldToken.allowance(address(this),      address(migrator)), 0);
        assertEq(newToken.balanceOf(address(this)),     amount_);
        assertEq(newToken.balanceOf(address(migrator)), OLD_SUPPLY - amount_);
    }

    function test_failWithoutBalance(uint256 amount_) external {
        amount_ = constrictToRange(amount_, 1, OLD_SUPPLY);

        oldToken.mint(address(this), amount_ - 1);

        oldToken.approve(address(migrator), amount_);

        vm.expectRevert("M:M:TRANSFER_FROM_FAILED");
        migrator.migrate(amount_);

        // Mint
        oldToken.mint(address(this), 1);

        migrator.migrate(amount_);

        assertEq(oldToken.balanceOf(address(this)),     0);
        assertEq(oldToken.balanceOf(address(migrator)), amount_);
        assertEq(oldToken.allowance(address(this),      address(migrator)), 0);
        assertEq(newToken.balanceOf(address(this)),     amount_);
        assertEq(newToken.balanceOf(address(migrator)), OLD_SUPPLY - amount_);
    }

    function test_failWithoutNewToken(uint256 amount_) external {
        amount_ = constrictToRange(amount_, 1, OLD_SUPPLY);

        // Burn new supply that was added in setUp
        newToken.burn(address(migrator), OLD_SUPPLY - amount_ + 1);

        // Mint amount of old token
        oldToken.mint(address(this), amount_);

        // Approve
        oldToken.approve(address(migrator), amount_);

        vm.expectRevert("M:M:TRANSFER_FAILED");
        migrator.migrate(amount_);

        newToken.mint(address(migrator), 1);

        migrator.migrate(amount_);

        assertEq(oldToken.balanceOf(address(this)),     0);
        assertEq(oldToken.balanceOf(address(migrator)), amount_);
        assertEq(oldToken.allowance(address(this),      address(migrator)), 0);
        assertEq(newToken.balanceOf(address(this)),     amount_);
        assertEq(newToken.balanceOf(address(migrator)), 0);
    }

}
