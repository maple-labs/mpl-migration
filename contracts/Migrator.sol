// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity 0.8.7;

import { ERC20Helper } from "../modules/erc20-helper/src/ERC20Helper.sol";

import { IERC20Like } from "./interfaces/Interfaces.sol";

contract Migrator {

    address public immutable newToken;
    address public immutable oldToken;

    constructor(address oldToken_, address newToken_) {
        require(IERC20Like(newToken_).decimals() == IERC20Like(oldToken_).decimals(), "M:C:DECIMAL_MISMATCH");

        oldToken = oldToken_;
        newToken = newToken_;
    }

    function migrate(uint256 amount_) external {
        migrate(msg.sender, amount_);
    }

    function migrate(address owner_, uint256 amount_) public {
        require(amount_ > uint256(0),                                              "M:M:ZERO_AMOUNT");
        require(ERC20Helper.transferFrom(oldToken, owner_, address(this), amount_), "M:M:TRANSFER_FROM_FAILED");
        require(ERC20Helper.transfer(newToken, owner_, amount_),                    "M:M:TRANSFER_FAILED");
    }

}
