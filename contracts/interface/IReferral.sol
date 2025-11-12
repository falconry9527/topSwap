// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

interface IReferral {
    function getReferral(address _address) external view returns(address);
    function isBindReferral(address _address) external view returns(bool);
    function bindReferral(address parent, address user) external;
    function getReferralCount(address _address) external view returns(uint256);
    function getReferrals(address _address, uint256 _num) external view returns(address[] memory);
    function registerUser(address _referral) external;
    function isRegistered(address _user) external view returns(bool);
}