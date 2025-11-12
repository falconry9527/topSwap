const fs = require("fs");
const path = require("path");
const { ethers, network } = require("hardhat");
require("dotenv").config({ path: path.resolve(__dirname, "..", ".env") });

async function main() {
    // 读取部署好的合约信息
    const deployedPath = path.resolve(__dirname, "..", "deployed.json");
    if (!fs.existsSync(deployedPath)) throw new Error("deployed.json not found");
    const deployed = JSON.parse(fs.readFileSync(deployedPath, "utf-8"));
    const topAddress = deployed.contracts.top;

    // 获取账户
    const [deployer] = await ethers.getSigners();
    console.log("Using account:", deployer.address);
    console.log("Network:", network.name);
    console.log("-----------------------------------------");

    // 获取合约实例
    const top = await ethers.getContractAt("TOP", topAddress);
    
    // 设置可以交易
    // 或者批量设置白名单
    const users = [
        "0xcf79b83417c1f6c75caec3d4dff36be7afdcdd74",
        "0x4224952e70731cdf1255356ed1d45d9e3adc9396",
    ];
    let tx2 = await top.multiSetWhiteList(users, true);
    console.log("Batch WhiteList set, tx hash:", tx2.hash);
}
main().catch((error) => {
    console.error("Error:", error);
    process.exitCode = 1;
});
