// SPDX-License-Identifier: MIT

pragma solidity 0.6.12;

interface ICMT {
    function beginMigration() external;
    function endMigration() external;
}
