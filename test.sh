npx hardhat clean
npx hardhat compile
npx hardhat run scripts/deploy_bsc.js --network bscTestnet
npx hardhat run scripts/deploy_lp.js --network bscTestnet


npx hardhat run scripts/top_presale.js --network bscTestnet
npx hardhat run scripts/staking_presale.js --network bscTestnet

npx hardhat run scripts/deploy_verify.js --network bscTestnet
