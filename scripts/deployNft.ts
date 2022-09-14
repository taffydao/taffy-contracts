import hre, { ethers } from "hardhat";

async function main(name: string, ticker: string, fee: number) {
	await hre.run("compile");
	// const [deployer] = await ethers.getSigners();
	const deployer = await ethers.getSigner("0x9B064b6e4B994027E8b7d5B681290DEDe89fe5E0");

	console.log("Deploying contracts with the account:", deployer.address);

	console.log("Account balance:", (await deployer.getBalance()).toString());

	const TaffyNft = await ethers.getContractFactory("TaffyNft");
	const taffyNft = await TaffyNft.deploy(name, ticker, fee);

	console.log("Token address:", taffyNft.address);
}

main("Fish", "FSH", 10)
	.then(() => process.exit(0))
	.catch((error) => {
		console.error(error);
		process.exit(1);
	});
