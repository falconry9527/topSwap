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
import "@openzeppelin/contracts/access/Ownable.sol";

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
        return balance; 
    }
}


contract TOP  is Owned,ExcludedFromFeeList, FirstLaunch, ERC20 {
    bool public liquidityInitialized; 
    bool public presale;

    address public marketingAddress;

    uint256 public swapAtAmount = 1 ether;
    mapping(address => bool) public whiteList; 

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

    function setPresale() external onlyOwner {
        presale = true;
        updatePoolReserve();
        launch();
    }
    function updatePoolReserve() public {
        require(block.timestamp >= poolStatus.t + 10 minutes, "1 minutes");
        poolStatus.t = uint40(block.timestamp);
        (uint112 reserveU, , ) = IPancakePair(pancakePair).getReserves();
        poolStatus.bal = reserveU;
    }

    function updatePoolReserve(uint112 reserveU) private {
        if (block.timestamp >= poolStatus.t + 10 minutes) {
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
    uint256 public highFeeAmount;

    address public USDT ;
    address public immutable  pancakePair;
    IPancakeRouter02 public immutable  pancakeV2Router;
    Distributor public immutable  distributor;
    address public dividAdress ;
    uint40 public coldTime = 0 seconds;
    uint40 public highTaxDuration = 30;   
    uint16 public highTaxPercent = 25;    

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
    }

    function _transfer(
        address sender,
        address recipient,
        uint256 amount
    ) internal virtual override  {
        if ( inSwapAndLiquify ||
            _isExcludedFromFee[sender] ||
            _isExcludedFromFee[recipient]
        ) {
            super._transfer(sender, recipient, amount);
            return;
        }
        require(tx.origin == msg.sender || pancakePair == sender|| pancakePair == recipient,"contract");
        bool isHighFee = (launchedAtTimestamp > 0 && uint40(block.timestamp) <= launchedAtTimestamp + highTaxDuration );

        if (pancakePair == sender) {
            require(presale || whiteList[recipient], "pre");
            // buy
            unchecked {
                (uint112 reserveU, uint112 reserveThis, ) = IPancakePair(
                    pancakePair
                ).getReserves();
                require(amount <= reserveThis / 10, "max cap buy"); 
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
                uint256 highAmount;
                lpFeeAmount += lpAmount;
                uint256 nftAmount = amount / 100;
                nftFeeAmount += nftAmount;
                if (isHighFee) {
                    highAmount = (amount * highTaxPercent) / 100;
                    highFeeAmount+= highAmount;
                }
                super._transfer(sender, address(0xdead), burnAmount);
                super._transfer(sender, address(this), lpAmount + nftAmount + highAmount);
                super._transfer(sender, recipient, amount - burnAmount - lpAmount - nftAmount - highAmount);
            }
        } else if (pancakePair == recipient) {
            require(presale || whiteList[sender], "pre");
            require(uint40(block.timestamp) >= lastBuyTime[sender] + coldTime, "cold");
            //sell
            (uint112 reserveU, uint112 reserveThis, ) = IPancakePair(
                pancakePair
            ).getReserves();
            require(amount <= reserveThis / 10, "max cap sell"); 

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
            uint256 highAmount;
            if (isHighFee) {
                highAmount = (amount * highTaxPercent) / 100;
                highFeeAmount+= highAmount;
            }
            super._transfer(sender, address(0xdead), burnAmount);
            super._transfer(sender, address(this), lpAmount + nftAmount + fee + highAmount);
            if (shouldSwapTokenForFund(lpFeeAmount + nftFeeAmount + nodeFeeAmount + highAmount)) {
                executeLiquidityAndNftAndNodeDividend();
            }
            super._transfer(sender, recipient, amount  - burnAmount - lpAmount - nftAmount - fee - highAmount);

        } else {
            // normal transfer
            super._transfer(sender, recipient, amount);
        }
    }


        
    function executeLiquidityAndNftAndNodeDividend() internal lockTheSwap {
        uint256 lpFeeHalf = lpFeeAmount / 2;
        uint256 totalFee = lpFeeHalf + nftFeeAmount + nodeFeeAmount + highFeeAmount;
        if (totalFee == 0) return;

        swapTokenForUsdt(totalFee, address(distributor));
        uint256 totalUSDT = distributor.pull(USDT, address(this));
        if (totalUSDT == 0) return;

        uint256 lpUSDT = (totalUSDT * lpFeeHalf) / totalFee;
        uint256 nftUSDT = (totalUSDT * nftFeeAmount) / totalFee;
        uint256 nodeUSDT = (totalUSDT * nodeFeeAmount) / totalFee;
        uint256 highFeeUSDT = totalUSDT - lpUSDT - nftUSDT - nodeUSDT;

        if (lpUSDT > 0) {
            addLiquidity((lpFeeAmount - lpFeeHalf), lpUSDT);
        }
        if (nftUSDT > 0) {
            uint256 bal = IERC20(USDT).balanceOf(address(this));
            if (bal < nftUSDT) nftUSDT = bal;
            IDivid(dividAdress).executeNftDividend(nftUSDT);
        }
        if (nodeUSDT > 0) {
            uint256 bal = IERC20(USDT).balanceOf(address(this));
            if (bal < nodeUSDT) nodeUSDT = bal;
            IDivid(dividAdress).executeNodeDividend(nodeUSDT);
        }
        if (highFeeUSDT > 0) {
            uint256 bal = IERC20(USDT).balanceOf(address(this));
            if (bal < highFeeUSDT) highFeeUSDT = bal;
            IERC20(USDT).transfer(marketingAddress, highFeeUSDT);
        }

        lpFeeAmount = 0;
        nftFeeAmount = 0;
        nodeFeeAmount = 0;
        highFeeAmount = 0;

    }

    function setHighTaxDuration(uint40 _durationSeconds) external onlyOwner {
        require(_durationSeconds <= 8 hours, "duration <= 8 hour");
        highTaxDuration = _durationSeconds;
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
            pancakeV2Router.swapExactTokensForTokensSupportingFeeOnTransferTokens(
                tokenAmount,
                0, 
                path,
                to,
                block.timestamp
            );
        }
    }

    function recycle(uint256 amount) external {
        require(STAKING == msg.sender, "cycle");
        uint256 maxBurn = balanceOf(pancakePair) / 3;
        uint256 burn_maount = amount >= maxBurn ? maxBurn : amount;
        super._transferInside(pancakePair, STAKING, burn_maount);
        IPancakePair(pancakePair).sync();
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

    function setWhiteListBatch(address[] calldata users, bool value) external onlyOwner {
        for (uint256 i = 0; i < users.length; i++) {
            whiteList[users[i]] = value ;
        }
    }

    function setColdTime(uint40 value) external onlyOwner {
        require(value <= 5 minutes, "coldTime must <= 5 minutes");
        coldTime = value;
    }
    /**
     * @dev 返回 1 TOP 价值多少 USDT（18位精度）
     */
    function getPrice() external view returns (uint256) {
        (uint112 reserve0, uint112 reserve1, ) = IPancakePair(pancakePair).getReserves();
        address token0 = IPancakePair(pancakePair).token0(); 
        uint256 reserveTOP;
        uint256 reserveUSDT;
        if (token0 == address(this)) {
            reserveTOP = reserve0;
            reserveUSDT = reserve1;
        } else {
            reserveTOP = reserve1;
            reserveUSDT = reserve0;
        }
        // price = reserveUSDT / reserveTOP
        require(reserveTOP > 0, "NO_LIQ");
        return (reserveUSDT * 1e18) / reserveTOP;
    }
}
