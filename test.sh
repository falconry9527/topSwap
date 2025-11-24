npx hardhat clean
npx hardhat compile
npx hardhat run scripts/deploy_bsc.js --network bscTestnet
npx hardhat run scripts/deploy_verify.js --network bscTestnet