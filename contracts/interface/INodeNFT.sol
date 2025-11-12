// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

/// @title INodeNFT — NodeNFT 合约接口
/// @notice 提供节点地址列表和 NFT 所有权查询
interface INodeNFT  {
    /// ======== 全局变量 Getter ========
    /// @notice 返回所有节点地址数组
    /// @return nodes 所有节点地址
    function nodes(uint256 index) external view returns (address);

    /// @notice 返回节点数组长度
    /// @return length 节点数量
    function getNodesLength() external view returns (uint256 length);

    /// ======== NFT 所有权查询 ========
    /// @notice 返回指定 tokenId 的拥有者地址
    /// @param tokenId NFT 的唯一 ID
    /// @return owner NFT 拥有者地址
     function ownerOf(uint256 tokenId) external view returns (address) ;

    // ======== NFT 常量 ========
    /// @notice NFT 最大发行量
    function MAX_NFT() external view returns (uint256);

    /// @notice 判断NFT 是否存在
    function claimed(uint256 tokenId) external view returns (bool);

}
