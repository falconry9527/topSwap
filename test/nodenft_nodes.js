const fs = require("fs");
const path = require("path");
const { ethers, network } = require("hardhat");
require("dotenv").config({ path: path.resolve(__dirname, "..", ".env") });

async function main() {
    // 读取部署好的合约信息
    const deployedPath = path.resolve(__dirname, "..", "deployed.json");
    if (!fs.existsSync(deployedPath)) throw new Error("deployed.json not found");
    const deployed = JSON.parse(fs.readFileSync(deployedPath, "utf-8"));
    const nodeNFTAddress = deployed.contracts.nodeNFT;

    // 获取账户
    const [deployer] = await ethers.getSigners();
    console.log("Using account:", deployer.address);
    console.log("Network:", network.name);
    console.log("-----------------------------------------");

    // 获取合约实例
    const NodeNFT = await ethers.getContractAt("NodeNFT", nodeNFTAddress);

    // 获取节点数量
    const total = await NodeNFT.getNodesLength();
    const totalNum = Number(total);
    console.log(`Total nodes: ${totalNum}`);

    if (totalNum === 0) {
        console.log("No nodes found.");
        return;
    }

    // 批量读取（防止RPC超时）
    const batchSize = 100;
    for (let start = 0; start < totalNum; start += batchSize) {
        const end = Math.min(start + batchSize, totalNum);
        const promises = [];
        for (let i = start; i < end; i++) {
            promises.push(NodeNFT.nodes(i));
        }
        const results = await Promise.all(promises);

        results.forEach((addr, idx) => {
            const index = start + idx;
            const line = `${index}: ${addr}\n`;
            process.stdout.write(line);
        });
    }
}

main().catch((error) => {
    console.error("❌ Error:", error);
    process.exitCode = 1;
});
