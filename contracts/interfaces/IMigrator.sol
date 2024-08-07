// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.7;

interface IMigrator {

    /**
     *  @dev    Get the status of the migrator.
     *  @return active_ True if migrations are active.
     */
    function active() external view returns (bool active_);

    /**
     *  @dev   Gets the Maple Globals address.
     *  @param globals_ The address of the Maple globals.
     */
    function globals() external view returns (address globals_);

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
     *  @dev    Exchange the oldToken for the same amount of newToken.
     *  @param  oldTokenAmount_ The amount of oldToken to swap for newToken.
     *  @return newTokenAmount_ The amount of newToken received.
     */
    function migrate(uint256 oldTokenAmount_) external returns (uint256 newTokenAmount_);

    /**
     *  @dev    Exchange the oldToken for the same amount of newToken.
     *  @param  recipient_      The address of the recipient of the newToken.
     *  @param  oldTokenAmount_ The amount of oldToken to swap for newToken.
     *  @return newTokenAmount_ The amount of newToken received.
     */
    function migrate(address recipient_, uint256 oldTokenAmount_) external returns (uint256 newTokenAmount_);

    /**
     *  @dev   Set the migrator to active or inactive.
     *  @param active_ True if migrations are active.
     */
    function setActive(bool active_) external;

    /**
     *  @dev    Get the scalar value for token split.
     *  @return tokenSplitScalar_ The scalar value for token split.
     */
    function tokenSplitScalar() external view returns (uint256 tokenSplitScalar_);

}
