// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {INodeNFT} from "./interface/INodeNFT.sol";
import {IReferral} from "./interface/IReferral.sol";
import "@openzeppelin/contracts/utils/Base64.sol";

contract NodeNFT is ERC721Enumerable, INodeNFT, Ownable, ReentrancyGuard {
    using SafeERC20 for IERC20;

    IERC20 public USDT;
    address public marketingAddress;
    IReferral public referral;

    uint256 public constant nodePrice = 500 * 1e18;
    uint256 public MAX_SHARES_PER_ADDRESS = 10;
    uint256 public totalSharesSold;

    mapping(address => uint256) public sharesOf;
    mapping(address => uint256) public directShares;
    mapping(address => uint256) public teamShares;

    address[] public nodes;
    mapping(address => NodeOrder[]) public userNodeOrders;
    mapping(address => NodeOrderReward[]) public directNodeOrders;
    mapping(address => uint256) public directNodeOrdersReward;

    uint256 public constant MAX_NFT = 200;
    uint256 public constant MAX_SHARES_TOTAL = MAX_NFT * 10;
    uint256 public nextNftId = 1;
    uint256 public nftTotalMinted;
    mapping(address => uint256) public nftEligibleCount;
    mapping(address => uint256) public nftClaimedCount;
    mapping(address => uint256[]) public nftEligibleIds;
    mapping(address => uint256[]) public nftClaimedIds;
    mapping(uint256 => bool) private nftExists;

    string public baseURL;

    struct NodeOrder {
        uint256 timestamp;
        uint256 shares;
        uint256 totalAmount;
    }
    struct NodeOrderReward {
        uint256 timestamp;
        uint256 shares;
        uint256 totalAmount;
        uint256 directReward;
        address buyerAddress;
    }

    uint256 public perNodeTops;
    mapping(address => uint256) public topsEligible;
    address public topAdress;

    event NodePurchased(address indexed user, uint256 shares, uint256 amount);
    event DirectRewardPaid(address indexed referrer, address indexed user, uint256 reward);
    event NFTClaimed(address indexed user, uint256 tokenId);
    event TopsClaimed(address indexed user, uint256 amount);

    constructor(
        address _usdtAddress,
        address _marketingAddress,
        address _referralAddress,
        string memory _baseURL
    ) ERC721("TopNodeNFT", "TNNFT") Ownable(msg.sender)  {
        require(_usdtAddress != address(0), "payment token zero address");
        USDT = IERC20(_usdtAddress);
        marketingAddress = _marketingAddress;
        referral = IReferral(_referralAddress);
        perNodeTops = 50 * 1e18;
        baseURL = _baseURL;
    }

    // ====================== Buy Nodes ======================
    function buyNodes(uint256 shares) external nonReentrant {
        require(referral.isRegistered(msg.sender), "not registered");
        require(shares > 0, "shares>0");
        require(totalSharesSold + shares <= MAX_SHARES_TOTAL,"exceed total limit");
        require(sharesOf[msg.sender] + shares <= MAX_SHARES_PER_ADDRESS,"exceed per address limit");
        address ref = referral.getReferral(msg.sender);
        require(referral.isBindReferral(msg.sender), "no ref");

        uint256 amount = shares * nodePrice;
        USDT.safeTransferFrom(msg.sender, address(this), amount);
        for (uint256 i = 0; i < shares; i++) {
            nodes.push(msg.sender);
        }

        userNodeOrders[msg.sender].push(NodeOrder({
            timestamp: block.timestamp,
            shares: shares,
            totalAmount: amount
        }));

        uint256 directReward;
        if (ref != address(0) && sharesOf[ref] >= 1) {
            directReward = amount / 10;
            directNodeOrders[ref].push(NodeOrderReward({
                timestamp: block.timestamp,
                shares: shares,
                totalAmount: amount,
                directReward: directReward,
                buyerAddress: msg.sender
            }));
            directNodeOrdersReward[ref] += directReward;
            USDT.safeTransfer(ref, directReward);
            emit DirectRewardPaid(ref, msg.sender, directReward);
        }

        USDT.safeTransfer(marketingAddress, amount - directReward);

        totalSharesSold += shares;
        sharesOf[msg.sender] += shares;

        if (ref != address(0)) {
            directShares[ref] += shares;
        }

        address cur = ref;
        while (cur != address(0)) {
            teamShares[cur] += shares;
            cur = referral.getReferral(cur);
        }

        updateNft(ref);
        updateNft(msg.sender);
        topsEligible[msg.sender] += shares * perNodeTops;

        emit NodePurchased(msg.sender, shares, amount);
    }

    // ====================== NFT Logic ======================
    function updateNft(address ref) internal {
        if (ref == address(0) || sharesOf[ref] == 0) return;

        uint256 totalEligible = directShares[ref] / 10;
        uint256 alreadyAssigned = nftClaimedCount[ref] + nftEligibleCount[ref];
        uint256 newEligible = totalEligible > alreadyAssigned ? totalEligible - alreadyAssigned : 0;
        if (newEligible == 0) return;

        uint256[] storage eligibleArray = nftEligibleIds[ref];
        for (uint256 i = 0; i < newEligible && nextNftId <= MAX_NFT; i++) {
            eligibleArray.push(nextNftId);
            nftExists[nextNftId] = true; 
            nextNftId++;
        }
        nftEligibleCount[ref] = eligibleArray.length;
    }

    function claimNFT(uint256 tokenId) external nonReentrant {
        require(_exists(tokenId), "NFT does not exist");
        require(isEligibleForNFT(msg.sender, tokenId), "not eligible");

        nftClaimedIds[msg.sender].push(tokenId);
        nftClaimedCount[msg.sender] += 1;

        nftEligibleIds[msg.sender] = removeFromArray(nftEligibleIds[msg.sender], tokenId);
        nftEligibleCount[msg.sender] -= 1;

         super._safeMint(msg.sender, tokenId);
        emit NFTClaimed(msg.sender, tokenId);
    }

    function _exists(uint256 tokenId) internal view returns (bool) {
        return nftExists[tokenId];
    }

    function isEligibleForNFT(address user, uint256 tokenId) internal view returns (bool) {
        uint256[] memory eligibleIds = nftEligibleIds[user];
        for (uint256 i = 0; i < eligibleIds.length; i++) {
            if (eligibleIds[i] == tokenId) return true;
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

    // ====================== Interface Implementation ======================
    function claimed(uint256 tokenId) public view override(INodeNFT) returns (bool) {
        return _exists(tokenId);
    }
    function ownerOf(uint256 tokenId)
        public
        view
        override(ERC721, INodeNFT, IERC721)
        returns (address)
    {
        return super.ownerOf(tokenId);
    }

    function supportsInterface(bytes4 interfaceId)
        public
        view
        override(ERC721Enumerable)
        returns (bool)
    {
        return super.supportsInterface(interfaceId);
    }
    function tokenURI(uint256 tokenId) public view override returns (string memory) {
        require(_exists(tokenId), "Token does not exist");
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

    // ====================== TOPS ======================
    function claimTops(uint256 amount) external nonReentrant {
        require(amount > 0, "amount>0");
        require(topsEligible[msg.sender] >= amount, "not enough eligible TOP");
        topsEligible[msg.sender] -= amount;
        IERC20(topAdress).safeTransfer(msg.sender, amount);
        emit TopsClaimed(msg.sender, amount);
    }

    function getUserEligibleTops() external view returns (uint256) {
        return topsEligible[msg.sender];
    }

    // ====================== Setters ======================
    function setmarketingAddress(address _marketingAddress) external onlyOwner {
        require(_marketingAddress != address(0), "recipient cannot be zero");
        marketingAddress = _marketingAddress;
    }

    function setTOP(address _topAddress) external onlyOwner {
        topAdress = _topAddress;
    }

    function setBaseURL(string memory _baseURL) external onlyOwner {
        baseURL = _baseURL;
    }

    function setUserCanBuyNode(uint256 newLimit) external onlyOwner {
        require(newLimit > 0, "Invalid limit");
        MAX_SHARES_PER_ADDRESS = newLimit;
    }

    // ====================== View Functions ======================
    function getUserNodeOrders() external view returns (NodeOrder[] memory) {
        return userNodeOrders[msg.sender];
    }
    struct NodeOrderRewardWithLevel {
        uint256 timestamp;
        uint256 shares;
        uint256 totalAmount;
        uint256 directReward;
        address buyerAddress;
        uint8 teamLevel;
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

    function getDirectReward() public view returns (uint256) {
        return directNodeOrdersReward[msg.sender];
    }

    function getNodesLength() external view override returns (uint256) {
        return nodes.length;
    }

    function getNodePrice() external pure returns (uint256) {
        return nodePrice;
    }

    function getRemainingNodes() external view returns (uint256) {
        return MAX_SHARES_TOTAL - totalSharesSold;
    }

    function getUserCanBuyNode() external view returns (uint256) {
        if (sharesOf[msg.sender] >= MAX_SHARES_PER_ADDRESS) return 0;
        return MAX_SHARES_PER_ADDRESS - sharesOf[msg.sender];
    }
}
