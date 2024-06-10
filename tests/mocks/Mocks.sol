// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity 0.8.7;

contract MockGlobals {
    
    address public governor;
    address public operationalAdmin;

    function __setGovernor(address governor_) external {
        governor = governor_;
    }

    function __setOperationalAdmin(address operationalAdmin_) external {
        operationalAdmin = operationalAdmin_;
    }
    
}
