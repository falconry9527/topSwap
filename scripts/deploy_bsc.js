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

    // 3. 部署 Divid
    const Divid = await ethers.getContractFactory("Divid");
    const divid = await Divid.deploy(
        ethers.getAddress(usdtAddressConf),
        nodeNFTAddress
    );
    console.log("Deploying Divid...");
    await divid.waitForDeployment();
    const dividAddress = await divid.getAddress();
    console.log("Divid deployed to:", dividAddress);
    console.log("-----------------------------------------");

    // 4. 部署 Staking
    const Staking = await ethers.getContractFactory("Staking");
    const staking = await Staking.deploy(
        ethers.getAddress(usdtAddressConf),
        ethers.getAddress(marketingAddressConf),
        ethers.getAddress(routerAddressConf),
        referralAddress,
        dividAddress
    );
    console.log("Deploying Staking...");
    await staking.waitForDeployment();
    const stakingAddress = await staking.getAddress();
    console.log("Staking deployed to:", stakingAddress);
    console.log("-----------------------------------------");

    // 5. 部署 TOP
    const TOP = await ethers.getContractFactory("TOP");
    const top = await TOP.deploy(
        ethers.getAddress(usdtAddressConf),
        ethers.getAddress(marketingAddressConf),
        ethers.getAddress(routerAddressConf),
        referralAddress,
        dividAddress,
        stakingAddress,
        nodeNFTAddress
    );
    console.log("Deploying TOP...");
    await top.waitForDeployment();
    const topAddress = await top.getAddress();
    console.log("TOP deployed to:", topAddress);

    // 调用 pancakePair()
    const pairAddress = await top.pancakePair();
    await top.setWhiteList("0xf129f0e4624548d32007762908f33a7524a8f695",true) ;
    console.log("Pancake Pair address:", pairAddress);
    console.log("-----------------------------------------");

    // 7.1. Staking 设置 TOP 地址
    tx = await staking.setTOP(topAddress);
    await tx.wait();
    console.log(`Staking.setTOP called with: ${topAddress}`);
    console.log("-----------------------------------------");

    // 7.2  NFT 设置 TOP 地址
    tx = await nodeNFT.setTOP(topAddress);
    await tx.wait();
    console.log(`nodeNFT.setTOP called with: ${topAddress}`);
    console.log("-----------------------------------------");

    // 8. 初始化代币给 NodeNFT 和 Staking
    // 获取 TOP 总发行量（bigint 类型）
    const totalSupply = await top.totalSupply();
    // 按比例分配代币
    const perAmount = totalSupply * 10n / 100n; // 节点分配 10%
    const stakingAmount = totalSupply * 20n / 100n; // 节点分配 10%
    const lpAmount = (totalSupply * 70n / 100n) - (1n * 10n ** 18n); // 留 1 TOP
    // 给 NodeNFT 合约分配 10%
    tx = await top.transfer(nodeNFTAddress, perAmount);
    await tx.wait();
    console.log(`Transferred ${perAmount} TOP to NodeNFT`);
    // 给 Staking 合约分配 20%
    tx = await top.transfer(stakingAddress, stakingAmount);
    await tx.wait();
    console.log(`Transferred ${stakingAmount} TOP to Staking`);
    // 给 lp 合约分配 70%
    tx = await top.transfer(ethers.getAddress(marketingAddressConf), lpAmount);
    await tx.wait();
    console.log(`Transferred ${lpAmount} TOP to marketingAddress `);

    // 9.1 转移权限给  管理员
    tx = await referral.transferOwnership(ethers.getAddress(marketingAddressConf));
    await tx.wait();
    console.log(`referral Transferred owner to ${marketingAddressConf}  `);

    tx = await nodeNFT.transferOwnership(ethers.getAddress(marketingAddressConf));
    await tx.wait();
    console.log(`nodeNFT Transferred owner to ${marketingAddressConf}  `);

    tx = await divid.transferOwnership(ethers.getAddress(marketingAddressConf));
    await tx.wait();
    console.log(`divid Transferred owner to ${marketingAddressConf}  `);

    tx = await staking.transferOwnership(ethers.getAddress(marketingAddressConf));
    await tx.wait();
    console.log(`staking Transferred owner to ${marketingAddressConf}  `);

    tx = await top.transferOwnership(ethers.getAddress(marketingAddressConf));
    await tx.wait();
    console.log(`top Transferred owner to ${marketingAddressConf}  `);

    // 9. 写入部署配置文件
    const deployedConfig = {
        network: network.name,
        deployer: deployer.address,
        contracts: {
            usdt: usdtAddressConf,
            referral: referralAddress,
            nodeNFT: nodeNFTAddress,
            divid: dividAddress,
            staking: stakingAddress,
            top: topAddress,
            pair: pairAddress ,
            router: routerAddressConf ,
        }
    };

    const outputPath = path.resolve(__dirname, "..", "deployed.json");
    fs.writeFileSync(outputPath, JSON.stringify(deployedConfig, null, 2));
    console.log(`All deployed addresses saved to ${outputPath}`);

}

main().catch((error) => {
    console.error(error);
    process.exitCode = 1;
});
