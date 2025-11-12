// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

interface IStaking {
    function balances(address) external view returns (uint256);
    function isPreacher(address) external  view returns(bool);
}
