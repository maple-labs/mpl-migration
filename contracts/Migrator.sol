// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity 0.8.7;

import { ERC20Helper } from "../modules/erc20-helper/src/ERC20Helper.sol";

import { IERC20Like, IGlobalsLike } from "./interfaces/Interfaces.sol";

import { IMigrator } from "./interfaces/IMigrator.sol";

contract Migrator is IMigrator {

    address public immutable override globals;
    address public immutable override newToken;
    address public immutable override oldToken;

    uint256 public immutable override tokenSplitScalar;

    bool public override active;

    constructor(address globals_, address oldToken_, address newToken_, uint256 scalar_) {
        require(scalar_ > 0, "M:C:ZERO_SCALAR");

        require(IERC20Like(newToken_).decimals() == IERC20Like(oldToken_).decimals(), "M:C:DECIMAL_MISMATCH");

        globals  = globals_;
        oldToken = oldToken_;
        newToken = newToken_;

        tokenSplitScalar = scalar_;
    }

    function migrate(uint256 amount_) external override returns (uint256 migratedAmount_) {
        migratedAmount_ = migrate(msg.sender, amount_);
    }

    function migrate(address owner_, uint256 amount_) public override returns (uint256 migratedAmount_) {
        require(active,                "M:M:INACTIVE");
        require(amount_ != uint256(0), "M:M:ZERO_AMOUNT");

        migratedAmount_ = amount_ * tokenSplitScalar;

        require(ERC20Helper.transferFrom(oldToken, owner_, address(this), amount_), "M:M:TRANSFER_FROM_FAILED");
        require(ERC20Helper.transfer(newToken, owner_, migratedAmount_),            "M:M:TRANSFER_FAILED");
    }

    function setActive(bool active_) external override {
        require(
            msg.sender == IGlobalsLike(globals).governor() ||
            msg.sender == IGlobalsLike(globals).operationalAdmin(),
            "M:SA:NOT_PROTOCOL_ADMIN"
        );

        active = active_;
    }

}
