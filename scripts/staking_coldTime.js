const fs = require("fs");
const path = require("path");
const { ethers, network } = require("hardhat");
require("dotenv").config({ path: path.resolve(__dirname, "..", ".env") });

// 设置质押冷却时间
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
    const  coldTime= 1 ; // 单位秒
    let tx = await Staking.setColdTime(coldTime) ;
    await tx.wait();
    console.log(`Staking setColdTime ${coldTime} `);
}

main().catch((error) => {
    console.error(error);
    process.exitCode = 1;
});
