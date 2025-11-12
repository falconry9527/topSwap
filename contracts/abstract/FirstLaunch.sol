// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

abstract contract FirstLaunch {
    uint40 public launchedAtTimestamp;

    function launch() internal {
        // require(launchedAtTimestamp == 0, "Already launched");
        launchedAtTimestamp = uint40(block.timestamp);
    }
}