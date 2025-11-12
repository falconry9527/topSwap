// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {UD60x18, ud} from "@prb/math/src/UD60x18.sol";
import {IPancakeRouter02} from "./interface/IPancakeRouter02.sol";
import {IPancakePair} from "./interface/IPancakePair.sol";
import {ITOP} from "./interface/ITOP.sol";
import {IReferral} from "./interface/IReferral.sol";
import {Owned} from "./abstract/Owned.sol";
import {IPancakeFactory} from "./interface/IPancakeFactory.sol";
import {IDivid} from "./interface/IDivid.sol";

contract Staking is Owned {
    event Staked(
        address indexed user,
        uint256 amount,
        uint256 timestamp,
        uint256 index,
        uint256 stakeTime
    );

    event RewardPaid(
        address indexed user,
        uint256 reward,
        uint40 timestamp,
        uint256 index
    );
    event Transfer(address indexed from, address indexed to, uint256 amount);

    uint256[2] rates = [1000000034670200000,1000000143330000000]; 
    uint256[2] stakeDays = [1 days,30 days];  

    IPancakeRouter02 public ROUTER ;
    IERC20 public USDT ;

    ITOP public TOP;

    IReferral public REFERRAL;

    address marketingAddress;

    uint8 public constant decimals = 18;
    string public constant name = "Computility";
    string public constant symbol = "cpm";

    uint256 public totalSupply;
    // 用户usdt 余额
    mapping(address => uint256) public balances;
    mapping(address => uint256) public userIndex;
    mapping(address => uint256) public balances30 ;

    // 用户质押记录,团队业绩
    mapping(address => Record[]) public userStakeRecord;
    mapping(address => Record[]) public userUnStakeRecord;
    mapping(address => uint256) public teamTotalInvestValue;
    mapping(address => uint256) public teamVirtuallyInvestValue;
    uint8 immutable maxD = 30 ;
    address public dividAdress ;

    // 全局质押记录
    RecordTT[] public t_supply;

    // === 限额控制 ===
    uint256[9] public dailyLimits; // 单位：U * 1e18
    uint256[3] public oneLimits; // 单位：U * 1e18
    
    uint256 public openTime; // 交易开始时间

    mapping(uint256 => uint256) public dailyStakeAmount; // 记录每天已质押总额 (key=天序号)
    struct RecordTT {
        uint40 stakeTime;
        uint256 tamount;
    }
    struct Record {
        uint40 stakeTime;
        uint256 amount;
        uint256 reward;
        uint40 status; // 赎回进度 0 ： 等待赎回（还未到期） 1：立即赎回（到期可以赎回） 2 ：已赎回
        uint8 stakeIndex;
        uint256 index;
    }
    mapping(address => uint40) public lastTxTime;
    uint256 public  coldTime = 1 ; // 60秒冷却时间，可根据需求调整

    //只允许用户直接质押
    modifier onlyEOA() {
        require(tx.origin == msg.sender, "EOA");
        _;
    }
    // 交易冷却 ---
    modifier txCold() {
     require(block.timestamp - lastTxTime[msg.sender] >= coldTime, "cold");
       _;
    }
    /// @param _usdtAddress        支付代币 USDT 的合约地址
    /// @param _marketingAddress   市场合约
    /// @param _routerAddress       IPancake路由地址
    /// @param _referralAddress    上级关系合约
    /// @param _dividAdress        分红合约地址
    constructor(
        address _usdtAddress,
        address _marketingAddress ,
        address _routerAddress,
        address _referralAddress,
        address _dividAdress
    )  Owned(msg.sender) {
        REFERRAL = IReferral(_referralAddress);
        marketingAddress = _marketingAddress;
        USDT = IERC20(_usdtAddress);

        dividAdress = _dividAdress ;
        USDT.approve(dividAdress, type(uint256).max);

        ROUTER = IPancakeRouter02(_routerAddress);
        USDT.approve(address(ROUTER), type(uint256).max);

        // 部署第二天的 下午16:00 开放交易
        openTime = ((block.timestamp + 8 hours) / 1 days * 1 days)  // 今天 0:00 北京时间
              + 1 days                                         // 第二天 0:00 北京时间
              + 16 hours                                       // 第二天 16:00 北京时间
              - 8 hours;                                       // 转回 UTC 时间

        dailyLimits = [
            30000 * 1e18,
            50000 * 1e18,
            100000 * 1e18,
            200000 * 1e18,
            300000 * 1e18,
            400000 * 1e18,
            500000 * 1e18,
            600000 * 1e18,
            type(uint256).max // 无限额
        ];

        oneLimits = [
            200 * 1e18,
            500 * 1e18,
            1000 * 1e18 
        ];
    }

    // 设置开放交易时间（单位：秒，UTC 时间戳）
    function setOpenTime(uint256 _openTime) external onlyOwner {
        openTime = _openTime;
    }

    function setTOP(address _topAddress) external onlyOwner {
        TOP = ITOP(_topAddress);
        TOP.approve(address(ROUTER), type(uint256).max);
    }

    function setTeamVirtuallyInvestValue(address _user, uint256 _value)
        external
        onlyOwner
    {
        teamVirtuallyInvestValue[_user] = _value;
    }

    function setMarketingAddress(address _account) external  onlyOwner{
        marketingAddress = _account;
    }

    function network1In() public view returns (uint256 value) {
        uint256 len = t_supply.length;
        if (len == 0) return 0;
        uint256 one_last_time = block.timestamp - 1 minutes;
        uint256 last_supply = totalSupply;
        //       |
        // t0 t1 | t2 t3 t4 t5
        //       |
        for (uint256 i = len - 1; i >= 0; i--) {
            RecordTT storage stake_tt = t_supply[i];
            if (one_last_time > stake_tt.stakeTime) {
                break;
            } else {
                last_supply = stake_tt.tamount;
            }
            if (i == 0) break;
        }
        return totalSupply - last_supply;
    }


    function stake(uint256 _amount, uint256 amountOutMin,uint8 _stakeIndex) external onlyEOA txCold {
        require(_amount >= 1e18, "amount < 1");
        require(_amount <= maxStakeAmount(), "Exceed limit");
        require(_stakeIndex<=1,"<=1");
        require(canStakeNow(msg.sender) || currentDayIndex()>=120 ,"Exceed limit");
        if (_stakeIndex == 1) { // 30天质押需要限额
            uint256 today = currentDayIndex();
            require(dailyStakeAmount[today] + _amount <= getDayLimit(), "Exceed daily limit");
            dailyStakeAmount[today] += _amount;
        }
        swapAndAddLiquidity(_amount, amountOutMin);
        mint(msg.sender, _amount,_stakeIndex);
        lastTxTime[msg.sender]=uint40(block.timestamp);
    }

    function stakeWithInviter(
        uint256 _amount,
        uint256 amountOutMin,
        uint8 _stakeIndex,
        address parent
    ) external onlyEOA txCold {
        require(_amount >= 1e18, "amount < 1");
        require(_amount <= maxStakeAmount(), "Exceed limit");
        require(_stakeIndex<=1,"<=1");
        require(canStakeNow(msg.sender) || currentDayIndex()>=120 ,"Exceed limit");

        if (_stakeIndex == 1) { // 30天质押需要限额
            uint256 today = currentDayIndex();
            uint256 currentLimit = getDayLimit();
            require(dailyStakeAmount[today] + _amount <= currentLimit, "Exceed daily limit");
            dailyStakeAmount[today] += _amount;
        }
        swapAndAddLiquidity(_amount, amountOutMin);
        address user = msg.sender;
        if (!REFERRAL.isBindReferral(user) && REFERRAL.isBindReferral(parent)) {
            REFERRAL.bindReferral(parent, user);
        }
        mint(user, _amount,_stakeIndex);
        lastTxTime[msg.sender]=uint40(block.timestamp);
    }

    function swapAndAddLiquidity(uint256 _amount, uint256 amountOutMin)
        private
    {
        USDT.transferFrom(msg.sender, address(this), _amount);

        address[] memory path = new address[](2);
        path = new address[](2);
        path[0] = address(USDT);
        path[1] = address(TOP);
        uint256 balb = TOP.balanceOf(address(this));
        ROUTER.swapExactTokensForTokensSupportingFeeOnTransferTokens(
            _amount / 2,
            amountOutMin,
            path,
            address(this),
            block.timestamp
        );
        uint256 bala = TOP.balanceOf(address(this));
        ROUTER.addLiquidity(
            address(USDT),
            address(TOP),
            _amount / 2,
            bala - balb,
            0, // slippage is unavoidable
            0, // slippage is unavoidable
            address(0), // 不需要 LP token,直接销毁
            block.timestamp
        );
    }

    function mint(address sender, uint256 _amount,uint8 _stakeIndex) private {
        require(REFERRAL.isBindReferral(sender),"!!bind");
        RecordTT memory tsy;
        tsy.stakeTime = uint40(block.timestamp);
        tsy.tamount = uint256(totalSupply);
        t_supply.push(tsy);

        Record memory order;
        order.stakeTime = uint40(block.timestamp);
        order.amount = _amount;
        order.status = 0;
        order.reward=0;
        order.stakeIndex = _stakeIndex;
  
        totalSupply += _amount;
        balances[sender] += _amount;
        if(_stakeIndex==1 && _amount>=100e18){
         balances30[sender] += 1;
        }
        Record[] storage cord = userStakeRecord[sender];
        uint256 stake_index = cord.length;
        order.index = stake_index ;
        cord.push(order);

        address[] memory referrals = REFERRAL.getReferrals(sender, maxD);
        for (uint8 i = 0; i < referrals.length; i++) {
            teamTotalInvestValue[referrals[i]] += _amount;
        }
        emit Transfer(address(0), sender, _amount);
        emit Staked(sender, _amount, block.timestamp, stake_index,stakeDays[_stakeIndex]);
    }

    function balanceOf(address account)
        external
        view
        returns (uint256 balance)
    {
        Record[] storage cord = userStakeRecord[account];
        if (cord.length > 0) {
            for (uint256 i = cord.length - 1; i >= 0; i--) {
                Record storage user_record = cord[i];
                if (user_record.status < 2) {
                    balance += caclItem(user_record);
                }
                // else {
                //     continue;
                // }
                if (i == 0) break;
            }
        }
    }
    function caclItem(Record storage user_record)
        private
        view
        returns (uint256 reward)
    {
        UD60x18 stake_amount = ud(user_record.amount);
        uint40 stake_time = user_record.stakeTime;
        uint40 stake_period = (uint40(block.timestamp) - stake_time);
        stake_period = Math.min(stake_period, uint40(stakeDays[user_record.stakeIndex]));
        if (stake_period == 0) reward = UD60x18.unwrap(stake_amount);
        else
            reward = UD60x18.unwrap(
                stake_amount.mul(ud(rates[user_record.stakeIndex]).powu(stake_period))
            );
    }

    function rewardOfSlot(address user, uint8 index)
        public
        view
        returns (uint256 reward)
    {
        Record storage user_record = userStakeRecord[user][index];
        return caclItem(user_record);
    }

    function stakeCount(address user) external view returns (uint256 count) {
        count = userStakeRecord[user].length;
    }

    function getUserStakeRecords() external view returns (Record[] memory records) {
        Record[] storage allRecords = userStakeRecord[msg.sender];
        uint256 total = allRecords.length;
        uint256 count;
        // 先统计需要的数量
        for (uint256 i = 0; i < total; i++) {
            if (allRecords[i].status < 2) {
                count++;
            }
        }
        // 初始化 memory 数组
        records = new Record[](count);
        uint256 idx;
        for (uint256 i = 0; i < total; i++) {
            Record storage user_record = allRecords[i];
            if (user_record.status < 2) {
                Record memory tempRecord = user_record;
                uint256 stakeTime = user_record.stakeTime;
                uint256 stakeDuration = stakeDays[user_record.stakeIndex];
                // 到期未赎回
                if (block.timestamp - stakeTime >= stakeDuration && user_record.status < 2) {
                    tempRecord.status = 1;
                }
                tempRecord.reward = caclItem(user_record);
                records[idx] = tempRecord;
                idx++;
            }
        }
    }

    function unstakeCount(address user) external view returns (uint256 count) {
        // 返回用户已赎回的质押记录数量
        count = userUnStakeRecord[user].length;
    }

    function getUserUnStakeRecords() external view returns (Record[] memory) {
        Record[] storage allRecords = userUnStakeRecord[msg.sender];
        uint256 total = allRecords.length;
        // 如果记录少于等于100条，直接返回全部
        if (total <= 100) {
            return allRecords;
        }
        // 否则返回最后100条
        Record[] memory last100 = new Record[](100);
        for (uint256 i = 0; i < 100; i++) {
            last100[i] = allRecords[total - 100 + i];
        }
        return last100;
    }

    function unstake(uint256 index) external onlyEOA txCold returns (uint256)   {
        (uint256 reward, uint256 stake_amount) = burn(index);
        uint256 bal_this = TOP.balanceOf(address(this));
        uint256 usdt_this = USDT.balanceOf(address(this));
        address[] memory path = new address[](2);
        path = new address[](2);
        path[0] = address(TOP);
        path[1] = address(USDT);
        ROUTER.swapTokensForExactTokens(
            reward, //  目标输出数量
            bal_this, // 最大输入数量
            path,
            address(this),
            block.timestamp
        );
        uint256 bal_now = TOP.balanceOf(address(this));
        uint256 usdt_now = USDT.balanceOf(address(this));
        uint256 amount_TOP = bal_this - bal_now;
        uint256 amount_usdt = usdt_now - usdt_this;
        uint256 interset;
        if (amount_usdt > stake_amount) {
            interset = amount_usdt - stake_amount;
        }

        // 5% 直推奖励,直接发放
        uint256 referral_fee = referralReward(msg.sender, interset);
        address[] memory referrals = REFERRAL.getReferrals(msg.sender, maxD);
        for (uint8 i = 0; i < referrals.length; i++) {
            teamTotalInvestValue[referrals[i]] -= stake_amount;
        }
        // 20% 按团队等级分配
        uint256 team_fee = teamReward(referrals,interset);

        // 5% 节点分红
        uint256 node_divide = nodeDivide(interset);
        
        // 70% 给用户
        Record[] storage cord = userStakeRecord[msg.sender];
        Record storage user_record = cord[index];
        user_record.reward= amount_usdt - referral_fee - team_fee - node_divide ;
        USDT.transfer(msg.sender, amount_usdt - referral_fee - team_fee - node_divide );

        TOP.recycle(amount_TOP);

        userUnStakeRecord[msg.sender].push(user_record);
        lastTxTime[msg.sender]=uint40(block.timestamp);
        return reward;
    }

    function burn(uint256 index)
        private
        returns (uint256 reward, uint256 amount)
    {
        address sender = msg.sender;
        Record[] storage cord = userStakeRecord[sender];
        Record storage user_record = cord[index];

        uint256 stakeTime = user_record.stakeTime;
        require(block.timestamp - stakeTime >= stakeDays[user_record.stakeIndex], "The time is not right");
        require(user_record.status < 2, "alw");

        amount = user_record.amount;
        totalSupply -= amount;
        balances[sender] -= amount;
        if(user_record.stakeIndex ==1 && amount >= 100e18){
         balances30[sender] -= 1;
        }

        emit Transfer(sender, address(0), amount);

        reward = caclItem(user_record);
        user_record.status = 2;

        userIndex[sender] = userIndex[sender] + 1;

        emit RewardPaid(sender, reward, uint40(block.timestamp), index);
    }

    function getTeamKpi(address _user) public view returns (uint256) {
        return teamTotalInvestValue[_user] + teamVirtuallyInvestValue[_user];
    }

    function isPreacher(address user) public view returns (bool) {
        return balances30[user] >= 1;
    }

    function referralReward(
        address _user,
        uint256 _interset
    ) private returns (uint256 fee) {
        fee = (_interset * 5) / 100;
        address up = REFERRAL.getReferral(_user);
        if (up != address(0) && isPreacher(up)) {
            USDT.transfer(up, fee);
        }else{
            USDT.transfer(marketingAddress, fee);
        }
    }
    
    function nodeDivide(uint256 _interset)
        private
        returns (uint256 divide)
    {
       divide = (_interset * 5) / 100;
       IDivid(dividAdress).executeNodeDividend(divide);
    }

    function teamReward(address[] memory referrals, uint256 _interset)
        private
        returns (uint256 fee)
    {
        address top_team;
        uint256 team_kpi;
        uint256 maxTeamRate = 20;
        uint256 spendRate = 0;
        fee = (_interset * maxTeamRate) / 100;
        for (uint256 i = 0; i < referrals.length; i++) {
            top_team = referrals[i];
            team_kpi = getTeamKpi(top_team);
            if (
                team_kpi >= 700000 * 10**18 &&
                    maxTeamRate > spendRate &&
                    isPreacher(top_team)
            ) {
                USDT.transfer(
                    top_team,
                    (_interset * (maxTeamRate - spendRate)) / 100
                );
                spendRate = 20;
            }

            if (
                team_kpi >= 300000 * 10**18 &&
                    team_kpi < 1000000 * 10**18 &&
                    spendRate < 16 &&
                    isPreacher(top_team)
            ) {
                USDT.transfer(top_team, (_interset * (16 - spendRate)) / 100);
                spendRate = 16;
            }

            if (
                team_kpi >= 100000 * 10**18 &&
                    team_kpi < 500000 * 10**18 &&
                    spendRate < 12 &&
                    isPreacher(top_team)
            ) {
                USDT.transfer(top_team, (_interset * (12 - spendRate)) / 100);
                spendRate = 12;
            }

            if (
                team_kpi >= 50000 * 10**18 &&
                    team_kpi < 100000 * 10**18 &&
                    spendRate < 8 &&
                    isPreacher(top_team)
            ) {
                USDT.transfer(top_team, (_interset * (8 - spendRate)) / 100);
                spendRate = 8;
            }

            if (
                team_kpi >= 10000 * 10**18 &&
                    team_kpi < 50000 * 10**18 &&
                    spendRate < 4 &&
                    isPreacher(top_team)
            ) {
                USDT.transfer(top_team, (_interset * (4 - spendRate)) / 100);
                spendRate = 4;
            }
        }
        if (maxTeamRate > spendRate) {
            USDT.transfer(marketingAddress, fee - ((_interset * spendRate) / 100));
        }
    }

    function sync() external {
        uint256 w_bal = IERC20(USDT).balanceOf(address(this));
        address pair = TOP.pancakePair();
        IERC20(USDT).transfer(pair, w_bal);
        IPancakePair(pair).sync();
    }

    function emergencyWithdrawTOP(address to, uint256 _amount)
        external
        onlyOwner
    {
        TOP.transfer(to, _amount);
    }

    function emergencyWithdrawUSDT(address to, uint256 _amount)
        external
        onlyOwner
    {
         IERC20(USDT).transfer(to, _amount);
    }

    function currentDayIndex() public view returns (uint256 dayIndex) {
        // 调整为北京时间
        uint256 timeInBeijing = block.timestamp + 8 hours;
        // 从合约部署开始，按16:00为界限
        uint256 delta = timeInBeijing - openTime - 8 hours + 16 hours;
        dayIndex = delta / 1 days ;
    }
    
    function getDayLimit() public view returns (uint256 limit) {
        uint256 dayIndex = currentDayIndex();
        uint256 stage = dayIndex / 15; // 每15天一个阶段
        if (stage >= 8) return dailyLimits[8];
        return dailyLimits[stage];
    }
    
    function maxStakeDayAmount() public view returns (uint256 limit) {
        if(block.timestamp < openTime ){
           return 0 ;
        }
        // 返回用户已赎回的质押记录数量
        uint256  maxDayAmount = getDayLimit()-dailyStakeAmount[currentDayIndex()] ;
        if(maxDayAmount < 0){
            maxDayAmount = 0 ;
        }
        return maxDayAmount ;
    }

    function maxStakeAmount() public view returns (uint256 limit) {
        if(block.timestamp < openTime ){
           return 0 ;
        }
        uint256 dayIndex = currentDayIndex();
        uint256 stage = dayIndex / 15; // 每15天一个阶段
        if (stage >= 2) return oneLimits[2];
        return oneLimits[stage];
    }

    function setDailyLimits(uint256[8] calldata _limits) external onlyOwner {
        for (uint256 i = 0; i < 8; i++) {
            dailyLimits[i] = _limits[i] * 1e18; // 传U，内部转wei
        }
    }
    function setOneLimits(uint256[3] calldata _limits) external onlyOwner {
        for (uint256 i = 0; i < 3; i++) {
            oneLimits[i] = _limits[i] * 1e18; // 传U，内部转wei
        }
    }


    function canStakeNow(address user) public view returns (bool) {
        uint256 beijingTime = block.timestamp + 8 hours;
        uint256 secondsInDay = beijingTime % 1 days;
        uint256 startTime = 16 hours;        // 16:00
        uint256 endTime = 16 hours + 1 minutes; // 16:01
        if (secondsInDay >= startTime && secondsInDay <= endTime) {
            if (balances[user]>= 500 * 1e18) {
                return true;
            } else {
                return false;
            }
        }
        return true;
    }

    // 获取上级用户
    function getReferral() external view returns (address) {
     return REFERRAL.getReferral(msg.sender);
    }

    function setColdTime(uint256 _coldTime) external onlyOwner {
        coldTime = _coldTime;
    }
    
    // 设置单个 rate
    function setRate(uint256 index, uint256 newRate) external onlyOwner {
        require(index < rates.length, "invalid index");
        rates[index] = newRate;
    }

    // 设置单个 stakeDays
    function setStakeDay(uint256 index, uint256 newStakeDay) external onlyOwner {
        require(index < stakeDays.length, "invalid index");
        stakeDays[index] = newStakeDay;
    }


}

library Math {
    /**
     * @dev Returns the smallest of two numbers.
     */
    function min(uint40 a, uint40 b) internal pure returns (uint40) {
        return a < b ? a : b;
    }

    function min256(uint256 a, uint256 b) internal pure returns (uint256) {
        return a < b ? a : b;
    }
}