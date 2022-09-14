import hre, { ethers } from "hardhat";

async function main(_stakingToken: string, _rewardToken: string) {
	await hre.run("compile");

	const [deployer] = await ethers.getSigners();

	console.log("Deploying contracts with the account:", deployer.address);

	console.log("Account balance:", (await deployer.getBalance()).toString());

	const Staking = await ethers.getContractFactory("Staking");
	const staking = await Staking.deploy(_stakingToken, _rewardToken);

	console.log("Token address:", staking.address);
}

main("0xF97d270718FD0f942A2F200496D8d9e595d788fD", "0xF97d270718FD0f942A2F200496D8d9e595d788fD")
	.then(() => process.exit(0))
	.catch((error) => {
		console.error(error);
		process.exit(1);
	});
