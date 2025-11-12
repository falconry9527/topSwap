const fs = require("fs");
const path = require("path");
const { ethers, network } = require("hardhat");
require("dotenv").config({ path: path.resolve(__dirname, "..", ".env") });

// 设置单笔限额
async function main() {
    // 读取部署好的合约信息
    const deployedPath = path.resolve(__dirname, "..", "deployed.json");
    if (!fs.existsSync(deployedPath)) throw new Error("deployed.json not found");
    const deployed = JSON.parse(fs.readFileSync(deployedPath, "utf-8"));
    const stakingAddress = deployed.contracts.staking;

    // 获取部署者账户
    const [deployer] = await ethers.getSigners();
    console.log("Deploying account:", deployer.address);
    console.log("Network:", network.name);
    console.log("-----------------------------------------");

    // 获取 TOP 和 USDT 合约实例
    const Staking = await ethers.getContractAt("Staking", stakingAddress);
    const   limits = [20000,500,1000];
    // const   limits = [200,500,1000];

    let tx = await Staking.setOneLimits(limits) ;
    await tx.wait();
    console.log(`Staking setOneLimits ${limits} `);
}

main().catch((error) => {
    console.error(error);
    process.exitCode = 1;
});
