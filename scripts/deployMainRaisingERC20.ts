import hre, { ethers } from "hardhat";
import { expect } from "chai";
import { time } from "@nomicfoundation/hardhat-network-helpers";
import { BigNumber } from "ethers";

async function main(_raiseTokenAddress: string, _endTimestamp: number, _target: BigNumber, _tokenInfo: string[], /*_projectName: string, _projectTicker: string, _erc20Supply: number,*/ _stakingDuration: number, _raiseBeneficiaryAddresses: string[], _raiseBeneficiaryPercentages: number[], _tokenBeneficiaryAddresses: string[], _tokenBeneficiaryPercentages: number[], _vestingTimestamps: number[][], _vestingPercentages: number[][]) {
	const [owner, addr1, addr2] = await ethers.getSigners();

	await hre.run("compile");
	// const [deployer] = await ethers.getSigners();
	const deployer = await ethers.getSigner(owner.address);

	console.log("Deploying contracts with the account:", deployer.address);

	console.log("Account balance:", (await deployer.getBalance()).toString());

	let currentTime = await time.latest();
	console.log("Timestamp when deploying: ", currentTime);

	const TaffyRaising = await ethers.getContractFactory("TaffyRaising");
	const taffyRaising = await TaffyRaising.deploy(_raiseTokenAddress, _endTimestamp, _target, _tokenInfo, /*_projectName, _projectTicker, _erc20Supply,*/ _stakingDuration, _raiseBeneficiaryAddresses, _raiseBeneficiaryPercentages, _tokenBeneficiaryAddresses, _tokenBeneficiaryPercentages, _vestingTimestamps, _vestingPercentages);

	console.log("Token address:", taffyRaising.address);

	await time.increase(500);
	currentTime = await time.latest();

	console.log("Increased 500 seconds to timestamp: ", currentTime);

	console.log("Address 1 Balance Before deposit: ", await ethers.provider.getBalance(addr1.address));
	console.log("Address 2 Balance Before deposit: ", await ethers.provider.getBalance(addr2.address));

	// First add balance to addr1 and addr2
	await taffyRaising.connect(addr1).deposit(100 * 1e18);
	await taffyRaising.connect(addr2).deposit(300 * 1e18);

	console.log("Address 1 Balance After deposit: ", await ethers.provider.getBalance(addr1.address));
	console.log("Address 2 Balance After deposit: ", await ethers.provider.getBalance(addr2.address));

	// In test, try to do a withdraw and make it fail

	// Move time to endTime
	await time.increase(5000);
	currentTime = await time.latest();

	console.log("Increased 500 seconds to timestamp: ", currentTime);

	await taffyRaising.connect(addr2).finalizeRaise(); // Expect To Fail

	const finalizeRaise = await taffyRaising.connect(owner).finalizeRaise();

	console.log("The result of finalizeRaise: ", finalizeRaise);

	// const erc20Address = taffyRaising.erc20Address.toString();
	// const stakingAddress = taffyRaising.stakingAddress.toString();
	// console.log("The ERC20 Address is: ", erc20Address);
	// console.log("The Staking Contract Address is: ", stakingAddress);
}

main(
	"0x326C977E6efc84E512bB9C30f76E30c160eD06FB",
	Date.now() / 1000 + 5000,
	// This is probab
	BigNumber.from("10000000000000000000"),
	["JackToken", "JACK"],
	5000,
	["0x9B064b6e4B994027E8b7d5B681290DEDe89fe5E0", "0x7adB782f9cC311cD0166c9d85F9f075d9cD4126B"],
	[70, 30],
	["0x9B064b6e4B994027E8b7d5B681290DEDe89fe5E0", "0x7adB782f9cC311cD0166c9d85F9f075d9cD4126B"],
	[70, 30],
	[
		[Date.now() / 1000 + 1000, Date.now() / 1000 + 2000, Date.now() / 1000 + 3000],
		[Date.now() / 1000 + 1500, Date.now() / 1000 + 2500, Date.now() / 1000 + 3500],
	],
	[
		[30, 60, 100],
		[30, 60, 100],
	]
)
	.then(() => process.exit(0))
	.catch((error) => {
		console.error(error);
		process.exit(1);
	});
