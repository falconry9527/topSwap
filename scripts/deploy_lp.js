const fs = require("fs");
const path = require("path");
const { ethers, network } = require("hardhat");
require("dotenv").config({ path: path.resolve(__dirname, "..", ".env") });

async function main() {
    // 读取部署好的合约信息
    const deployedPath = path.resolve(__dirname, "..", "deployed.json");
    if (!fs.existsSync(deployedPath)) throw new Error("deployed.json not found");
    const deployed = JSON.parse(fs.readFileSync(deployedPath, "utf-8"));

    const usdtAddress = deployed.contracts.usdt;
    const topAddress = deployed.contracts.top;
    const routerAddress = deployed.contracts.router;

    // 获取部署者账户
    const [deployer] = await ethers.getSigners();
    console.log("Deploying account:", deployer.address);
    console.log("Network:", network.name);
    console.log("-----------------------------------------");

    // 获取 TOP 和 USDT 合约实例
    const TOP = await ethers.getContractAt("TOP", topAddress);
    const USDT = await ethers.getContractAt("IERC20", usdtAddress);
    const Router = await ethers.getContractAt("IPancakeRouter02", routerAddress);

    // 获取 TOP 总发行量（bigint 类型）
    const totalSupply = await TOP.totalSupply();
    // 按比例分配代币
    // const liquidityAmount = totalSupply * 70n / 100n; // 流动性池 70%
    const liquidityAmount = ethers.parseUnits("10", 18);
    // 从 .env 文件读取 USDT 数量（单位：18位小数）
    const lpUsdtValue =  ethers.parseUnits("10", 18); 
    const usdtForLiquidity =  ethers.parseUnits("10", 18);
    console.log(`USDT for liquidity (from .env): ${lpUsdtValue} USDT`);

    // 授权 Router 使用 TOP 和 USDT
    tx = await TOP.approve(routerAddress, liquidityAmount);
    await tx.wait();
    console.log(`Approved Router to spend ${liquidityAmount} TOP`);

    tx = await USDT.approve(routerAddress, usdtForLiquidity);
    await tx.wait();
    console.log(`Approved Router to spend ${usdtForLiquidity} USDT`);

    // 添加流动性
    tx = await Router.addLiquidity(
        topAddress,
        usdtAddress,
        liquidityAmount,
        usdtForLiquidity,
        0, // slippage 最小TOP数量
        0, // slippage 最小USDT数量
        deployer.address, // 接收 LP 的地址
        Math.floor(Date.now() / 1000) + 60 * 10 // 截止时间
    );

    console.log(`TX Hash: ${tx.hash}`);
    console.log(`Liquidity added successfully!`);

}

main().catch((error) => {
    console.error(error);
    process.exitCode = 1;
});
