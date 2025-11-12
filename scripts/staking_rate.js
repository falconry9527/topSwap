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
   const rates = [
        "1000049949800000000", // 1.0000499498
        "1001239000000000000"  // 1.001239
    ];

    const stakeDays = [
        1 * 60,  // 1 minute
        5 * 60   // 5 minutes
    ];
    // ===========================
    console.log("🚀 Setting default rates and stakeDays...");
    // 设置 rates
    for (let i = 0; i < rates.length; i++) {
        const tx = await Staking.setRate(i, rates[i]);
        await tx.wait();
        console.log(`✅ setRate(${i}, ${rates[i]}) done`);
    }

    // 设置 stakeDays
    for (let i = 0; i < stakeDays.length; i++) {
        const tx = await Staking.setStakeDay(i, stakeDays[i]);
        await tx.wait();
        console.log(`✅ setStakeDay(${i}, ${stakeDays[i]}) done`);
    }
}

main().catch((error) => {
    console.error(error);
    process.exitCode = 1;
});
