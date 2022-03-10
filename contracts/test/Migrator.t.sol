// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity 0.8.7;

import { IERC20 } from "../../modules/erc20/contracts/interfaces/IERC20.sol";

import { TestUtils } from "../../modules/contract-test-utils/contracts/test.sol";
import { MockERC20 } from "../../modules/erc20/contracts/test/mocks/MockERC20.sol";

import { Migrator } from "../Migrator.sol";

contract SomeAccount {

    function approve(address token_, address spender_, uint256 amount_) external {
        IERC20(token_).approve(spender_, amount_);
    }

}

contract MigratorConstructorTest is TestUtils {

    function test_constructor_mismatch_decimals() external {
        MockERC20 oldToken = new MockERC20("Old Token", "OT", 18);
        MockERC20 newToken = new MockERC20("New Token", "NT", 17);

        vm.expectRevert("M:C:DECIMAL_MISMATCH");
        new Migrator(address(oldToken), address(newToken));
    }

    function test_constructor() external {
        MockERC20 oldToken = new MockERC20("Old Token", "OT", 18);
        MockERC20 newToken = new MockERC20("New Token", "NT", 18);

        Migrator migrator = new Migrator(address(oldToken), address(newToken));

        assertEq(migrator.oldToken(), address(oldToken));
        assertEq(migrator.newToken(), address(newToken));
    }

}

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

    function test_migrate_zeroAmount() external {
        uint256 amount_ = 0;

        vm.expectRevert("M:M:ZERO_AMOUNT");
        migrator.migrate(amount_);

        amount_ = 1;

        oldToken.mint(address(this), amount_);
        oldToken.approve(address(migrator), amount_);

        migrator.migrate(amount_);

        assertEq(oldToken.allowance(address(this), address(migrator)), 0);

        assertEq(oldToken.balanceOf(address(this)),     0);
        assertEq(oldToken.balanceOf(address(migrator)), amount_);
        assertEq(newToken.balanceOf(address(this)),     amount_);
        assertEq(newToken.balanceOf(address(migrator)), OLD_SUPPLY - amount_);
    }

    function test_migrate_insufficientApproval(uint256 amount_) external {
        amount_ = constrictToRange(amount_, 1, OLD_SUPPLY);

        // Mint amount of old token
        oldToken.mint(address(this), amount_);

        oldToken.approve(address(migrator), amount_ - 1);

        vm.expectRevert("M:M:TRANSFER_FROM_FAILED");
        migrator.migrate(amount_);

        // Approve
        oldToken.approve(address(migrator), amount_);

        migrator.migrate(amount_);

        assertEq(oldToken.allowance(address(this), address(migrator)), 0);

        assertEq(oldToken.balanceOf(address(this)),     0);
        assertEq(oldToken.balanceOf(address(migrator)), amount_);
        assertEq(newToken.balanceOf(address(this)),     amount_);
        assertEq(newToken.balanceOf(address(migrator)), OLD_SUPPLY - amount_);
    }

    function test_migrate_insufficientBalance(uint256 amount_) external {
        amount_ = constrictToRange(amount_, 1, OLD_SUPPLY);

        oldToken.mint(address(this), amount_ - 1);

        oldToken.approve(address(migrator), amount_);

        vm.expectRevert("M:M:TRANSFER_FROM_FAILED");
        migrator.migrate(amount_);

        // Mint
        oldToken.mint(address(this), 1);

        migrator.migrate(amount_);

        assertEq(oldToken.allowance(address(this), address(migrator)), 0);

        assertEq(oldToken.balanceOf(address(this)),     0);
        assertEq(oldToken.balanceOf(address(migrator)), amount_);
        assertEq(newToken.balanceOf(address(this)),     amount_);
        assertEq(newToken.balanceOf(address(migrator)), OLD_SUPPLY - amount_);
    }

    function test_migrate_newTokenInsufficientBalance(uint256 amount_) external {
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

        assertEq(oldToken.allowance(address(this), address(migrator)), 0);

        assertEq(oldToken.balanceOf(address(this)),     0);
        assertEq(oldToken.balanceOf(address(migrator)), amount_);
        assertEq(newToken.balanceOf(address(this)),     amount_);
        assertEq(newToken.balanceOf(address(migrator)), 0);
    }

    function test_migrate_success(uint256 amount_) external {
        amount_ = constrictToRange(amount_, 1, OLD_SUPPLY);

        // Mint amount of old token
        oldToken.mint(address(this), amount_);

        // Approve
        oldToken.approve(address(migrator), amount_);

        assertEq(oldToken.allowance(address(this), address(migrator)), amount_);

        assertEq(oldToken.balanceOf(address(this)),     amount_);
        assertEq(oldToken.balanceOf(address(migrator)), 0);
        assertEq(newToken.balanceOf(address(this)),     0);
        assertEq(newToken.balanceOf(address(migrator)), OLD_SUPPLY);

        migrator.migrate(amount_);

        assertEq(oldToken.allowance(address(this), address(migrator)), 0);

        assertEq(oldToken.balanceOf(address(this)),     0);
        assertEq(oldToken.balanceOf(address(migrator)), amount_);
        assertEq(newToken.balanceOf(address(this)),     amount_);
        assertEq(newToken.balanceOf(address(migrator)), OLD_SUPPLY - amount_);
    }

    function test_migration_specifiedOwner(uint256 amount_) external {
        amount_ = constrictToRange(amount_, 1, OLD_SUPPLY);

        SomeAccount someAccount = new SomeAccount();

        // Mint amount of old token
        oldToken.mint(address(someAccount), amount_);

        // Approve
        someAccount.approve(address(oldToken), address(migrator), amount_);

        assertEq(oldToken.allowance(address(someAccount), address(migrator)), amount_);

        assertEq(oldToken.balanceOf(address(someAccount)), amount_);
        assertEq(oldToken.balanceOf(address(migrator)),    0);
        assertEq(newToken.balanceOf(address(someAccount)), 0);
        assertEq(newToken.balanceOf(address(migrator)),    OLD_SUPPLY);

        migrator.migrate(address(someAccount), amount_);

        assertEq(oldToken.allowance(address(someAccount), address(migrator)), 0);

        assertEq(oldToken.balanceOf(address(someAccount)), 0);
        assertEq(oldToken.balanceOf(address(migrator)),    amount_);
        assertEq(newToken.balanceOf(address(someAccount)), amount_);
        assertEq(newToken.balanceOf(address(migrator)),    OLD_SUPPLY - amount_);
    }

    function test_migrate_partialMigration(uint256 amount_, uint256 partialAmount_) external {
        amount_        = constrictToRange(amount_,        2, OLD_SUPPLY);
        partialAmount_ = constrictToRange(partialAmount_, 1, amount_ - 1);

        // Mint amount of old token
        oldToken.mint(address(this), amount_);

        // Approve partial
        oldToken.approve(address(migrator), partialAmount_);

        assertEq(oldToken.allowance(address(this), address(migrator)), partialAmount_);

        assertEq(oldToken.balanceOf(address(this)),     amount_);
        assertEq(oldToken.balanceOf(address(migrator)), 0);
        assertEq(newToken.balanceOf(address(this)),     0);
        assertEq(newToken.balanceOf(address(migrator)), OLD_SUPPLY);

        migrator.migrate(partialAmount_);

        assertEq(oldToken.allowance(address(this), address(migrator)), 0);

        assertEq(oldToken.balanceOf(address(this)),     amount_ - partialAmount_);
        assertEq(oldToken.balanceOf(address(migrator)), partialAmount_);
        assertEq(newToken.balanceOf(address(this)),     partialAmount_);
        assertEq(newToken.balanceOf(address(migrator)), OLD_SUPPLY - partialAmount_);

        uint256 remaining = amount_ - partialAmount_;

        oldToken.approve(address(migrator), remaining);

        migrator.migrate(remaining);

        assertEq(oldToken.allowance(address(this), address(migrator)), 0);

        assertEq(oldToken.balanceOf(address(this)),     0);
        assertEq(oldToken.balanceOf(address(migrator)), amount_);
        assertEq(newToken.balanceOf(address(this)),     amount_);
        assertEq(newToken.balanceOf(address(migrator)), OLD_SUPPLY - amount_);
    }

}
