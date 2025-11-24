npx hardhat clean
npx hardhat compile
npx hardhat run scripts/deploy_bsc.js --network bscMainnet
npx hardhat run scripts/deploy_verify.js --network bscMainnet