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
    
    uint256 public maxNode = 800;
    uint256 public topsPerNode = 125 ether;

    event TopsClaimed(address indexed user, uint256 amount);
    event MaxNodeUpdated(uint256 newMax);

    constructor(address _topsToken, address _nodeNFT) Owned(msg.sender) {
        require(_topsToken != address(0), "token cannot be zero");
        require(_nodeNFT != address(0), "nodeNFT cannot be zero");
        topsToken = IERC20(_topsToken);
        nodeNFT = INodeNFT(_nodeNFT);
    }

    /// @notice 计算用户在前 maxNode 个 nodes 中出现的次数
    function earlyBuyerCount(address user) public view returns (uint256) {
        uint256 total = nodeNFT.getNodesLength();
        uint256 limit = total < maxNode ? total : maxNode;
        uint256 count = 0;
        for (uint256 i = 0; i < limit; i++) {
            if (nodeNFT.nodes(i) == user) {
                count += 1;
            }
        }
        return count;
    }

    /// @notice 用户领取 TOPS
    function claimTops(uint256 amount) external {
        // require(nodeNFT.getNodesLength() >= maxNode, "not open");
        require(amount > 0, "amount>0");

        uint256 eligible = getUserEligibleTops(msg.sender);
        require(eligible >= amount, "not enough eligible TOP");

        claimedTops[msg.sender] += amount;
        topsToken.safeTransfer(msg.sender, amount);
        emit TopsClaimed(msg.sender, amount);
    }

    /// @notice 获取用户可领取 TOPS = 早期购买次数 * topsPerNode - 已领取
    function getUserEligibleTops(address user) public view returns (uint256) {
        uint256 count = earlyBuyerCount(user);
        if (count == 0) return 0;
        uint256 totalEligible = count * topsPerNode;
        uint256 alreadyClaimed = claimedTops[user];
        if (totalEligible <= alreadyClaimed) return 0;
        return totalEligible - alreadyClaimed;
    }

    function getUserClaimedTops(address user) external view returns (uint256) {
        return claimedTops[user];
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
        maxNode = newMax;
        topsPerNode = 100000 ether / newMax;
        emit MaxNodeUpdated(newMax);
    }
}
