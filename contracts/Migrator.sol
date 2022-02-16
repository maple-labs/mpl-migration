// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity 0.8.7;

import { ERC20Helper } from "../modules/erc20-helper/src/ERC20Helper.sol";

contract Migrator {

    address immutable oldToken;
    address immutable newToken;

    constructor(address old_, address new_) {
        oldToken = old_;
        newToken = new_;
    }

    function migrate(uint256 amount_) external {
        require(amount_ > 0, "M:M:ZERO_AMOUNT");

        require(ERC20Helper.transferFrom(oldToken, msg.sender, address(this), amount_), "M:M:TRANSFER_FROM_FAILED");
        require(ERC20Helper.transfer(newToken, msg.sender, amount_), "M:M:TRANSFER_FAILED");
    }

}