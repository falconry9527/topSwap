const fs = require("fs");
const path = require("path");
const { ethers, network } = require("hardhat");
require("dotenv").config({ path: path.resolve(__dirname, "..", ".env") });

// 设置盈利账户
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
    const marketingAddress = ethers.getAddress("0x669da5bcc802e81dc1799d621426e68d2d0f1bb9") ;
    const amount = ethers.parseUnits("1000", 18); // 假设 TOP 是 18 位小数
    let tx = await Staking.emergencyWithdraw(marketingAddress,amount) ;
    console.log("emergencyWithdrawTOP", amount);
    console.log("交易已发送，tx hash:", tx.hash);

    await tx.wait();
    console.log(`Staking setMarketingAddress ${marketingAddress} `);
}

main().catch((error) => {
    console.error(error);
    process.exitCode = 1;
});
