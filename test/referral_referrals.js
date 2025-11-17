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
    // 查询的用户地址
    const user = "0xb14045398AaC7B1EFDeCDA9B88144046c038F3f0";
    // 查询几层推荐链（最多 30）
    const depth = 30;
    const referrals = await Referral.getReferrals(user, depth);
    console.log("Referral Chain:", referrals);
}

main().catch((error) => {
    console.error(error);
    process.exitCode = 1;
});
