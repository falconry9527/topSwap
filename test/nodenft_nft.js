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
    const count = await NodeNFT.getEligibleNFTCount();
    console.log(` getEligibleNFTCount ${count}`);

    // 批量读取（防止RPC超时）
    const batchSize = 5;
    for (let start = 1; start < batchSize; start += 1) {
       const add = await NodeNFT.ownerOf(start);
       console.log(` index ${start} owner  ${add}`);
    }
}

main().catch((error) => {
    console.error("❌ Error:", error);
    process.exitCode = 1;
});
