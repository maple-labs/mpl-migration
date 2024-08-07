// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity 0.8.7;

import { Test } from "../modules/forge-std/src/Test.sol";

import { MockERC20 } from "../modules/erc20/contracts/test/mocks/MockERC20.sol";

import { Migrator } from "../contracts/Migrator.sol";

import { MockGlobals } from "./mocks/Mocks.sol";

contract MigratorConstructorTest is Test {

    function test_constructor_zeroScalar() external {
        vm.expectRevert("M:C:ZERO_SCALAR");
        new Migrator(address(0), address(0), address(0), 0);
    }

    function test_constructor_mismatch_decimals() external {
        MockGlobals globals = new MockGlobals();
        MockERC20 oldToken = new MockERC20("Old Token", "OT", 18);
        MockERC20 newToken = new MockERC20("New Token", "NT", 17);

        vm.expectRevert("M:C:DECIMAL_MISMATCH");
        new Migrator(address(globals), address(oldToken), address(newToken), 1);
    }

    function test_constructor() external {
        MockGlobals globals = new MockGlobals();
        MockERC20 oldToken  = new MockERC20("Old Token", "OT", 18);
        MockERC20 newToken  = new MockERC20("New Token", "NT", 18);

        Migrator migrator = new Migrator(address(globals), address(oldToken), address(newToken), 1);

        assertEq(migrator.globals(),          address(globals));
        assertEq(migrator.oldToken(),         address(oldToken));
        assertEq(migrator.newToken(),         address(newToken));
        assertEq(migrator.tokenSplitScalar(), 1);
    }

}

contract SetActiveTests is Test {

    uint256 internal constant SCALAR     = 10;
    uint256 internal constant OLD_SUPPLY = 10_000_000e18;

    address operationalAdmin = makeAddr("operationalAdmin");
    address governor         = makeAddr("governor");
    address account          = makeAddr("account");

    Migrator    internal _migrator;
    MockERC20   internal _oldToken;
    MockERC20   internal _newToken;
    MockGlobals internal _globals;

    function setUp() external {
        _globals = new MockGlobals();

        _globals.__setGovernor(governor);
        _globals.__setOperationalAdmin(operationalAdmin);

        _oldToken = new MockERC20("Old Token", "OT", 18);
        _newToken = new MockERC20("New Token", "NT", 18);

        _migrator = new Migrator(address(_globals), address(_oldToken), address(_newToken), SCALAR);
    }

    function test_setActive_notProtocolAdmin() external {
        vm.expectRevert("M:SA:NOT_PROTOCOL_ADMIN");
        _migrator.setActive(false);
    }

    function test_setActive_withGovernor() external {
        assertEq(_migrator.active(), false);

        vm.prank(governor);
        _migrator.setActive(true);

        assertEq(_migrator.active(), true);

        vm.prank(governor);
        _migrator.setActive(false);

        assertEq(_migrator.active(), false);
    }

    function test_setActive_withOperationalAdmin() external {
        assertEq(_migrator.active(), false);

        vm.prank(operationalAdmin);
        _migrator.setActive(true);

        assertEq(_migrator.active(), true);

        vm.prank(operationalAdmin);
        _migrator.setActive(false);

        assertEq(_migrator.active(), false);
    }

}

contract MigratorTest is Test {

    uint256 internal constant SCALAR     = 10;
    uint256 internal constant OLD_SUPPLY = 10_000_000e18;

    address account          = makeAddr("account");
    address operationalAdmin = makeAddr("operationalAdmin");
    address recipient        = makeAddr("recipient");
    address sender           = makeAddr("sender");

    uint256 amount = 100e18;

    Migrator    internal _migrator;
    MockERC20   internal _oldToken;
    MockERC20   internal _newToken;
    MockGlobals internal _globals;

    function setUp() external {
        _globals = new MockGlobals();

        _oldToken = new MockERC20("Old Token", "OT", 18);
        _newToken = new MockERC20("New Token", "NT", 18);

        _migrator = new Migrator(address(_globals), address(_oldToken), address(_newToken), SCALAR);

        _globals.__setOperationalAdmin(operationalAdmin);

        vm.prank(operationalAdmin);
        _migrator.setActive(true);

        // Mint new token to migrator
        _newToken.mint(address(_migrator), OLD_SUPPLY * SCALAR);
    }

    function test_migrate_zeroAmount() external {
        vm.expectRevert("M:M:ZERO_AMOUNT");
        _migrator.migrate(0);

        _oldToken.mint(address(this), 1);
        _oldToken.approve(address(_migrator), 1);

        _migrator.migrate(1);

        uint256 newAmount = 1 * SCALAR;

        assertEq(_oldToken.allowance(address(this), address(_migrator)), 0);

        assertEq(_oldToken.balanceOf(address(this)),      0);
        assertEq(_oldToken.balanceOf(address(_migrator)), 1);
        assertEq(_newToken.balanceOf(address(this)),      newAmount);
        assertEq(_newToken.balanceOf(address(_migrator)), (OLD_SUPPLY * SCALAR)- newAmount);
    }

    function test_migrate_inactive() external {
        vm.prank(operationalAdmin);
        _migrator.setActive(false);

        vm.expectRevert("M:M:INACTIVE");
        _migrator.migrate(1);
    }

    function test_migrate_recipient() external {
        _oldToken.mint(address(sender), amount);

        vm.prank(sender);
        _oldToken.approve(address(_migrator), amount);

        assertEq(_oldToken.balanceOf(address(sender)),    amount);
        assertEq(_oldToken.balanceOf(address(_migrator)), 0);
        assertEq(_oldToken.balanceOf(address(recipient)), 0);

        assertEq(_newToken.balanceOf(address(sender)),    0);
        assertEq(_newToken.balanceOf(address(_migrator)), OLD_SUPPLY * SCALAR);
        assertEq(_newToken.balanceOf(address(recipient)), 0);

        vm.prank(sender);
        _migrator.migrate(address(recipient), amount);

        assertEq(_oldToken.balanceOf(address(sender)),    0);
        assertEq(_oldToken.balanceOf(address(_migrator)), amount);
        assertEq(_oldToken.balanceOf(address(recipient)), 0);

        assertEq(_newToken.balanceOf(address(sender)),    0);
        assertEq(_newToken.balanceOf(address(_migrator)), (OLD_SUPPLY - amount) * SCALAR);
        assertEq(_newToken.balanceOf(address(recipient)), amount * SCALAR);
    }

    function testFuzz_migrate_insufficientApproval(uint256 amount_) external {
        amount_ = bound(amount_, 1, OLD_SUPPLY);

        uint256 newTokenAmount = amount_ * SCALAR;

        // Mint amount of old token
        _oldToken.mint(address(this), amount_);

        _oldToken.approve(address(_migrator), amount_ - 1);

        vm.expectRevert("M:M:TRANSFER_FROM_FAILED");
        _migrator.migrate(amount_);

        // Approve
        _oldToken.approve(address(_migrator), amount_);

        _migrator.migrate(amount_);

        assertEq(_oldToken.allowance(address(this), address(_migrator)), 0);

        assertEq(_oldToken.balanceOf(address(this)),      0);
        assertEq(_oldToken.balanceOf(address(_migrator)), amount_);
        assertEq(_newToken.balanceOf(address(this)),      newTokenAmount);
        assertEq(_newToken.balanceOf(address(_migrator)), (OLD_SUPPLY * SCALAR) - newTokenAmount);
    }

    function testFuzz_migrate_insufficientBalance(uint256 amount_) external {
        amount_ = bound(amount_, 1, OLD_SUPPLY);

        _oldToken.mint(address(this), amount_ - 1);

        _oldToken.approve(address(_migrator), amount_);

        vm.expectRevert("M:M:TRANSFER_FROM_FAILED");
        _migrator.migrate(amount_);

        // Mint
        _oldToken.mint(address(this), 1);

        _migrator.migrate(amount_);

        uint256 newAmount = amount_ * SCALAR;

        assertEq(_oldToken.allowance(address(this), address(_migrator)), 0);

        assertEq(_oldToken.balanceOf(address(this)),      0);
        assertEq(_oldToken.balanceOf(address(_migrator)), amount_);
        assertEq(_newToken.balanceOf(address(this)),      newAmount);
        assertEq(_newToken.balanceOf(address(_migrator)), (OLD_SUPPLY * SCALAR) - newAmount);
    }

    function testFuzz_migrate_newTokenInsufficientBalance(uint256 amount_) external {
        amount_ = bound(amount_, 1, OLD_SUPPLY);

        uint256 newAmount = amount_ * SCALAR;

        // Burn new supply that was added in setUp
        _newToken.burn(address(_migrator), (OLD_SUPPLY * SCALAR) - newAmount + 1);

        // Mint amount of old token
        _oldToken.mint(address(this), amount_);

        // Approve
        _oldToken.approve(address(_migrator), amount_);

        vm.expectRevert("M:M:TRANSFER_FAILED");
        _migrator.migrate(amount_);

        _newToken.mint(address(_migrator), 1);

        _migrator.migrate(amount_);

        assertEq(_oldToken.allowance(address(this), address(_migrator)), 0);

        assertEq(_oldToken.balanceOf(address(this)),      0);
        assertEq(_oldToken.balanceOf(address(_migrator)), amount_);
        assertEq(_newToken.balanceOf(address(this)),      newAmount);
        assertEq(_newToken.balanceOf(address(_migrator)), 0);
    }

    function testFuzz_migrate_success(uint256 amount_) external {
        amount_ = bound(amount_, 1, OLD_SUPPLY);

        uint256 newAmount = amount_ * SCALAR;

        // Mint amount of old token
        _oldToken.mint(address(this), amount_);

        // Approve
        _oldToken.approve(address(_migrator), amount_);

        assertEq(_oldToken.allowance(address(this), address(_migrator)), amount_);

        assertEq(_oldToken.balanceOf(address(this)),      amount_);
        assertEq(_oldToken.balanceOf(address(_migrator)), 0);
        assertEq(_newToken.balanceOf(address(this)),      0);
        assertEq(_newToken.balanceOf(address(_migrator)), OLD_SUPPLY * SCALAR);

        _migrator.migrate(amount_);

        assertEq(_oldToken.allowance(address(this), address(_migrator)), 0);

        assertEq(_oldToken.balanceOf(address(this)),      0);
        assertEq(_oldToken.balanceOf(address(_migrator)), amount_);
        assertEq(_newToken.balanceOf(address(this)),      newAmount);
        assertEq(_newToken.balanceOf(address(_migrator)), (OLD_SUPPLY  * SCALAR) - newAmount);
    }

    function testFuzz_migration_specifiedRecipient(uint256 amount_) external {
        amount_ = bound(amount_, 1, OLD_SUPPLY);

        uint256 newAmount = amount_ * SCALAR;

        // Mint amount of old token
        _oldToken.mint(address(account), amount_);

        // Approve
        vm.prank(account);
        _oldToken.approve(address(_migrator), amount_);

        assertEq(_oldToken.allowance(address(account), address(_migrator)), amount_);

        assertEq(_oldToken.balanceOf(address(account)),   amount_);
        assertEq(_oldToken.balanceOf(address(_migrator)), 0);
        assertEq(_oldToken.balanceOf(address(recipient)), 0);

        assertEq(_newToken.balanceOf(address(account)),   0);
        assertEq(_newToken.balanceOf(address(_migrator)), OLD_SUPPLY * SCALAR);
        assertEq(_newToken.balanceOf(address(recipient)), 0);

        vm.prank(account);
        _migrator.migrate(address(recipient), amount_);

        assertEq(_oldToken.allowance(address(account), address(_migrator)), 0);

        assertEq(_oldToken.balanceOf(address(account)),   0);
        assertEq(_oldToken.balanceOf(address(_migrator)), amount_);
        assertEq(_oldToken.balanceOf(address(recipient)), 0);

        assertEq(_newToken.balanceOf(address(account)),   0);
        assertEq(_newToken.balanceOf(address(_migrator)), (OLD_SUPPLY * SCALAR) - newAmount);
        assertEq(_newToken.balanceOf(address(recipient)), newAmount);
    }

    function testFuzz_migrate_partialMigration(uint256 amount_, uint256 partialAmount_) external {
        amount_        = bound(amount_,        2, OLD_SUPPLY);
        partialAmount_ = bound(partialAmount_, 1, amount_ - 1);

        uint256 newAmount        = amount_ * SCALAR;
        uint256 newPartialAmount = partialAmount_ * SCALAR;

        // Mint amount of old token
        _oldToken.mint(address(this), amount_);

        // Approve partial
        _oldToken.approve(address(_migrator), partialAmount_);

        assertEq(_oldToken.allowance(address(this), address(_migrator)), partialAmount_);

        assertEq(_oldToken.balanceOf(address(this)),      amount_);
        assertEq(_oldToken.balanceOf(address(_migrator)), 0);
        assertEq(_newToken.balanceOf(address(this)),      0);
        assertEq(_newToken.balanceOf(address(_migrator)), OLD_SUPPLY * SCALAR);

        _migrator.migrate(partialAmount_);

        assertEq(_oldToken.allowance(address(this), address(_migrator)), 0);

        assertEq(_oldToken.balanceOf(address(this)),      amount_ - partialAmount_);
        assertEq(_oldToken.balanceOf(address(_migrator)), partialAmount_);
        assertEq(_newToken.balanceOf(address(this)),      newPartialAmount);
        assertEq(_newToken.balanceOf(address(_migrator)), (OLD_SUPPLY * SCALAR) - newPartialAmount);

        uint256 remaining = amount_ - partialAmount_;

        _oldToken.approve(address(_migrator), remaining);

        _migrator.migrate(remaining);

        assertEq(_oldToken.allowance(address(this), address(_migrator)), 0);

        assertEq(_oldToken.balanceOf(address(this)),      0);
        assertEq(_oldToken.balanceOf(address(_migrator)), amount_);
        assertEq(_newToken.balanceOf(address(this)),      newAmount);
        assertEq(_newToken.balanceOf(address(_migrator)), (OLD_SUPPLY * SCALAR)- newAmount);
    }

}

contract TokenSplitScalars is Test {

    uint256 internal constant OLD_SUPPLY = 10_000_000e18;

    address operationalAdmin = makeAddr("operationalAdmin");
    address account          = makeAddr("account");

    Migrator  internal _migrator;
    MockERC20 internal _oldToken;
    MockERC20 internal _newToken;
    MockGlobals internal _globals;

    function setUp() external {
        _globals = new MockGlobals();

        _oldToken = new MockERC20("Old Token", "OT", 18);
        _newToken = new MockERC20("New Token", "NT", 18);

        _globals.__setOperationalAdmin(operationalAdmin);
    }

    function testFuzz_tokenSplitScalar(uint256 amount_, uint16 scalar_) external {
        vm.assume(scalar_ > 0);
        amount_ = bound(amount_, 1, OLD_SUPPLY);

        uint256 newAmount = amount_ * scalar_;

        _migrator = new Migrator(address(_globals), address(_oldToken), address(_newToken), scalar_);

        vm.prank(operationalAdmin);
        _migrator.setActive(true);

        _newToken.mint(address(_migrator), OLD_SUPPLY * scalar_);

        _oldToken.mint(address(this), amount_);

        // Approve
        _oldToken.approve(address(_migrator), amount_);

        assertEq(_oldToken.allowance(address(this), address(_migrator)), amount_);

        assertEq(_oldToken.balanceOf(address(this)),      amount_);
        assertEq(_oldToken.balanceOf(address(_migrator)), 0);
        assertEq(_newToken.balanceOf(address(this)),      0);
        assertEq(_newToken.balanceOf(address(_migrator)), OLD_SUPPLY * scalar_);

        _migrator.migrate(amount_);

        assertEq(_oldToken.allowance(address(this), address(_migrator)), 0);

        assertEq(_oldToken.balanceOf(address(this)),      0);
        assertEq(_oldToken.balanceOf(address(_migrator)), amount_);
        assertEq(_newToken.balanceOf(address(this)),      newAmount);
        assertEq(_newToken.balanceOf(address(_migrator)), (OLD_SUPPLY  * scalar_) - newAmount);
    }

}
