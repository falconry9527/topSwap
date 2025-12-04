const fs = require("fs");
const path = require("path");
const { ethers, network } = require("hardhat");

async function main() {
    // 直接加载 .env 文件
    const envPath = path.resolve(__dirname, "..", ".env");
    if (!fs.existsSync(envPath)) {
      throw new Error(".env not found");
    }
    require("dotenv").config({ path: envPath });

    // 读取配置参数
    const usdtAddressConf = process.env.USDT_ADRESS;
    if (!usdtAddressConf) throw new Error("USDT_ADRESS is not defined in env");

    const marketingAddressConf = process.env.MARKETING_Address;
    if (!marketingAddressConf) throw new Error("MARKETING_Address is not defined in env");

    const routerAddressConf = process.env.ROUTER_ADRESS;
    if (!routerAddressConf) throw new Error("ROUTER_ADRESS is not defined in env");

    const topAgentAddress = process.env.TOP_AGENT;
    if (!topAgentAddress) throw new Error("TOP_AGENT is not defined in env");

   const adminAddress = process.env.ADMIN_Address;
    if (!adminAddress) throw new Error("ADMIN_Address is not defined in env");
    
    const [deployer] = await ethers.getSigners();
    console.log("Deploying account:", deployer.address);
    console.log("Deploying to network:", network.name);
    console.log(`Loaded env from: .env`);
    console.log("-----------------------------------------");

    // 1. 部署 Referral
    const Referral = await ethers.getContractFactory("Referral");
    const referral = await Referral.deploy(ethers.getAddress(topAgentAddress));
    console.log("Deploying Referral...");
    await referral.waitForDeployment();
    const referralAddress = await referral.getAddress();
    console.log("Referral deployed to:", referralAddress);
    console.log("-----------------------------------------");

    // 2. 部署 NodeNFT
    const url = "https://www.toprotocol.xyz/NFT.png"
    const NodeNFT = await ethers.getContractFactory("NodeNFT");
    const nodeNFT = await NodeNFT.deploy(
        ethers.getAddress(usdtAddressConf),
        ethers.getAddress(marketingAddressConf),
        referralAddress,
        url
    );
    console.log("Deploying NodeNFT...");
    await nodeNFT.waitForDeployment();
    const nodeNFTAddress = await nodeNFT.getAddress();
    console.log("NodeNFT deployed to:", nodeNFTAddress);
    console.log("-----------------------------------------");


}

main().catch((error) => {
    console.error(error);
    process.exitCode = 1;
});
