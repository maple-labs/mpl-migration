// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity 0.8.7;

import { ERC20Helper } from "../modules/erc20-helper/src/ERC20Helper.sol";

contract Migrator {

    address public immutable oldToken;
    address public immutable newToken;

    constructor(address oldToken_, address newToken_) {
        oldToken = oldToken_;
        newToken = newToken_;
    }

    function migrate(uint256 amount_) external {
        migrate(msg.sender, amount_);
    }

    function migrate(address owner, uint256 amount_) public {
        require(amount_ > 0, "M:M:ZERO_AMOUNT");

        require(ERC20Helper.transferFrom(oldToken, owner, address(this), amount_), "M:M:TRANSFER_FROM_FAILED");
        require(ERC20Helper.transfer(newToken, owner, amount_),                    "M:M:TRANSFER_FAILED");
    }

}
