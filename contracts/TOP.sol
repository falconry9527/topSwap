// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {FirstLaunch} from "./abstract/FirstLaunch.sol";
import {Owned} from "./abstract/Owned.sol";
import {IPancakeRouter02} from "./interface/IPancakeRouter02.sol";
import {IPancakePair} from "./interface/IPancakePair.sol";
import {IPancakeFactory} from "./interface/IPancakeFactory.sol";
import {ERC20} from "./abstract/ERC20.sol";
import {ExcludedFromFeeList} from "./abstract/ExcludedFromFeeList.sol";
import {Helper} from "./lib/Helper.sol";
import {IReferral} from "./interface/IReferral.sol";
import {IStaking} from "./interface/IStaking.sol";
import {IDivid} from "./interface/IDivid.sol";

contract Distributor {
    address public parent;

    constructor(address _topAddress) {
        parent = _topAddress;
    }

    function pull(address _usdtAddress, address to) external returns (uint256) {
        require(msg.sender == parent, "only parent");
        IERC20 token = IERC20(_usdtAddress);
        uint256 balance = token.balanceOf(address(this));
        if (balance > 0) {
            token.transfer(to, balance);
        }
        return balance; // 返回实际转出的金额
    }

}


contract TOP is  ExcludedFromFeeList, FirstLaunch, ERC20 {
    bool public liquidityInitialized; // 防止重复初始化
    bool public presale;
    uint40 public coldTime = 1 seconds;

    address public marketingAddress;

    // 每2个代币，卖出到 pankcake 一次
    uint256 public swapAtAmount = 1 ether;

    mapping(address => bool) public rewardList; // 黑名单
    mapping(address => bool) public whiteList; // 白名单

    mapping(address => uint256) public tOwnedU;
    mapping(address => uint40) public lastBuyTime;
    address public STAKING;
    address public REFERRAL;
    address public NODENFT;

    struct POOLUStatus {
        uint112 bal; // pool usdt reserve last time update
        uint40 t; // last update time
    }

    POOLUStatus public poolStatus;
    bool public inSwapAndLiquify;
    modifier lockTheSwap() {
        inSwapAndLiquify = true;
        _;
        inSwapAndLiquify = false;
    }

    function setPresale(bool _presale) external onlyOwner {
        presale = _presale;
        updatePoolReserve();
    }

    function setColdTime(uint40 _coldTime) external onlyOwner {
        coldTime = _coldTime;
    }

    function updatePoolReserve() public {
        require(block.timestamp >= poolStatus.t + 1 minutes, "1 minutes");
        poolStatus.t = uint40(block.timestamp);
        (uint112 reserveU, , ) = IPancakePair(pancakePair).getReserves();
        poolStatus.bal = reserveU;
    }

    function updatePoolReserve(uint112 reserveU) private {
        if (block.timestamp >= poolStatus.t + 1 minutes) {
            poolStatus.t = uint40(block.timestamp);
            poolStatus.bal = reserveU;
        }
    }

    function getReserveU() external view returns (uint112) {
        return poolStatus.bal;
    }

    uint256 public lpFeeAmount;
    uint256 public nftFeeAmount;
    uint256 public nodeFeeAmount;

    address public USDT ;
    address public immutable  pancakePair;
    IPancakeRouter02 public immutable  pancakeV2Router;
    Distributor public immutable  distributor;
    address public dividAdress ;

    /// @param _usdtAddress        支付代币 USDT 的合约地址
    /// @param _marketingAddress   市场合约
    /// @param _routerAddress       IPancake路由地址
    /// @param _referralAddress    上级关系合约
    /// @param _dividAdress        分红合约地址
    constructor(
        address _usdtAddress,
        address _marketingAddress,
        address _routerAddress,
        address _referralAddress,
        address _dividAdress,
        address _stakingAdress,
        address _nodeNFTAddress
    ) Owned(msg.sender) ERC20("TOP", "TOP", 1000000 ether) {
        USDT=_usdtAddress ;
        STAKING = _stakingAdress;
        REFERRAL = _referralAddress;
        marketingAddress = _marketingAddress;
        NODENFT = _nodeNFTAddress ;
        distributor = new Distributor(address(this));
        IERC20(_usdtAddress).approve(address(distributor), type(uint256).max);
        
        pancakeV2Router = IPancakeRouter02(_routerAddress);
        pancakePair = IPancakeFactory(pancakeV2Router.factory()).createPair(address(this), _usdtAddress);
        _approve(address(this), address(pancakeV2Router), type(uint256).max);
        IERC20(_usdtAddress).approve(address(pancakeV2Router), type(uint256).max);

        dividAdress = _dividAdress;
        IERC20(_usdtAddress).approve(dividAdress, type(uint256).max);

        excludeFromFee(msg.sender);
        excludeFromFee(address(this));
        excludeFromFee(STAKING);
        excludeFromFee(dividAdress);
        excludeFromFee(marketingAddress);
        excludeFromFee(NODENFT);
        launch();
    }

    function _transfer(
        address sender,
        address recipient,
        uint256 amount
    ) internal virtual override  {
        require(isReward(sender) == 0, "isReward != 0 !");
        if ( inSwapAndLiquify ||
            _isExcludedFromFee[sender] ||
            _isExcludedFromFee[recipient]
        ) {
            super._transfer(sender, recipient, amount);
            return;
        }
        require(tx.origin == msg.sender || pancakePair == sender|| pancakePair == recipient,"contract");
        if (pancakePair == sender) {
            require(presale || whiteList[recipient], "pre");
            // buy
            unchecked {
                (uint112 reserveU, uint112 reserveThis, ) = IPancakePair(
                    pancakePair
                ).getReserves();
                require(amount <= reserveThis / 10, "max cap buy"); //每次买单最多只能卖池子的10%
                updatePoolReserve(reserveU);
                uint256 amountUBuy = Helper.getAmountIn(
                    amount,
                    reserveU,
                    reserveThis
                );
                tOwnedU[recipient] = tOwnedU[recipient] + amountUBuy;
                lastBuyTime[recipient] = uint40(block.timestamp);

                uint256 burnAmount = (amount * 5) / 1000;
                uint256 lpAmount = (amount * 15) / 1000;
                lpFeeAmount += lpAmount;
                uint256 nftAmount = amount / 100;
                nftFeeAmount += nftAmount;

                super._transfer(sender, address(0xdead), burnAmount);
                super._transfer(sender, address(this), lpAmount + nftAmount);
                super._transfer(sender, recipient, amount - burnAmount - lpAmount - nftAmount);
            }
        } else if (pancakePair == recipient) {
            require(presale || whiteList[sender], "pre");
            require(block.timestamp >= lastBuyTime[sender] + coldTime, "cold");
            //sell
            (uint112 reserveU, uint112 reserveThis, ) = IPancakePair(
                pancakePair
            ).getReserves();
            require(amount <= reserveThis / 10, "max cap sell"); //每次卖单最多只能卖池子的10%

            uint256 burnAmount = (amount * 5) / 1000;
            uint256 lpAmount = (amount * 15) / 1000;
            lpFeeAmount += lpAmount;
            uint256 nftAmount = amount / 100;
            nftFeeAmount += nftAmount;

            uint256 amountUOut = Helper.getAmountOut(
                amount - burnAmount - lpAmount - nftAmount,
                reserveThis,
                reserveU
            );
            updatePoolReserve(reserveU);
            uint256 fee;
            if (tOwnedU[sender] >= amountUOut) {
                unchecked {
                    tOwnedU[sender] = tOwnedU[sender] - amountUOut;
                }
            } else if (tOwnedU[sender] > 0 && tOwnedU[sender] < amountUOut) {
                uint256 profitU = amountUOut - tOwnedU[sender];
                uint256 profitThis = Helper.getAmountOut(
                    profitU,
                    reserveU,
                    reserveThis
                );
                fee = profitThis / 4;
                tOwnedU[sender] = 0;
            } else {
                fee = amount / 4;
                tOwnedU[sender] = 0;
            }
            if (fee > 0) {
                lpFeeAmount += fee * 3 / 5;
                nodeFeeAmount += fee * 2 / 5;
            }
            super._transfer(sender, address(0xdead), burnAmount);
            super._transfer(sender, address(this), lpAmount + nftAmount + fee);
            if (shouldSwapTokenForFund(lpFeeAmount + nftFeeAmount + nodeFeeAmount)) {
                executeLiquidityAndNftAndNodeDividend();
            }
            super._transfer(sender, recipient, amount  - burnAmount - lpAmount - nftAmount - fee);

        } else {
            // normal transfer
            super._transfer(sender, recipient, amount);
        }
    }
        
    function executeLiquidityAndNftAndNodeDividend() internal lockTheSwap {
        uint256 lpFeeHalf = lpFeeAmount / 2;
        uint256 totalFee = lpFeeHalf + nftFeeAmount + nodeFeeAmount;
        if (totalFee == 0) return;

        swapTokenForUsdt(totalFee, address(distributor));
        uint256 totalUSDT = distributor.pull(USDT, address(this));
        if (totalUSDT == 0) return;

        uint256 lpUSDT = (totalUSDT * lpFeeHalf) / totalFee;
        uint256 nftUSDT = (totalUSDT * nftFeeAmount) / totalFee;
        uint256 nodeUSDT = totalUSDT - lpUSDT - nftUSDT;
        if (lpFeeAmount > 0 && lpUSDT > 0) {
            addLiquidity((lpFeeAmount - lpFeeHalf), lpUSDT);
        }
        if (nftUSDT > 0) {
            IDivid(dividAdress).executeNftDividend(nftUSDT);
        }
        if (nodeUSDT > 0) {
            uint256 bal = IERC20(USDT).balanceOf(address(this));
            if (bal < nodeUSDT) nodeUSDT = bal;
            IDivid(dividAdress).executeNodeDividend(nodeUSDT);
        }
        lpFeeAmount = 0;
        nftFeeAmount = 0;
        nodeFeeAmount = 0;
    }



    function shouldSwapTokenForFund(uint256 amount)
        internal
        view
        returns (bool)
    {
        if (amount >= swapAtAmount && !inSwapAndLiquify ) {
            return true;
        } else {
            return false;
        }
    }

    
    function addLiquidity(uint256 tokenAmount, uint256 usdtAmount) internal {
        pancakeV2Router.addLiquidity(
            address(this),
            address(USDT),
            tokenAmount,
            usdtAmount,
            0,
            0,
            address(0xdead),
            block.timestamp
        );
    }

    function swapTokenForUsdt(uint256 tokenAmount, address to) internal {
        unchecked {
            address[] memory path = new address[](2);
            path[0] = address(this);
            path[1] = address(USDT);
            
            // 使用 try-catch 处理可能的错误
            try pancakeV2Router.swapExactTokensForTokensSupportingFeeOnTransferTokens(
                tokenAmount,
                0, // 对于有转账费的代币，设置较低的期望值
                path,
                to,
                block.timestamp
            ) {
                // 交换成功
            } catch Error(string memory reason) {
                revert(string(abi.encodePacked("Swap failed: ", reason)));
            } catch {
                revert("Swap failed with unknown error");
            }
        }
    }

    function recycle(uint256 amount) external {
        require(STAKING == msg.sender, "cycle");
        uint256 maxBurn = balanceOf(pancakePair) / 3;
        uint256 burn_maount = amount >= maxBurn ? maxBurn : amount;
        super._transferInside(pancakePair, STAKING, burn_maount);
        IPancakePair(pancakePair).sync();
    }

    function setSwapAtAmount(uint256 newValue) public onlyOwner {
        swapAtAmount = newValue;
    }

    function setMarketingAddress(address addr) external onlyOwner {
        marketingAddress = addr;
        excludeFromFee(addr);
    }

    function setStaking(address addr) external onlyOwner {
        STAKING = addr;
        excludeFromFee(addr);
    }

    function setWhiteList(address user, bool value) external onlyOwner {
        whiteList[user] = value;
    }

    function multiSetWhiteList(address[] calldata users, bool value) external onlyOwner {
        require(users.length < 201, "too many");
        for(uint i = 0; i < users.length; i++){
            whiteList[users[i]] = value;
        }
    }

    function multi_bclist(address[] calldata addresses, bool value)
        public
        onlyOwner
    {
        require(addresses.length < 201);
        for (uint256 i; i < addresses.length; ++i) {
            rewardList[addresses[i]] = value;
        }
    }

    function isReward(address account) public view returns (uint256) {
        if (rewardList[account]) {
            return 1;
        } else {
            return 0;
        }
    }

    function emergencyWithdrawTOP(address to, uint256 _amount)
        external
        onlyOwner
    {
        transfer(to, _amount);
    }

    function emergencyWithdrawUSDT(address to, uint256 _amount)
        external
        onlyOwner
    {
         IERC20(USDT).transfer(to, _amount);
    }
}
