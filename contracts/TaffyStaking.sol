// SPDX-License-Identifier: MIT
pragma solidity ^0.8;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "./interfaces/IUniswapV2Router.sol";
// import "./interfaces/IUniswapV3Router.sol";
// import '@uniswap/v3-periphery/contracts/libraries/TransferHelper.sol';
// import '@uniswap/v3-periphery/contracts/interfaces/ISwapRouter.sol';

// There's 6 functions:
// 1. setRewardsDuration => set how long the staking process will go for
// 2. notifyRewardAmount
// 3. stake => deposit to staking pool
// 4. withdraw => withdraw from staking pool
// 5. earned => shows how much rwards an address has been earned
// 6. getReward => claim the reward

contract TaffyStaking is Ownable {
    IERC20 public immutable stakingToken;
    IERC20 public immutable rewardsToken;
    // ISwapRouter public uniswap = ISwapRouter(0xE592427A0AEce92De3Edee1F18E0157C05861564);
    // IUniswapV2Router public uniswap = IUniswapV2Router(0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D);
    IUniswapV2Router public uniswap = IUniswapV2Router(0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D);

    // address public constant WETH9 = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;
    // IERC20 public WETH = IERC20(0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2);
    IERC20 public WETH = IERC20(0xB4FBF271143F4FBf7B91A5ded31805e42b2208d6); // Goerli
    IERC20 public TFY = IERC20(0x6De6A91eB63673e63852e67aACF86D98C1B80531);


    // Duration of rewards to be paid out (in seconds)
    uint public duration;
    // Timestamp of when the rewards finish
    uint public finishAt;
    // Minimum of last updated time and reward finish time
    uint public updatedAt;
    // Reward to be paid out per second
    uint public rewardRate;
    // Sum of (reward rate * dt * 1e18 / total supply)
    uint public rewardPerTokenStored;
    // User address => rewardPerTokenStored
    mapping(address => uint) public userRewardPerTokenPaid;
    // User address => rewards to be claimed
    mapping(address => uint) public rewards;

    // Total staked
    uint public totalSupply;
    // User address => staked amount
    mapping(address => uint) public balanceOf;

    constructor(address _stakingToken, address _rewardToken) {
        stakingToken = IERC20(_stakingToken);
        rewardsToken = IERC20(_rewardToken);
    }

    modifier updateReward(address _account) {
        rewardPerTokenStored = rewardPerToken();
        updatedAt = lastTimeRewardApplicable();

        if (_account != address(0)) {
            rewards[_account] = earned(_account);
            userRewardPerTokenPaid[_account] = rewardPerTokenStored;
        }

        _;
    }

    function lastTimeRewardApplicable() public view returns (uint) {
        return finishAt <= block.timestamp ? finishAt : block.timestamp;
    }

    function rewardPerToken() public view returns (uint) {
        if (totalSupply == 0) {
            return rewardPerTokenStored;
        }

        // Description: currentRewardPerTokenStored + (rewardRate * duration) /totalSupply
        return rewardPerTokenStored + (rewardRate * (lastTimeRewardApplicable() - updatedAt) * 1e18) / totalSupply;
    }

    function stake(uint _amount) external updateReward(msg.sender) {
        require(_amount > 0, "amount = 0");
        // Probably need to do an approval?
        stakingToken.transferFrom(msg.sender, address(this), _amount);
        balanceOf[msg.sender] += _amount;
        totalSupply += _amount;
    }

    function withdraw(uint _amount) external updateReward(msg.sender) {
        require(_amount > 0, "amount = 0");
        require(balanceOf[msg.sender] >= _amount, "You must withdraw less than, or equal your balance");
        balanceOf[msg.sender] -= _amount;
        totalSupply -= _amount;
        stakingToken.transfer(msg.sender, _amount);
    }

    function earned(address _account) public view returns (uint) {
        // Description: (currentAmountStaked * (currentRewardPerToken - userRewardPerTokenPaid)) + previousRewardsEarnedByUser
        return ((balanceOf[_account] * (rewardPerToken() - userRewardPerTokenPaid[_account])) / 1e18) + rewards[_account];
    }

    function getReward() external updateReward(msg.sender) {
        uint reward = rewards[msg.sender];
        if (reward > 0) {
            rewards[msg.sender] = 0;
            rewardsToken.transfer(msg.sender, reward);
        }
    }

    function setRewardsDuration(uint _duration) external onlyOwner {
        require(finishAt < block.timestamp, "reward duration not finished");
        duration = _duration;
    }

    // This sets the Reward Rate => maybe this needs to be called as a modifier every time other ERC20 tokens are swapped for reward token
    // Instead of taking _amount param, you could get amount by looking at current balance of contract, and update reward rate from there
    function notifyRewardAmount(uint _amount) external onlyOwner updateReward(address(0)) {
        if (block.timestamp >= finishAt) {
            rewardRate = _amount / duration;
        } else {
            uint remainingRewards = (finishAt - block.timestamp) * rewardRate;
            rewardRate = (_amount + remainingRewards) / duration;
        }

        require(rewardRate > 0, "reward rate = 0");
        require(rewardRate * duration <= rewardsToken.balanceOf(address(this)), "reward amount > balance");

        finishAt = block.timestamp + duration;
        updatedAt = block.timestamp;
    }

    function swapERC20ToRewardToken(address _tokenIn) external {
        uint amountIn = IERC20(_tokenIn).balanceOf(address(this));
        IERC20(_tokenIn).approve(address(uniswap), amountIn);

        address[] memory path;
        if (_tokenIn == address(WETH)) {
            path = new address[](2);
            path[0] = _tokenIn;
            path[1] = address(TFY);
        } else {
            path = new address[](3);
            path[0] = _tokenIn;
            path[1] = address(WETH);
            path[2] = address(TFY);
        }

        uniswap.swapExactTokensForTokens(amountIn, 0, path, address(this), block.timestamp);
    }

    function swapETHToRewardToken() external {
        address[] memory path;
        path = new address[](2);
        path[0] = address(WETH);
        path[1] = address(TFY);
        uniswap.swapExactETHForTokens{value: address(this).balance}(0, path, address(this), block.timestamp);
    }

    // MAKE A FUNCTION WHICH CLAIMS THE LP FEES
}