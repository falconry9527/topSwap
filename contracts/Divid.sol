// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {IDivid} from "./interface/IDivid.sol";
import {INodeNFT} from "./interface/INodeNFT.sol";
import {Owned} from "./abstract/Owned.sol";

contract Divid is Owned,IDivid, ReentrancyGuard {
    using SafeERC20 for IERC20;

    IERC20 public usdt;
    INodeNFT public nft;

    // NFT 分红
    uint256 public nftBatchSize = 20;
    uint256 public nextNftId = 0;
    uint256 public nftAccumulated;
    uint256 public constant nftTHRESHOLD = 50 * 1e18;
    uint256 public nftAccumulatedAll;

    // 节点分红
    uint256 public nodeBatchSize = 20;
    uint256 public nextNodeIndex = 0;
    uint256 public nodeAccumulated;
    uint256 public nodeAccumulatedAll;

    uint256 public constant nodeTHRESHOLD = 100 * 1e18;
    uint256 public maxNode = 2000;


    // --- Events ---
    event NftDividendDistributed(uint256 startId, uint256 endId, uint256 amount);
    event NodeDividendDistributed(uint256 startId, uint256 endId, uint256 amount);

    constructor(address _usdtAddress, address _nftAddress)  Owned(msg.sender)  {
        usdt = IERC20(_usdtAddress);
        nft = INodeNFT(_nftAddress);
        owner = msg.sender;
    }

    /// @notice NFT 分红
    function executeNftDividend(uint256 tetherAmount) external nonReentrant {
        require(tetherAmount > 0, "Zero amount");
        usdt.safeTransferFrom(msg.sender, address(this), tetherAmount);
        nftAccumulated += tetherAmount;
        nftAccumulatedAll+= tetherAmount;
        uint256 nftAccumulatedSend = nftAccumulated / nftTHRESHOLD * nftTHRESHOLD;

        uint256 totalNft = maxNode / 10 ;
        if (totalNft == 0) return;
        if (usdt.balanceOf(address(this)) < nftAccumulatedSend) return;

        uint256 perNftAmount = nftTHRESHOLD / nftBatchSize;
        uint256 sendAmount =0 ;
        uint256 count=1 ;
        while (nftAccumulated >= nftTHRESHOLD  && sendAmount < nftAccumulatedSend  ) {
            uint256 startId = nextNftId;
            if (startId >= totalNft) startId = 0;

            uint256 endId = startId + nftBatchSize;
            if (endId > totalNft) endId = totalNft;
            
            for (uint256 id = startId; id < endId; id++) {
                if (nft.claimed(id)) {
                    address ownerAddr = nft.ownerOf(id);
                    if (ownerAddr != address(0)) {
                        usdt.safeTransfer(ownerAddr, perNftAmount);
                        sendAmount+= perNftAmount ;
                        nftAccumulated -= perNftAmount;
                    }
                }
            }
            nextNftId = endId;
            if (nextNftId >= totalNft) nextNftId = 0;
            emit NftDividendDistributed(startId, endId - 1, nftTHRESHOLD);
            count +=1 ;
            if(count > 10){
               return ;
            }
        }
    }

    /// @notice 节点分红
    function executeNodeDividend(uint256 tetherAmount) external  nonReentrant {
        require(tetherAmount > 0, "Zero amount");
        usdt.safeTransferFrom(msg.sender, address(this), tetherAmount);
        nodeAccumulated += tetherAmount;
        nodeAccumulatedAll += tetherAmount;
        uint256 nodeAccumulatedSend = nodeAccumulated / nodeTHRESHOLD * nodeTHRESHOLD;
        uint256 totalNodes = maxNode ;
        if (totalNodes == 0) return;
        if (usdt.balanceOf(address(this)) < nodeAccumulatedSend) return;

        uint256 totalNodesArr = nft.getNodesLength();
        if (totalNodesArr == 0) return; // 没有节点，返回
        uint256 perNodeAmount = nodeTHRESHOLD / nodeBatchSize;

        uint256 sendAmount =0 ;
        while (nodeAccumulated >= nodeTHRESHOLD && sendAmount < nodeAccumulatedSend ) {
            if (nextNodeIndex >= totalNodes) nextNodeIndex = 0;
            
            uint256 startIdx = nextNodeIndex;
            if (startIdx >= totalNodes) startIdx = 0;
            if (startIdx >= totalNodesArr) startIdx = 0;
            
            uint256 endIdx = startIdx + nodeBatchSize;
            if (endIdx > totalNodes) endIdx = totalNodes;
            if (endIdx > totalNodesArr) endIdx = totalNodesArr;

            for (uint256 i = startIdx; i < endIdx; i++) {
                if (i < totalNodesArr) {
                    address nodeOwner = nft.nodes(i);
                    if (nodeOwner != address(0)) {
                        usdt.safeTransfer(nodeOwner, perNodeAmount);
                        sendAmount+= perNodeAmount ;
                        nodeAccumulated -= perNodeAmount ;
                        nextNodeIndex = i + 1;                     
                    }
                }
            }
            emit NodeDividendDistributed(startIdx, nextNodeIndex-1, perNodeAmount);
        }
    }

    function setMaxNode(uint256 newMax) external onlyOwner {
        require(newMax >= 400 && newMax<=2000, "invalid max node");
        maxNode = newMax;
    }
}
