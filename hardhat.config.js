require("@nomicfoundation/hardhat-toolbox");
require("dotenv").config();

const { PRIVATE_KEY, BSC_MAINNET_RPC, BSC_TESTNET_RPC } = process.env;

if (!PRIVATE_KEY || !BSC_MAINNET_RPC || !BSC_TESTNET_RPC) {
  throw new Error("Please set PRIVATE_KEY, BSC_MAINNET_RPC, and BSC_TESTNET_RPC in .env");
}

module.exports = {
  solidity: {
    version: "0.8.30",
    settings: { optimizer: { enabled: true, runs: 200 },viaIR: true,viaIR: true, }
  },
  networks: {
    hardhat: { chainId: 31337 },

    // BSC 测试网
    bscTestnet: {
      url: BSC_TESTNET_RPC,
      chainId: 97,
      accounts: [PRIVATE_KEY],
      nonceManagement: true
    },

    // BSC 主网
    bscMainnet: {
      url: BSC_MAINNET_RPC,
      chainId: 56,
      accounts: [PRIVATE_KEY]
    }
  }
};