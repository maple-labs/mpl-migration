// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity 0.8.7;

interface IERC20Like {

    function decimals() external view returns (uint8 decimals_);

}

interface IGlobalsLike {

    function governor() external view returns (address governor_);

    function operationalAdmin() external view returns (address operationalAdmin_);

}
