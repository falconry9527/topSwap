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
const referralAddress = deployed.contracts.referral;

// 获取部署者账户  
const [deployer] = await ethers.getSigners();  
console.log("Using account:", deployer.address);  
console.log("Network:", network.name);  
console.log("-----------------------------------------");  

// 获取 Staking 合约实例  
const Staking = await ethers.getContractAt("Staking", stakingAddress);  
const referral = await ethers.getContractAt("Referral", referralAddress);  
// 查询最大可质押金额  
const maxAmount = await Staking.maxStakeAmount();  
console.log("Max stake amount:", ethers.formatUnits(maxAmount, 18), "USDT");  

// 设置质押参数（不超过 maxStakeAmount）  
const amount = ethers.parseUnits("10", 18); // 质押 10 USDT  
const amountOutMin = ethers.parseUnits("1", 18);  
const stakeIndex = 0;  

// 授权 staking 合约使用钱包中的 USDT
const usdtAddress = deployed.contracts.usdt; // 如果 deployed.json 有 USDT 地址
const USDT = await ethers.getContractAt("IERC20", usdtAddress);
let tx = await USDT.approve(stakingAddress, amount);
await tx.wait();
console.log("USDT approved for staking contract");

// 调用 stake 方法  
//   tx = await referral.registerUser(deployer.address)
//   await tx.wait();

//  tx = await Staking.stake(amount, amountOutMin, stakeIndex);  
    try {
        const tx = await Staking.stakeWithInviter(amount, amountOutMin, stakeIndex,deployer.address);
        await tx.wait();
        console.log("Stake executed successfully!"
    );
    } catch(error) {
        console.error("Stake failed:", error.reason || error.message);
    }

}

main().catch((error) => {
console.error(error);
process.exitCode = 1;
});
