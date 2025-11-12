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

    // 设置卖单后面跟着的最大卖单
    const maxSwapAtAmount= ethers.parseUnits("4", 18)
    await top.setSwapAtAmount(maxSwapAtAmount);

    console.log("setMaxSwapAtAmount:",maxSwapAtAmount);

}
main().catch((error) => {
    console.error("Error:", error);
    process.exitCode = 1;
});
