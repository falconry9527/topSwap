// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {IReferral} from "./interface/IReferral.sol";

contract Referral is IReferral {

    event BindReferral(address indexed user, address parent);
    event TopAddressAdded(address indexed newTop);
    event TopAddressRemoved(address indexed oldTop);

    address public owner;    
    uint256 public constant MAX_DEPTH = 30; 

    address[] public topAddresses;
    mapping(address => bool) public isTopAddress;

    mapping(address => address) private _parent;
    mapping(address => address[]) private _children;
    mapping(address => bool) public registered;
    address constant DEAD_ADDRESS = 0x000000000000000000000000000000000000dEaD;
    
    modifier onlyOwner() {
        require(msg.sender == owner, "Not owner");
        _;
    }

    constructor(address _tops) {
        require(_tops != address(0), "Invalid top");
        require(!registered[_tops], "Already registered");

        owner = msg.sender;

        isTopAddress[_tops] = true;
        registered[_tops] = true;
        _parent[_tops] = address(0);
    }


    function registerUser(address _referral) external override  {
        address _user = msg.sender;
        if(!isTopAddress[_user]){
            require(!registered[_user], "Already registered");
            require(_user != _referral, "Cannot refer self");

            require(_referral != address(0), "Cannot refer address 0");
            require(_referral != DEAD_ADDRESS, "Cannot refer blackhole");
            require(_referral != address(0xdead), "Cannot refer blackhole");
            require(_parent[_user] == address(0), "Already has parent");
            require(registered[_referral], "Referral not registered");
            
            registered[_user] = true;
            _parent[_user] = _referral;
            _children[_referral].push(_user);
        }
    }

    function bindReferral(address parent, address user) external  {
        if(!isTopAddress[user]){
            require(user != parent, "Cannot refer self");
            require(parent != address(0), "Cannot refer address 0");
            require(parent != DEAD_ADDRESS, "Cannot refer blackhole");
            require(parent != address(0xdead), "Cannot refer blackhole");
            require(!isTopAddress[user], "Top cannot be referred");
            require(_parent[user] != address(0), "Already has parent");
            require(registered[parent], "parent not registered");
            require(registered[user], "user not registered");
            _parent[user] = parent;
        }
    }

    function addTopAddress(address newTop) external onlyOwner {
        require(newTop != address(0), "Invalid address");
        require(!isTopAddress[newTop], "Already a top address");

        isTopAddress[newTop] = true;
        registered[newTop] = true;
        _parent[newTop] = address(0);

        emit TopAddressAdded(newTop);
    }
    function isRegistered(address _user) external view override returns(bool) {
        return registered[_user];
    }

    function getReferral(address _address) external view override returns(address) {
        return _parent[_address];
    }

    function isBindReferral(address _address) external view override returns(bool) {
        return _parent[_address] != address(0) || isTopAddress[_address];
    }

    function getReferralCount(address _address) external view override returns(uint256) {
        return _children[_address].length;
    }

    function getReferrals(address _address, uint256 _num) external view override returns(address[] memory) {
        if (_num > MAX_DEPTH) _num = MAX_DEPTH;

        address[] memory chain = new address[](_num);
        address current = _parent[_address];
        uint256 i = 0;
        while (current != address(0) && i < _num) {
            chain[i] = current;
            current = _parent[current];
            i++;
        }

        address[] memory result = new address[](i);
        for (uint256 j = 0; j < i; j++) {
            result[j] = chain[j];
        }
        return result;
    }

    function getDirectChildren(address _address) external view returns(address[] memory) {
        return _children[_address];
    }

    function getTopAddresses() external view returns(address[] memory) {
        return topAddresses;
    }

}

