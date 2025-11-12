// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {INodeNFT} from "./interface/INodeNFT.sol";
import {IReferral} from "./interface/IReferral.sol";
import "@openzeppelin/contracts/utils/Base64.sol";

/// @title Node and NFT System
/// @notice 用户可以购买节点，推荐关系奖励，累积节点可领取 NFT
contract NodeNFT is ERC721,INodeNFT, Ownable, ReentrancyGuard  {
    using SafeERC20 for IERC20;

    // ======== 全局变量 ========
    IERC20 public USDT ;
    address public marketingAddress; // 用于接收购买节点的资金

    // 用户注册和代理相关
    IReferral public referral; // 注册和代理关系合约
   
    // 节点相关 
    uint256 public constant nodePrice = 500 * 1e18 ; // 单份节点价格（支付 ERC20）
    uint256 public MAX_SHARES_PER_ADDRESS = 10; // 单个地址可购买的节点最大份数
    uint256 public totalSharesSold; // 已售出节点总份数

    mapping(address => uint256) public sharesOf; // 每个地址已购买的节点份数
    mapping(address => uint256) public directShares; // 用户直推节点数量
    mapping(address => uint256) public teamShares; // 用户团队节点数量

    address[] public nodes;  // 每个节点按顺序的归属记录
    mapping(address => NodeOrder[]) public userNodeOrders; // 用户的购买节点记录
    mapping(address => NodeOrderReward[]) public directNodeOrders; // 上级用户的直推节点购买记录
    mapping(address => uint256) public directNodeOrdersReward; // 直推奖励金额

    // NFT 相关
    uint256 public constant MAX_NFT = 200; // NFT 总发行量
    uint256 public constant MAX_SHARES_TOTAL = MAX_NFT * 10; // 节点总份数上限
    uint256 public nextNftId = 1; // 下一个 NFT ID
    uint256 public nftTotalMinted; // 已 mint NFT 数量
    mapping(address => uint256) public nftEligibleCount; // 用户可领取 NFT 数量
    mapping(address => uint256) public nftClaimedCount; // 用户已领取 NFT 数量
    mapping(address => uint256[]) public nftEligibleIds; // 用户可领取 NFT ID 列表
    mapping(address => uint256[]) public nftClaimedIds; // 用户已领取 NFT ID 列表
    mapping(uint256 => bool) public nftExists; // NFT 是否已存在
    string public baseURL;

    struct NodeOrder {
        uint256 timestamp; // 购买时间
        uint256 shares; // 购买份数
        uint256 totalAmount; // 总金额 = shares * unitPrice
    }
    struct NodeOrderReward {
        uint256 timestamp; // 购买时间
        uint256 shares; // 购买份数
        uint256 totalAmount; // 总金额 = shares * unitPrice
        uint256 directReward; // 直推奖励 
        address buyerAddress; // 购买用户的地址
    }
    uint256 public perNodeTops ; // 每个节点对应可领取 TOP 数量
    mapping(address => uint256) public topsEligible; // 用户可领取的 TOP 代币数量
    address public topAdress;
    // ======== 事件 ========
    event NodePurchased(address indexed user, uint256 shares, uint256 amount);
    event DirectRewardPaid(address indexed referrer, address indexed user, uint256 reward);
    event NFTClaimed(address indexed user, uint256 tokenId);
    event TopsClaimed(address indexed user, uint256 amount);

    // ======== 构造函数 ========
    /// @notice 构造函数，用于初始化 TopNodeNFT 合约
    /// @param _usdtAddress        支付代币 USDT 的合约地址
    /// @param _marketingAddress   市场合约
    /// @param _referralAddress    上级关系合约
    constructor(
        address _usdtAddress,
        address _marketingAddress,
        address _referralAddress,
        string memory _baseURL
    ) ERC721("TopNodeNFT", "TNNFT")  Ownable(msg.sender)  {
        require(_usdtAddress != address(0), "payment token zero address");
        USDT = IERC20(_usdtAddress);
        marketingAddress = _marketingAddress;
        referral = IReferral(_referralAddress);
        perNodeTops = 50 * 1e18;
        baseURL = _baseURL;
    }

    // ======== 节点购买相关 ========
    function buyNodes(uint256 shares) external nonReentrant {
        require(referral.isRegistered(msg.sender), "not registered");
        require(shares > 0, "shares>0");
        require(totalSharesSold + shares <= MAX_SHARES_TOTAL,"exceed total limit");
        require(sharesOf[msg.sender] + shares <= MAX_SHARES_PER_ADDRESS,"exceed per address limit");
        address ref = referral.getReferral(msg.sender) ;
        require(referral.isBindReferral(msg.sender), "no ref") ; // 必须有上级代理才能买

        uint256 amount = shares * nodePrice ;
        USDT.safeTransferFrom(msg.sender, address(this), amount);
        // 更新记录
         for (uint256 i = 0; i < shares; i++) {
            // 更新记录
            nodes.push(msg.sender) ;
        }
        userNodeOrders[msg.sender].push(
            NodeOrder({
                timestamp: block.timestamp,
                shares: shares,
                totalAmount: amount
            })
        );
        uint256 directReward ;
        if (ref != address(0)) {
            if (sharesOf[ref] >= 1) {
               directReward = amount / 10;
            }
            directNodeOrders[ref].push(
                NodeOrderReward({
                    timestamp: block.timestamp,
                    shares: shares,
                    totalAmount: amount,
                    directReward: directReward,
                    buyerAddress: msg.sender
                })
            );
        }
        // 发放直推奖励
        if (directReward > 0) {
            directNodeOrdersReward[ref] += directReward;
            USDT.safeTransfer(ref, directReward) ;
            emit DirectRewardPaid(ref, msg.sender, directReward); 
        }
        // marketingAddress 
        USDT.safeTransfer(marketingAddress, amount - directReward);
        
        // 更新 shares
        totalSharesSold += shares;
        sharesOf[msg.sender] += shares;
        
        if (ref != address(0)) {
            directShares[ref] += shares;
        }
        
        address cur = ref;
        while (cur != address(0)) {
            teamShares[cur] += shares;
            cur =  referral.getReferral(cur);
        }

        // 可领取NFT,更新上级的 
        updateNft(ref) ;
        // 更新自己的
        updateNft(msg.sender) ;
        topsEligible[msg.sender] += shares * perNodeTops; // 可领取代币数
        emit NodePurchased(msg.sender, shares, amount);  // Emit event
    }

    function updateNft(address ref) internal {
        if (ref == address(0) || sharesOf[ref] == 0) {
            return;
        }
        uint256 totalEligible = directShares[ref] / 10;
        uint256 alreadyAssigned = nftClaimedCount[ref] + nftEligibleCount[ref];
        uint256 newEligible = totalEligible > alreadyAssigned ? totalEligible - alreadyAssigned : 0;
        if (newEligible == 0) {
            return;
        }
        uint256[] storage eligibleArray = nftEligibleIds[ref];
        for (uint256 i = 0; i < newEligible && nextNftId <= MAX_NFT; i++) {
            eligibleArray.push(nextNftId);
            nftExists[nextNftId] = true;
            nextNftId++;
        }
        nftEligibleCount[ref] = eligibleArray.length;
    }

    // ======== NFT 领取 ========
    function claimNFT(uint256 tokenId) external nonReentrant {
        require(nftExists[tokenId], "NFT does not exist");
        require(isEligibleForNFT(msg.sender, tokenId), "You are not eligible for this NFT");

        nftClaimedIds[msg.sender].push(tokenId);
        nftClaimedCount[msg.sender] += 1;

        nftEligibleIds[msg.sender] = removeFromArray(nftEligibleIds[msg.sender], tokenId);
        nftEligibleCount[msg.sender] -= 1;

        _safeMint(msg.sender, tokenId);
        
        emit NFTClaimed(msg.sender, tokenId);  // Emit event
    }

    function claimed(uint256 tokenId) public view returns (bool) {
        return _ownerOf(tokenId) != address(0);
    }

    function isEligibleForNFT(address user, uint256 tokenId) internal view returns (bool) {
        uint256[] memory eligibleIds = nftEligibleIds[user];
        for (uint256 i = 0; i < eligibleIds.length; i++) {
            if (eligibleIds[i] == tokenId) {
                return true;
            }
        }
        return false;
    }

    function removeFromArray(uint256[] storage array, uint256 value) internal returns (uint256[] memory) {
        uint256 length = array.length;
        for (uint256 i = 0; i < length; i++) {
            if (array[i] == value) {
                array[i] = array[length - 1];
                array.pop();
                break;
            }
        }
        return array;
    }
    // ======== 管理员方法 ========
    function setmarketingAddress(address _marketingAddress) external onlyOwner {
        require(_marketingAddress != address(0), "recipient address cannot be zero");
        marketingAddress = _marketingAddress;
    }
    function setTOP(address _topAddress) external onlyOwner {
        topAdress = _topAddress;
    }
    // ======== 查询方法 ========
    function getUserNodeOrders() external view returns (NodeOrder[] memory) {
        return userNodeOrders[msg.sender];
    }
    function getDirectNodeOrders() external view returns (NodeOrderReward[] memory) {
        return directNodeOrders[msg.sender];
    }

    function getDirectNodeAmount() external view returns (uint256) {
        return directShares[msg.sender] * nodePrice;
    }

    function getTeamNodeAmount() external view returns (uint256) {
        return teamShares[msg.sender] * nodePrice;
    }

    function getEligibleNFTCount() external view returns (uint256) {
        return nftEligibleCount[msg.sender];
    }

    function getClaimedNFTCount() external view returns (uint256) {
        return nftClaimedCount[msg.sender];
    }

    function getClaimedNFTs() external view returns (uint256[] memory) {
        return nftClaimedIds[msg.sender];
    }

    function getEligibleNFTs() external view returns (uint256[] memory) {
        return nftEligibleIds[msg.sender];
    }

    // 我的收益
    function getDirectReward() public view returns (uint256) {
        return directNodeOrdersReward[msg.sender];
    }

    // 返回节点总数
    function getNodesLength() external view override returns (uint256) {
        return nodes.length;
    }

    // 显式 override ERC721 和 INodeNFT
    function ownerOf(uint256 tokenId)
        public
        view
        override(ERC721, INodeNFT)
        returns (address)
    {
        return super.ownerOf(tokenId);
    }

    function getNodePrice() external pure returns (uint256) {
        return nodePrice;
    }

    function getRemainingNodes() external view returns (uint256) {
        return MAX_SHARES_TOTAL - totalSharesSold;
    }

    function getUserCanBuyNode() external view returns (uint256) {
        if (sharesOf[msg.sender] >= MAX_SHARES_PER_ADDRESS) {
            return 0;
        }
        return MAX_SHARES_PER_ADDRESS - sharesOf[msg.sender];
    }

    function setUserCanBuyNode(uint256 newLimit) external onlyOwner {
        require(newLimit > 0, "Invalid limit");
        MAX_SHARES_PER_ADDRESS = newLimit;
    }

    function claimTops(uint256 amount) external nonReentrant {
        require(amount > 0, "amount>0");
        require(topsEligible[msg.sender] >= amount, "not enough eligible TOP");
        topsEligible[msg.sender] -= amount;
        IERC20(topAdress).safeTransfer(msg.sender, amount);
        emit TopsClaimed(msg.sender, amount);
    }

    function getUserEligibleTops() external view returns (uint256 amount) {
        return topsEligible[msg.sender];
    }

    function setBaseURL(string memory _baseURL) external onlyOwner {
        baseURL = _baseURL;
    }

    function tokenURI(uint256 tokenId) public view override returns (string memory) {
        require(_ownerOf(tokenId) != address(0), "Token does not exist");
        string memory json = Base64.encode(bytes(string(abi.encodePacked(
            '{"name":"TopNodeNFT #', _toString(tokenId),
            '","description":"Top Node NFT","image":"', baseURL, '"}'
        ))));
        return string(abi.encodePacked("data:application/json;base64,", json));
    }

    function _toString(uint256 value) internal pure returns (string memory) {
        if (value == 0) return "0";
        uint256 temp = value;
        uint256 digits;
        while (temp != 0) {
            digits++;
            temp /= 10;
        }
        bytes memory buffer = new bytes(digits);
        while (value != 0) {
            digits -= 1;
            buffer[digits] = bytes1(uint8(48 + uint256(value % 10)));
            value /= 10;
        }
        return string(buffer);
    }
}
