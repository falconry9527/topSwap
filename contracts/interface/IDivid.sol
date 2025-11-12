// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

interface IDivid {
    function executeNftDividend(uint256 tetherAmount) external;
    function executeNodeDividend(uint256 tetherAmount) external;
}