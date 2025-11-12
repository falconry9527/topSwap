// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.30;

library Helper {
    // function isContract(address account) internal view returns (bool) {
    //    (bool success, ) = account.staticcall(abi.encodeWithSignature("getReserves()"));
    //     return success;
    // }

    function isContract(address msg_sender,address tx_origin) internal pure returns (bool) {
         return tx_origin != msg_sender ;
    }


    function getAmountOut(uint256 amountIn, uint256 reserveIn, uint256 reserveOut)
        internal
        pure
        returns (uint256 amountOut)
    {
        uint256 amountInWithFee = amountIn * 9975;
        uint256 numerator = amountInWithFee * reserveOut;
        uint256 denominator = (reserveIn * 10000) + amountInWithFee;
        amountOut = numerator / denominator;
    }

    // given an output amount of an asset and pair reserves, returns a required input amount of the other asset
    function getAmountIn(uint256 amountOut, uint256 reserveIn, uint256 reserveOut)
        internal
        pure
        returns (uint256 amountIn)
    {
        uint256 numerator = reserveIn * amountOut * 10000;
        uint256 denominator = (reserveOut - amountOut) * 9975;
        amountIn = (numerator / denominator) + 1;
    }
}