const { ethers, network } = require("hardhat");

async function main() {
  console.log("Deploying MUSDT to network:", network.name);

  const [deployer] = await ethers.getSigners();
  console.log("Deployer address:", deployer.address);

  const MUSDT = await ethers.getContractFactory("MUSDT");
  const musdt = await MUSDT.deploy();

  await musdt.waitForDeployment();

  const address = await musdt.getAddress();
  console.log("MUSDT deployed at:", address);

  const balance = await musdt.balanceOf(deployer.address);
  console.log("Deployer initial balance:", ethers.formatUnits(balance, 18), "MUSDT");
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
