# TopSwap
# 编译和测试
```
npm install  
npx hardhat clean
npx hardhat compile
```


# 部署
```shell
#  配置修改 .env_temple 修改为 .env , 并修改对应的配置
# 测试环境
npx hardhat run scripts/deploy_bsc.js --network bscTestnet
# 给pancke 新增流动性,TOP 默认70w，USDT 要修改 .env 的 LP_USDT 配置（默认70W）
# npx hardhat run scripts/deploy_lp.js --network bscTestnet
# top 设置开放购买
npx hardhat run scripts/top_presale.js --network bscTestnet

# 主网环境
npx hardhat run scripts/deploy_bsc.js --network bscMainnet
# npx hardhat run scripts/deploy_lp.js --network bscMainnet
npx hardhat run scripts/top_presale.js --network bscMainnet
```


# 配置
```shell
# staking设置交易开放时间
# npx hardhat run scripts/staking_openTime.js --network bscTestnet
# staking设置交易冷冻时间间隔
# npx hardhat run scripts/staking_coldTime.js --network bscTestnet
# staking设置盈利账户
npx hardhat run scripts/staking_marketing.js --network bscTestnet
# staking设置每日交易限额
# npx hardhat run scripts/staking_dayLimit.js --network bscTestnet
# staking设置单笔交易限额
# npx hardhat run scripts/staking_oneLimit.js --network bscTestnet
# staking设置交易时间和费率
# npx hardhat run scripts/staking_rate.js --network bscTestnet
# staking 提现 TOP
npx hardhat run scripts/staking_withdraw.js --network bscTestnet


# nodenft 设置盈利账户
npx hardhat run scripts/nodenft_marketing.js --network bscTestnet
# nodenft 设置每个用户可以买的节点数
# npx hardhat run scripts/nodenft_nodes.js --network bscTestnet
# nodenft 设置 url
npx hardhat run scripts/nodenft_url.js --network bscTestnet

# top 设置开放购买
npx hardhat run scripts/top_presale.js --network bscTestnet
# top 设置交易冷冻时间间隔
# npx hardhat run scripts/top_coldTime.js --network bscTestnet
# top 设置白名单
npx hardhat run scripts/top_white.js --network bscTestnet
# top 设置 每次最小卖出TOP数量
npx hardhat run scripts/top_swap.js --network bscTestnet


```

# 代码验证
```shell
#  会生成  verify 脚本，验证对应的合约代码
npx hardhat run scripts/deploy_verify.js --network bscTestnet

```

# 测试
```shell
# staking 质押
npx hardhat run test/staking_stake.js --network bscTestnet
# staking 查询余额
npx hardhat run test/staking_balance.js --network bscTestnet
# staking 赎回
npx hardhat run test/staking_unstake.js --network bscTestnet

# nft 获取所有的购买节点
npx hardhat run test/nodenft_nodes.js --network bscTestnet
# nft 获取所有的nft归属地址
npx hardhat run test/nodenft_nft.js --network bscTestnet

# top 转账
npx hardhat run test/top_transfer.js --network bscTestnet

# referrals 获取上级代理
npx hardhat run test/referral_referrals.js --network bscTestnet


```


