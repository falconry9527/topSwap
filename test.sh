npx hardhat clean
npx hardhat compile
npx hardhat run scripts/deploy_bsc.js --network bscTestnet
npx hardhat run scripts/deploy_lp.js --network bscTestnet

# npx hardhat run scripts/top_presale.js --network bscTestnet
# npx hardhat run scripts/top_coldTime.js --network bscTestnet
# npx hardhat run scripts/nodenft_nodes.js --network bscTestnet // setUserCanBuyNode

# npx hardhat run scripts/staking_openTime.js --network bscTestnet
# npx hardhat run scripts/staking_dayLimit.js --network bscTestnet
# npx hardhat run scripts/staking_oneLimit.js --network bscTestnet
# npx hardhat run scripts/staking_rate.js --network bscTestnet
