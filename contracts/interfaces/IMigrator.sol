// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.7;

interface IMigrator {

    /**
     *  @dev    Get address of newToken.
     *  @return newToken_ The address of new token.
     */
    function newToken() external view returns (address newToken_);

    /**
     *  @dev    Get address of oldToken.
     *  @return oldToken_ The address of new token.
     */
    function oldToken() external view returns (address oldToken_);

    /**
     *  @dev   Exchange the oldToken for the same amount of newToken.
     *  @param amount_ The amount of oldToken to swap for newToken.
     */
    function migrate(uint256 amount_) external;

    /**
     *  @dev   Exchange the oldToken for the same amount of newToken.
     *  @param owner_ The address of the owner of the oldToken.
     *  @param amount_ The amount of oldToken to swap for newToken.
     */
    function migrate(address owner_, uint256 amount_) external;

}
