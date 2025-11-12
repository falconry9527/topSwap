const fs = require("fs");
const path = require("path");
const { ethers, network } = require("hardhat");
require("dotenv").config({ path: path.resolve(__dirname, "..", ".env") });

// 设置交易开放时间
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
        // ===== 动态计算昨天的下午四点（北京时间） =====
    const now = new Date();
    // 获取昨天的日期
    now.setDate(now.getDate() - 1);
    // 设置北京时间下午四点
    now.setHours(16, 0, 0, 0);
    // 北京时间转 UTC（北京时间比 UTC 快 8 小时）
    const utcTime = new Date(now.getTime() - 8 * 60 * 60 * 1000);
    const openTime = Math.floor(utcTime.getTime() / 1000);

    // const targetDate = "2025-11-05 16:00:00"; // 北京时间
    // const openTime = Math.floor(new Date(targetDate).getTime() / 1000) ;

    let tx = await Staking.setOpenTime(openTime) ;
    await tx.wait();
    // 设置的时候，请检查一下时间戳对应的时间
    console.log(`Staking setOpenTime ${openTime} `);
}

main().catch((error) => {
    console.error(error);
    process.exitCode = 1;
});
