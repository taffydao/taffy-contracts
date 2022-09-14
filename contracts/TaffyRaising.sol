// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
// VERIFY IF WE CAN JUST IMPORT THE INTERFACE WITHOUT IMPORTING THE IMPLEMENTATION
// LIKELY NOT, BECAUSE WE NEED TO DEPLOY FROM WITHIN THE CONTRACT
import "./TaffyERC20.sol";
import "./ITaffyERC20.sol";
import "./TaffyStaking.sol";
import "./interfaces/IUniswapV2Router.sol";

contract TaffyRaising {
    struct RaiseBeneficiary {
        address payable beneficiaryAddress;
        uint percentage;
    }

    struct TokenBeneficiary {
        address payable beneficiaryAddress;
        uint percentage;
        // These two arrays must be of equal length and the individual timestamps must correlate to the percentage of the
        // Beneficiary's allocation, e.g. the unique elements inside the vestingPercentage array must sum to == 100
        uint[] vestingTimestamps;
        uint[] vestingPercentages;
    }

    address public raiseTokenAddress;
    address payable erc20Address; // Initialize this to A TaffyERC20 contract address
    address payable stakingAddress; // Initialize this to A TaffyStaking contract address
    address payable public owner;

    uint public target;
    uint public endTimestamp;
    uint erc20Supply = 1000000e18;
    uint public stakingDuration; // In seconds

    TaffyERC20 public erc20Contract;
    TaffyStaking public stakingContract;
    RaiseBeneficiary[] raiseBeneficiaries;
    TokenBeneficiary[] tokenBeneficiaries;

    IUniswapV2Router public uniswap = IUniswapV2Router(0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D);
    IERC20 public WETH = IERC20(0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2);
    IERC20 public TFY = IERC20(0x6De6A91eB63673e63852e67aACF86D98C1B80531);

    string projectName;
    string projectTicker;

    bool public raisingEth;
    bool public projectTerminated = false;
    bool raiseFinalized = false;

    mapping(address => uint) public totalBalanceClaimable;
    mapping(address => uint) public amountClaimed;

    event Withdrawal(address contributor, uint amount, uint when);
    event Deposit(address contributor, uint amount, uint when);

    // _tokenInfo takes 2 elements => [tokenName, tokenTicker]
    constructor(
        address _raiseTokenAddress, uint _endTimestamp, uint _target,
        string[] memory _tokenInfo, /*string memory _projectName, string memory _projectTicker, uint _erc20Supply,*/ uint _stakingDuration,
        address payable[] memory _raiseBeneficiaryAddresses, uint[] memory _raiseBeneficiaryPercentages,
        address payable[] memory _tokenBeneficiaryAddresses, uint[] memory _tokenBeneficiaryPercentages,
        uint[][] memory _vestingTimestamps, uint[][] memory _vestingPercentages
        ) {
            require(block.timestamp < _endTimestamp, "Raising end date should be in the future");
            require(_raiseBeneficiaryAddresses.length == _raiseBeneficiaryPercentages.length, "Number of raise beneficiary addresses does not match raise beneficiary percentages");
            require(_tokenBeneficiaryAddresses.length == _tokenBeneficiaryPercentages.length, "Number of token beneficiary addresses does not match token beneficiary percentages");
            // These will make the gas run out
            checkForValidPercentage(_raiseBeneficiaryPercentages);
            checkForValidPercentage(_tokenBeneficiaryPercentages);

            _raiseTokenAddress == address(0) ? raisingEth = true : false;
            raiseTokenAddress = _raiseTokenAddress;
            endTimestamp = _endTimestamp;
            target = _target;
            // erc20Supply = _erc20Supply ** 18;
            projectName = _tokenInfo[0];
            projectTicker = _tokenInfo[1];
            stakingDuration = _stakingDuration;
            owner = payable(msg.sender);

            // This section makes it run out of gas
            uint i;
            while (i < _raiseBeneficiaryAddresses.length) {
                raiseBeneficiaries.push(RaiseBeneficiary(_raiseBeneficiaryAddresses[i], _raiseBeneficiaryPercentages[i]));
                i++;
            }
            i = 0;
            while (i < _tokenBeneficiaryAddresses.length) {
                require(_vestingTimestamps[i].length == _vestingPercentages[i].length, "The array length of _vestingTimestamps and _vestingPercentages must be equal for each token beneficiary");
                // First check that the vesting %'s sum to 100
                checkForValidPercentage(_vestingPercentages[i]);
                tokenBeneficiaries.push(TokenBeneficiary(_tokenBeneficiaryAddresses[i], _tokenBeneficiaryPercentages[i], _vestingTimestamps[i], _vestingPercentages[i]));
                i++;
            }
    }

    function checkForValidPercentage(uint[] memory _percentageArray) private pure {
        uint i;
        uint movingPercentage;
        while (i < _percentageArray.length) {
            movingPercentage += _percentageArray[i];
            i++;
        }
        require(movingPercentage == 100, "Percentage array does not sum to 100");
    }

    /**
        @dev deposit() allows anyone to contribute eth to the project, and their contribution is 
        for future
     */
    function deposit(uint _amount) public payable {
        require(_amount > 0, "amount = 0");
        require(block.timestamp <= endTimestamp, "Raising period has finished");

        if (raisingEth == false) {
            IERC20(raiseTokenAddress).approve(msg.sender, _amount);
            IERC20(raiseTokenAddress).transferFrom(msg.sender, address(this), _amount);
        }

        if (raisingEth == true) {
            totalBalanceClaimable[msg.sender] += msg.value;
        } else {
            totalBalanceClaimable[msg.sender] += _amount;
        }

        emit Deposit(msg.sender, _amount, block.timestamp);
    }

    /**
        @dev withdraw() is to allow contributors to withdraw funds if the project has reached the end of the raising period
        and have unsuccessfully reached the target
     */
    function withdraw() public {
        require((block.timestamp >= endTimestamp && address(this).balance < target) || projectTerminated == true, "You can not withdraw yet");

        uint amountToTransfer = totalBalanceClaimable[msg.sender];
        amountClaimed[msg.sender] += amountToTransfer;

        if (raisingEth == true) {
            (bool success, ) = msg.sender.call{value: amountToTransfer}("");
            require(success, "Failed to send Ether");
        } else {
            IERC20(raiseTokenAddress).approve(address(this), amountToTransfer);
            IERC20(raiseTokenAddress).transferFrom(address(this), msg.sender, amountToTransfer);
        }

        emit Withdrawal(msg.sender, amountToTransfer, block.timestamp);
    }

    /**
        @dev finalizeRaise() enables anyone to distribute the proceeds of the project raise
        after the raise period has finished.
     */
    function finalizeRaise() external returns (address newTokenAddress, address newStakingAddress) {
        require(projectTerminated == false, "You may not finalize a terminated project");
        require(raiseFinalized == false, "The raise has already been finalized");
        require(block.timestamp >= endTimestamp, "You may not finalize until raising has finished");
        uint amountRaised;
        if (raisingEth == true) {
            amountRaised = address(this).balance;
        } else {
            amountRaised = IERC20(raiseTokenAddress).balanceOf(address(this));
        }
        require(amountRaised >= target, "Project did not reach target");
        raiseFinalized == true;

        // // Distribute raise proceeds to beneficiaries
        // // Make sure to fix the percentage issues => You might not be able to send the right amount based on percentage and the function will always fail.
        uint i;
        if (raisingEth == true) {
            // Do the following where ETH has Been Raised
            while (i < raiseBeneficiaries.length) {
                (bool success, ) = raiseBeneficiaries[i].beneficiaryAddress.call{value: amountRaised * raiseBeneficiaries[i].percentage / 100}("");
                require(success, "Failed to send Ether");
            }
        } else {
            // Do the following where an ERC20 has Been Raised
            while (i < raiseBeneficiaries.length) {
                IERC20(raiseTokenAddress).transfer(raiseBeneficiaries[i].beneficiaryAddress, amountRaised * raiseBeneficiaries[i].percentage / 100);
                i++;
            }
        }

        // Set the mintable amounts for the beneficiaries
        i = 0;
        while (i < tokenBeneficiaries.length) {
            totalBalanceClaimable[tokenBeneficiaries[i].beneficiaryAddress] += amountRaised * raiseBeneficiaries[i].percentage / 100;
            i++;
        }

        // Create the main ERC20
        erc20Contract = new TaffyERC20(projectName, projectTicker, amountRaised);
        erc20Address = payable(address(erc20Contract));

        stakingContract = new TaffyStaking(erc20Address, erc20Address /*address(0x6De6A91eB63673e63852e67aACF86D98C1B80531)*/); // The reward token is TFY => rewards are tracked in TAFFY
        stakingAddress = payable(address(stakingContract));

        // Now 1. mint total staking rewards to staking contract, 2. set staking duration and 3. Set the reward rate
        TaffyERC20(erc20Address).mint(stakingAddress, 1000000 * 1e18); // We should find out how many tokens are allocated to staking contracr => for now its 1,000,000 * 1e18
        TaffyStaking(stakingAddress).setRewardsDuration(stakingDuration);
        TaffyStaking(stakingAddress).notifyRewardAmount(1000000 * 1e18);

        // Create Liquidity Pool
        TaffyERC20(erc20Address).mint(address(this), 200000 * 1e18); // Mint 200,000 tokens to this contract to add to liquidity
        uint amountToPair; // Amount of tokens allocated against the ERC20 token

        if (raisingEth) {
            amountToPair = address(this).balance / 5;
            uniswap.addLiquidityETH{value: address(this).balance}(erc20Address, 200000 * 1e18, 200000, address(this).balance, stakingAddress, block.timestamp);
        } else {
            amountToPair = IERC20(raiseTokenAddress).balanceOf(address(this)) / 5;
            // Swap The Raising Tokens To ETH
            IERC20(raiseTokenAddress).approve(address(uniswap), amountToPair);

            // if (raiseTokenAddress == address(WETH)) {
            //     uniswap.addLiquidity(erc20Address, address(WETH), 200000 * 1e18, amountToPair, 200000 * 1e18, amountToPair, stakingAddress, block.timestamp);
            // } else {
            //     address[] memory path;
            //     path = new address[](2);
            //     path[0] = raiseTokenAddress;
            //     path[1] = address(WETH);
            //     uint[] memory amountOut = uniswap.swapExactTokensForTokens(amountToPair, 0, path, stakingAddress, block.timestamp);

            //     uniswap.addLiquidity(erc20Address, address(WETH), 200000 * 1e18, amountOut[0], 200000 * 1e18, amountOut[0], stakingAddress, block.timestamp);
            // }
        }

        return (erc20Address, stakingAddress);
    }

    /**
        @dev terminateProject() is only available to the creator of the contract.
        It allows contributors to withdraw their contribution.
        It also prohibits the funds from being distributed to the beneficiaries after
        the raise period has closed.
     */
    function terminateProject() external {
        require(projectTerminated == false, "Project has already terminated");
        require(msg.sender == owner, "You are not authorized to terminate the project");
        projectTerminated = true;
    }

    function mintTokens(bool _isBeneficiary) external {
        require(raiseFinalized == true);

        uint amountToClaim = getClaimable(msg.sender, _isBeneficiary);
        amountClaimed[msg.sender] += amountToClaim;

        TaffyERC20(erc20Address).mint(msg.sender, amountToClaim);
    }

    function getClaimable(address _account, bool beneficiary) public view returns (uint claimableAmount) {
        // Check if Beneficiary
        if (!beneficiary) {
            return (totalBalanceClaimable[_account] - amountClaimed[_account]);
        } else {
            uint i = 0; // i will relate to the index in the tokenBeneficiaries array
            // Find the addresses index in the tokenBeneficiaries array
            while (i < tokenBeneficiaries.length) {
                if (_account == tokenBeneficiaries[i].beneficiaryAddress) {
                    break;
                }
                i++;
            }
            uint j = 0; // This will be equal to last timestamp checkpoint in the tokenBeneficiary[i].vestingTimestamps
            uint currentTimestamp;
            // Doublecheck this!
            while (block.timestamp > j) {
                if (tokenBeneficiaries[i].vestingTimestamps[j] > block.timestamp) {
                    currentTimestamp = tokenBeneficiaries[i].vestingTimestamps[j - 1];
                    break;
                }
                j++;
            }
            return (totalBalanceClaimable[_account] * tokenBeneficiaries[i].vestingPercentages[currentTimestamp] - amountClaimed[_account]);
        }
    }

    /**
        @dev getContractBalance() returns the balance currently held by the contract.
     */
    function getContractBalance() external view returns (uint) {
        if (raisingEth == true) {
            return address(this).balance;
        } else {
            return IERC20(raiseTokenAddress).balanceOf(address(this));
        }
    }

    /**
        @dev Gets the balance of the user in the raise contract
     */
    function getTotalBalanceClaimable(address _address) external view returns (uint) {
        return totalBalanceClaimable[_address];
    }

    function getBalanceClaimable(address _address) public view returns (uint) {
        return totalBalanceClaimable[_address] - amountClaimed[_address];
    }

    receive() external payable {
        if (block.timestamp > endTimestamp || !raisingEth) {
            (bool success, ) = erc20Address.call{value: msg.value}("");
            require(success, "Sent ether to staking pool");
        }
    }
}