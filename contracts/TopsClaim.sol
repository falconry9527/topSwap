// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {Owned} from "./abstract/Owned.sol";
import {INodeNFT} from "./interface/INodeNFT.sol";

contract TopsClaim is Owned {
    using SafeERC20 for IERC20;

    IERC20 public topsToken;
    INodeNFT public nodeNFT;
    mapping(address => uint256) public claimedTops;
    
    uint256 public topsPerNode = 125 ether;
    uint256 public MAXNode = 800;

    event TopsClaimed(address indexed user, uint256 amount);
    event TopsPerNodeUpdated(uint256 newAmount);

    constructor(address _topsToken, address _nodeNFT) Owned(msg.sender) {
        require(_topsToken != address(0), "token cannot be zero");
        require(_nodeNFT != address(0), "nodeNFT cannot be zero");
        topsToken = IERC20(_topsToken);
        nodeNFT = INodeNFT(_nodeNFT);
    }
    function claimTops(uint256 amount) external {
        require(nodeNFT.getNodesLength()>= MAXNode, "not open");
        require(amount > 0, "amount>0");
        uint256 eligible = getUserEligibleTops(msg.sender);
        require(eligible >= amount, "not enough eligible TOP");
        claimedTops[msg.sender] += amount;
        topsToken.safeTransfer(msg.sender, amount);
        emit TopsClaimed(msg.sender, amount);
    }
    function getUserEligibleTops(address user) public view returns (uint256) {
        uint256 totalEligible = nodeNFT.getUserNodeOrderLength(user) * topsPerNode;
        uint256 alreadyClaimed = claimedTops[user];
        if (totalEligible <= alreadyClaimed) {
            return 0;
        }
        return totalEligible - alreadyClaimed;
    }
    function getUserClaimedTops(address user) external view returns (uint256) {
        return claimedTops[user];
    }
    function setTopsPerNode(uint256 newAmount) external onlyOwner {
        require(newAmount > 0, "invalid amount");
        topsPerNode = newAmount;
        emit TopsPerNodeUpdated(newAmount);
    }
    function setTopsToken(address _topsToken) external onlyOwner {
        require(_topsToken != address(0), "token cannot be zero");
        topsToken = IERC20(_topsToken);
    }
    function setNodeNFT(address _nodeNFT) external onlyOwner {
        require(_nodeNFT != address(0), "nodeNFT cannot be zero");
        nodeNFT = INodeNFT(_nodeNFT);
    }
    function emergencyWithdrawTop() external onlyOwner {
        uint256 balance = topsToken.balanceOf(address(this));
        require(balance > 0, "no TOPS balance");
        topsToken.safeTransfer(owner, balance);
    }
    function setMaxNode(uint256 newMax) external onlyOwner {
        require(newMax > 0, "invalid max node");
        MAXNode = newMax;
    }

}
