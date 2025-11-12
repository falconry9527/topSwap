const fs = require("fs");
const path = require("path");
const { ethers, network } = require("hardhat");
require("dotenv").config({ path: path.resolve(__dirname, "..", ".env") });

async function main() {
// 读取部署好的合约信息
const deployedPath = path.resolve(__dirname, "..", "deployed.json");
if (!fs.existsSync(deployedPath)) throw new Error("deployed.json not found");
const deployed = JSON.parse(fs.readFileSync(deployedPath, "utf-8"));
const stakingAddress = deployed.contracts.staking;

// 获取部署者账户  
const [deployer] = await ethers.getSigners();  
console.log("Using account:", deployer.address);  
console.log("Network:", network.name);  
console.log("-----------------------------------------");  

// 获取 Staking 合约实例  
const Staking = await ethers.getContractAt("Staking", stakingAddress);  

// 查询指定账户余额（质押余额 + 奖励）  
const balance = await Staking.balanceOf("0x2A347e307BDA5b4aE56A391DA048333278fa4a9F");  
console.log(`Balance `, ethers.formatUnits(balance, 18), "USDT");  

const isPreacher = await Staking.isPreacher("0x2A347e307BDA5b4aE56A391DA048333278fa4a9F");  
console.log(`isPreacher `,isPreacher );  

}

main().catch((error) => {
console.error(error);
process.exitCode = 1;
});
