import { BigNumber } from "ethers";
import hre, { ethers } from "hardhat";

async function main(_endTimestamp: number, _target: BigNumber, _beneficiary1: string, _ben1Portion: number, _beneficiary2: string, _ben2Portion: number, _beneficiary3: string, _ben3Portion: number, _beneficiary4: string, _ben4Portion: number, _beneficiary5: string, _ben5Portion: number) {
	await hre.run("compile");

	const [deployer] = await ethers.getSigners();

	console.log("Deploying contracts with the account:", deployer.address);

	console.log("Account balance:", (await deployer.getBalance()).toString());

	const RaisingEth = await ethers.getContractFactory("RaisingEth");
	const raisingEth = await RaisingEth.deploy(_endTimestamp, _target, _beneficiary1, _ben1Portion, _beneficiary2, _ben2Portion, _beneficiary3, _ben3Portion, _beneficiary4, _ben4Portion, _beneficiary5, _ben5Portion);

	console.log("Token address:", raisingEth.address);
}

main(1665486838, BigNumber.from(10000000000000000000n), "0x163290dd5322db5F688b9a90d80817324A185780", 80, "0x9B064b6e4B994027E8b7d5B681290DEDe89fe5E0", 20, "0x0000000000000000000000000000000000000000", 0, "0x0000000000000000000000000000000000000000", 0, "0x0000000000000000000000000000000000000000", 0)
	.then(() => process.exit(0))
	.catch((error) => {
		console.error(error);
		process.exit(1);
	});
