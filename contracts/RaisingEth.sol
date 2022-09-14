// // SPDX-License-Identifier: MIT
// pragma solidity ^0.8.9;

// import "./TaffyERC20.sol";

// contract RaisingEth {
//     uint public endTimestamp;
//     uint public totalSupply;
//     bool projectTerminated = false;
//     bool raiseFinalized = false;
//     TaffyERC20 public erc20Contract;
//     uint erc20Supply;

//     mapping (address => uint) public balanceOf;

//     event Withdrawal(address contributor, uint amount, uint when);
//     event Deposit(address contributor, uint amount, uint when);

//     address payable public owner;
//     address payable beneficiary1;
//     address payable beneficiary2;
//     address payable beneficiary3;
//     address payable beneficiary4;
//     address payable beneficiary5;

//     uint beneficiary1Portion;
//     uint beneficiary2Portion;
//     uint beneficiary3Portion;
//     uint beneficiary4Portion;
//     uint beneficiary5Portion;

//     string projectName;
//     string projectTicker;
//     uint target;

//     constructor(
//         uint _endTimestamp, uint _target, string memory _projectName, string memory _projectTicker, uint _erc20Supply,
//         address payable _beneficiary1, uint _ben1Portion,
//         address payable _beneficiary2, uint _ben2Portion,
//         address payable _beneficiary3, uint _ben3Portion,
//         address payable _beneficiary4, uint _ben4Portion,
//         address payable _beneficiary5, uint _ben5Portion) payable {
//             require(block.timestamp < _endTimestamp, "Raising end date should be in the future");
//             require ((_ben1Portion + _ben2Portion + _ben3Portion + _ben4Portion + _ben5Portion) == 100, "Beneficiary portions must total 100" );

//             endTimestamp = _endTimestamp;
//             target = _target;
//             projectName = _projectName;
//             projectTicker = _projectTicker;
//             erc20Supply = _erc20Supply ** 18;

//             owner = payable(msg.sender);

//             beneficiary1 = _beneficiary1;
//             beneficiary1Portion = _ben1Portion;

//             beneficiary2 = _beneficiary2;
//             beneficiary2Portion = _ben2Portion;

//             beneficiary3 = _beneficiary3;
//             beneficiary3Portion = _ben3Portion;

//             beneficiary4 = _beneficiary4;
//             beneficiary4Portion = _ben4Portion;

//             beneficiary5 = _beneficiary5;
//             beneficiary5Portion = _ben5Portion;
//     }

//     /**
//         @dev deposit() allows anyone to contribute eth to the project, and their contribution is 
//         for future
//      */
//     function deposit() payable public {
//         require(msg.value > 0, "amount = 0");
//         require(block.timestamp <= endTimestamp, "Raising period has finished");

//         balanceOf[msg.sender] += msg.value;
//         totalSupply += msg.value;
//         emit Deposit(msg.sender, msg.value, block.timestamp);
//     }

//     /**
//         @dev withdraw() is to allow contributors to withdraw funds if the project has reached the end of the raising period
//         and have unsuccessfully reached the target
//      */
//     function withdraw() public {
//         // Uncomment this line to print a log in your terminal
//         // console.log("Unlock time is %o and block timestamp is %o", endTimestamp, block.timestamp);

//         require((block.timestamp >= endTimestamp && address(this).balance < target) || projectTerminated == true, "You can't withdraw yet");

//         uint amountToTransfer = getBalance(msg.sender);
//         balanceOf[msg.sender] = 0;

//         transfer(payable(msg.sender), amountToTransfer);
//         emit Withdrawal(msg.sender, amountToTransfer, block.timestamp);
//     }

//     /**
//         @dev finalizeRaise() enables anyone to distribute the proceeds of the project raise
//         after the raise period has finished.
//      */
//     function finalizeRaise() external payable returns(TaffyERC20) {
//         require(projectTerminated == false, "You may not finalize a terminated project");
//         require(raiseFinalized == false, "The raise has already been finalized");
//         require(block.timestamp >= endTimestamp, "You may not withdraw until raising has finished");
//         require(address(this).balance >= target, "Project did not reach target");
//         raiseFinalized == true;

//         uint ben1Balance = address(this).balance * (beneficiary1Portion / 100);
//         uint ben2Balance = address(this).balance * (beneficiary2Portion / 100);
//         uint ben3Balance = address(this).balance * (beneficiary3Portion / 100);
//         uint ben4Balance = address(this).balance * (beneficiary4Portion / 100);
//         uint ben5Balance = address(this).balance * (beneficiary5Portion / 100);

//         transfer(beneficiary1, ben1Balance);
//         transfer(beneficiary2, ben2Balance);
//         transfer(beneficiary3, ben3Balance);
//         transfer(beneficiary4, ben4Balance);
//         transfer(beneficiary5, ben5Balance);

//         // Make sure to fix the percentage issues => You might not be able to send the right amount based on percentage and the function will always fail.

//         // Find the amount raised
//         uint amountRaised = 100;
//         //This creates the main ERC20
//         erc20Contract = new TaffyERC20{value: msg.value}(projectName, projectTicker, amountRaised);
//         return erc20Contract;
//     }

//     /**
//         @dev transfer() allows funds to be sent from the contract to the payabale address.
//      */
//     function transfer(address payable _to, uint _amount) internal {
//         (bool success, ) = _to.call{value: _amount}("");
//         require(success, "Failed to send Ether");
//     }

//     /**
//         @dev getContractBalance() returns the eth balance currently held in the contract.
//      */
//     function getContractBalance() external view returns (uint) {
//         return address(this).balance;
//     }

//     /**
//         @dev Gets the balance of the user in the raise contract
//      */
//     function getBalance(address _contributor) public view returns (uint) {
//         return balanceOf[_contributor];
//     }

//     /**
//         @dev Retrieves the total supply of raise contract
//      */
//     function getSupply() external view returns (uint) {
//         return totalSupply;
//     }

//     /**
//         @dev terminateProject() is only available to the creator of the contract.
//         It allows contributors to withdraw their contribution.
//         It also prohibits the funds from being distributed to the beneficiaries after
//         the raise period has closed.
//      */
//     function terminateProject() external {
//         require(projectTerminated == false, "Project has already terminated");
//         require(msg.sender == owner, "You are not authorized to terminate the project");
//         projectTerminated = true;
//     }

//     receive() external payable {}
//     fallback() external payable {}
// }