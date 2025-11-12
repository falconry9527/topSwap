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
    const referralAddress = deployed.contracts.referral;

    // 获取部署者账户
    const [deployer] = await ethers.getSigners();
    console.log("Deploying account:", deployer.address);
    console.log("Network:", network.name);
    console.log("-----------------------------------------");

    // 获取 TOP 和 USDT 合约实例
    const Referral = await ethers.getContractAt("Referral", referralAddress);
    const marketingAddress = ethers.getAddress("0x27fBB8D2116A44b8C08c17a215aCFd2Ae37C4c59")
    let tx = await Referral.setMarketingAddress(marketingAddress) ;
    await tx.wait();
    console.log(`Referral setMarketingAddress ${marketingAddress} `);
}

main().catch((error) => {
    console.error(error);
    process.exitCode = 1;
});
