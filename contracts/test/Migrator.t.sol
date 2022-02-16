// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity 0.8.7;

import { TestUtils } from "../../modules/contract-test-utils/contracts/test.sol";

import { MockERC20 } from "../../modules/erc20/src/test/mocks/MockERC20.sol";

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
    }

    function test_migration(uint256 amount_) external {
        amount_ = constrictToRange(amount_, 1, OLD_SUPPLY);

        //Mint new token to migrator
        newToken.mint(address(migrator), OLD_SUPPLY);

        // Mint amount of old token
        oldToken.mint(address(this), amount_);

        // Approve
        oldToken.approve(address(migrator), amount_);

        migrator.migrate(amount_);

        assertEq(oldToken.balanceOf(address(this)),     0);
        assertEq(oldToken.balanceOf(address(migrator)), amount_);
        assertEq(oldToken.allowance(address(this),      address(migrator)), 0);
        assertEq(newToken.balanceOf(address(this)),     amount_);
        assertEq(newToken.balanceOf(address(migrator)), OLD_SUPPLY - amount_);
    }

    function test_partialMigration(uint256 amount_, uint256 partialAmount_) external {
        amount_        = constrictToRange(amount_,        3, OLD_SUPPLY);
        partialAmount_ = constrictToRange(partialAmount_, 1, amount_ - 1);

        //Mint new token to migrator
        newToken.mint(address(migrator), OLD_SUPPLY);

        // Mint amount of old token
        oldToken.mint(address(this), amount_);

        // Approve partial
        oldToken.approve(address(migrator), partialAmount_);

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
        //Mint new token to migrator
        newToken.mint(address(migrator), OLD_SUPPLY);

        uint256 amount_ = 0;

         try migrator.migrate(amount_) { 
            assertTrue(false, "Able to migrate zero amount"); 
        } catch Error(string memory reason) {
            assertEq(reason, "M:M:ZERO_AMOUNT");
        }

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

        //Mint new token to migrator
        newToken.mint(address(migrator), OLD_SUPPLY);

        // Mint amount of old token
        oldToken.mint(address(this), amount_);

         try migrator.migrate(amount_) { 
            assertTrue(false, "Able to migrate without approve"); 
        } catch Error(string memory reason) {
            assertEq(reason, "M:M:TRANSFER_FROM_FAILED");
        }

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

        //Mint new token to migrator
        newToken.mint(address(migrator), OLD_SUPPLY);

        oldToken.approve(address(migrator), amount_);

        try migrator.migrate(amount_) { 
            assertTrue(false, "Able to migrate without balance"); 
        } catch Error(string memory reason) {
            assertEq(reason, "M:M:TRANSFER_FROM_FAILED");
        }

        // Mint
        oldToken.mint(address(this), amount_);

        migrator.migrate(amount_);

        assertEq(oldToken.balanceOf(address(this)),     0);
        assertEq(oldToken.balanceOf(address(migrator)), amount_);
        assertEq(oldToken.allowance(address(this),      address(migrator)), 0);
        assertEq(newToken.balanceOf(address(this)),     amount_);
        assertEq(newToken.balanceOf(address(migrator)), OLD_SUPPLY - amount_);
    }

    function test_failWithoutNewToken(uint256 amount_) external {
        amount_ = constrictToRange(amount_, 1, OLD_SUPPLY);
        
        // Mint amount of old token
        oldToken.mint(address(this), amount_);

        // Approve
        oldToken.approve(address(migrator), amount_);

        try migrator.migrate(amount_) { 
            assertTrue(false, "Able to migrate without new token"); 
        } catch Error(string memory reason) {
            assertEq(reason, "M:M:TRANSFER_FAILED");
        }

        //Mint new token to migrator
        newToken.mint(address(migrator), OLD_SUPPLY);

        migrator.migrate(amount_);

        assertEq(oldToken.balanceOf(address(this)),     0);
        assertEq(oldToken.balanceOf(address(migrator)), amount_);
        assertEq(oldToken.allowance(address(this),      address(migrator)), 0);
        assertEq(newToken.balanceOf(address(this)),     amount_);
        assertEq(newToken.balanceOf(address(migrator)), OLD_SUPPLY - amount_);
    }


    
}