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

// 查询用户质押记录数量  
const stakeCountBN = await Staking.stakeCount(deployer.address);  
console.log("Total stakes for user:", stakeCountBN.toString());  
const stakeCount = Number(stakeCountBN); 
if (stakeCount === 0) {  
    console.log("No stakes found for this user");  
    return;  
}  

// 选择赎回的质押记录索引（这里选择最后一条）  
const index = stakeCount - 1;  

// 调用 unstake  
const tx = await Staking.unstake(index);  
console.log("Transaction sent:", tx.hash);  

await tx.wait();  
console.log(`Unstaked successfully for index ${index}`);  

// 查询赎回后的余额  
const balance = await Staking.balanceOf(deployer.address);  
console.log(`Updated balance: ${ethers.formatUnits(balance, 18)} USDT`);  

}

main().catch((error) => {
console.error(error);
process.exitCode = 1;
});
