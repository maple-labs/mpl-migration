// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity 0.8.7;

import { ERC20Helper } from "../modules/erc20-helper/src/ERC20Helper.sol";

import { IERC20Like } from "./interfaces/Interfaces.sol";

import { IMigrator } from "./interfaces/IMigrator.sol";

contract Migrator is IMigrator {

    uint256 public immutable override TOKEN_SPLIT_SCALAR;

    address public immutable override newToken;
    address public immutable override oldToken;

    constructor(address oldToken_, address newToken_, uint256 scalar_) {
        require(IERC20Like(newToken_).decimals() == IERC20Like(oldToken_).decimals(), "M:C:DECIMAL_MISMATCH");

        oldToken = oldToken_;
        newToken = newToken_;

        TOKEN_SPLIT_SCALAR = scalar_;
    }

    function migrate(uint256 amount_) external override {
        migrate(msg.sender, amount_);
    }

    function migrate(address owner_, uint256 amount_) public override {
        require(amount_ != uint256(0),                                              "M:M:ZERO_AMOUNT");

        require(ERC20Helper.transferFrom(oldToken, owner_, address(this), amount_),   "M:M:TRANSFER_FROM_FAILED");
        require(ERC20Helper.transfer(newToken, owner_, amount_ * TOKEN_SPLIT_SCALAR), "M:M:TRANSFER_FAILED");
    }

}
