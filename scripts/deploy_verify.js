// scripts/generateAutoVerifyWithComments.js
const fs = require("fs");
const path = require("path");
const { ethers } = require("ethers"); // 用于 address checksum

async function main() {
  // 1️⃣ 读取 deployed.json
  const deployedPath = path.resolve(__dirname, "..", "deployed.json");
  if (!fs.existsSync(deployedPath)) {
    throw new Error("deployed.json not found. Deploy contracts first!");
  }
  const deployed = JSON.parse(fs.readFileSync(deployedPath, "utf8"));
  const network = deployed.network;

  // 2️⃣ 读取 .env 配置
  const envPath = path.resolve(__dirname, "..", ".env");
  if (!fs.existsSync(envPath)) {
    throw new Error(".env file not found!");
  }
  require("dotenv").config({ path: envPath });

  const usdt = ethers.getAddress(process.env.USDT_ADRESS);
  const marketing = ethers.getAddress(process.env.MARKETING_Address);
  const router = ethers.getAddress(process.env.ROUTER_ADRESS);
  const topAgent = ethers.getAddress(process.env.TOP_AGENT);

  // 3️⃣ 生成 verify 命令（带注释）
  const commands = [];

  // Referral
  commands.push(`# ----- Referral -----`);
  commands.push(
    `npx hardhat verify --network ${network} ${deployed.contracts.referral} "${topAgent}"`
  );

  // NodeNFT
  commands.push(`# ----- NodeNFT -----`);
  commands.push(
    `npx hardhat verify --network ${network} ${deployed.contracts.nodeNFT} "${usdt}" "${marketing}" "${deployed.contracts.referral}" "https://www.toprotocol.xyz/NFT.png"`
  );

  // topsClaim
  commands.push(`# ----- topsClaim -----`);
  commands.push(
    `npx hardhat verify --network ${network} ${deployed.contracts.topsClaim} "${deployed.contracts.nodeNFT}" `
  );


  // Divid
  commands.push(`# ----- Divid -----`);
  commands.push(
    `npx hardhat verify --network ${network} ${deployed.contracts.divid} "${usdt}" "${deployed.contracts.nodeNFT}"`
  );

  // Staking
  commands.push(`# ----- Staking -----`);
  commands.push(
    `npx hardhat verify --network ${network} ${deployed.contracts.staking} "${usdt}" "${marketing}" "${router}" "${deployed.contracts.referral}" "${deployed.contracts.divid}"  "${deployed.contracts.nodeNFT}"`
  );

  // TOP
  commands.push(`# ----- TOP -----`);
  commands.push(
    `npx hardhat verify --network ${network} ${deployed.contracts.top} "${usdt}" "${marketing}" "${router}" "${deployed.contracts.referral}" "${deployed.contracts.divid}" "${deployed.contracts.staking}" "${deployed.contracts.topsClaim}"`
  );

  // 4️⃣ 输出到 verify_commands.sh 文件
  const outputPath = path.resolve(__dirname, "..", "verify.sh");
  fs.writeFileSync(outputPath, commands.join("\n"));
  console.log(`✅ Verify commands with comments generated at ${outputPath}`);
  console.log("Run: bash verify.sh");
}

main().catch((err) => {
  console.error(err);
  process.exit(1);
});
