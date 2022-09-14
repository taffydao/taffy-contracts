import { time, loadFixture } from "@nomicfoundation/hardhat-network-helpers";
import { anyValue } from "@nomicfoundation/hardhat-chai-matchers/withArgs";
import { expect } from "chai";
import hre, { ethers, network } from "hardhat";
import { BigNumber } from "ethers";

describe("RaiseERC20", function () {
	// We define a fixture to reuse the same setup in every test.
	// We use loadFixture to run this setup once, snapshot that state,
	// and reset Hardhat Network to that snapshopt in every test.
	async function setupRaiseERC20Contract() {
		const ONE_YEAR_IN_SECS = 365 * 24 * 60 * 60;
		const ONE_GWEI = 1_000_000_000;
		const LINK = "0x326C977E6efc84E512bB9C30f76E30c160eD06FB";

		const [owner, addr1, addr2] = await ethers.getSigners();

		await hre.run("compile");

		let currentTime = await time.latest();

		const TaffyRaising = await ethers.getContractFactory("TaffyRaising");
		const taffyRaising = await TaffyRaising.deploy(
			LINK,
			(await time.latest()) + 5000,
			BigNumber.from("10000000000000000000"),
			["JackToken", "JACK"],
			5000,
			["0x9B064b6e4B994027E8b7d5B681290DEDe89fe5E0", "0x7adB782f9cC311cD0166c9d85F9f075d9cD4126B"],
			[70, 30],
			["0x9B064b6e4B994027E8b7d5B681290DEDe89fe5E0", "0x7adB782f9cC311cD0166c9d85F9f075d9cD4126B"],
			[70, 30],
			[
				[(await time.latest()) + 1000, (await time.latest()) + 2000, (await time.latest()) + 3000],
				[(await time.latest()) + 1500, (await time.latest()) + 2500, (await time.latest()) + 3500],
			],
			[
				[25, 50, 25],
				[25, 50, 25],
			]
		);

		// Transfer a bunch of LINK to Owner, addr1 and addr2
		const link = await ethers.getContractAt("IERC20", LINK);
		const LINK_WHALE = "0xe4ddb4233513498b5aa79b98bea473b01b101a67";
		const linkWhale = await ethers.getSigner(LINK_WHALE);

		return { ONE_YEAR_IN_SECS, ONE_GWEI, owner, addr1, addr2, currentTime, TaffyRaising, taffyRaising, link, linkWhale, LINK_WHALE };
	}

	async function fundAccounts() {
		let { ONE_YEAR_IN_SECS, ONE_GWEI, owner, addr1, addr2, currentTime, TaffyRaising, taffyRaising } = await loadFixture(setupRaiseERC20Contract);

		// Transfer a bunch of LINK to Owner, addr1 and addr2
		const LINK = "0x326C977E6efc84E512bB9C30f76E30c160eD06FB";
		const link = await ethers.getContractAt("IERC20", LINK);
		const LINK_WHALE = "0xe4ddb4233513498b5aa79b98bea473b01b101a67";
		const linkWhale = await ethers.getSigner(LINK_WHALE);

		await network.provider.request({
			method: "hardhat_impersonateAccount",
			params: [LINK_WHALE],
		});

		const amount = 100n * 10n ** 18n;

		expect(await link.balanceOf(linkWhale.address)).to.gte(amount);

		await link.connect(linkWhale).transfer(addr1.address, amount);
		await link.connect(linkWhale).transfer(addr2.address, amount);

		await hre.network.provider.request({
			method: "hardhat_stopImpersonatingAccount",
			params: [LINK_WHALE],
		});
	}

	describe("Check for function calls in the ERC20 Raising Contract", function () {
		it("Unlocks Georli Whale LINK account", async () => {
			let { ONE_YEAR_IN_SECS, ONE_GWEI, owner, addr1, addr2, currentTime, TaffyRaising, taffyRaising, link, linkWhale, LINK_WHALE } = await loadFixture(setupRaiseERC20Contract);
			const amount = 100n * 10n ** 18n;

			console.log("LINK balance of whale", await link.balanceOf(linkWhale.address));
			expect(await link.balanceOf(linkWhale.address)).to.gte(amount);

			await network.provider.request({
				method: "hardhat_impersonateAccount",
				params: [LINK_WHALE],
			});

			await link.connect(linkWhale).transfer(addr1.address, amount);
			await link.connect(linkWhale).transfer(addr2.address, amount);
		});

		it("Should return a false ethRaising", async function () {
			const { owner, taffyRaising } = await loadFixture(setupRaiseERC20Contract);

			expect(await taffyRaising.raisingEth()).to.equal(false);
			expect(await taffyRaising.raiseTokenAddress()).to.equal("0x326C977E6efc84E512bB9C30f76E30c160eD06FB");
		});

		it("Should set the right owner", async function () {
			const { owner, taffyRaising } = await loadFixture(setupRaiseERC20Contract);

			expect(await taffyRaising.owner()).to.equal(owner.address);
		});

		it("Should revert to a withdraw before end timestamp", async function () {
			const { addr1, taffyRaising } = await loadFixture(setupRaiseERC20Contract);

			expect(taffyRaising.connect(addr1).withdraw()).to.be.revertedWith("You can not withdraw yet");
		});

		it("Should deposit", async function () {
			let { ONE_YEAR_IN_SECS, ONE_GWEI, owner, addr1, addr2, currentTime, TaffyRaising, taffyRaising, link } = await loadFixture(setupRaiseERC20Contract);
			await fundAccounts();

			await time.increase(500);
			currentTime = await time.latest();
			let addr1LinkBalance = await link.balanceOf(addr1.address);
			let addr2LinkBalance = await link.balanceOf(addr2.address);

			await link.connect(addr1).approve(taffyRaising.address, addr1LinkBalance);
			await link.connect(addr2).approve(taffyRaising.address, addr2LinkBalance);

			await taffyRaising.connect(addr1).deposit(addr1LinkBalance);
			await taffyRaising.connect(addr2).deposit(addr2LinkBalance);

			expect(await taffyRaising.getTotalBalanceClaimable(addr1.address)).to.equal(addr1LinkBalance);
			expect(await taffyRaising.getTotalBalanceClaimable(addr2.address)).to.equal(addr2LinkBalance);

			expect(await taffyRaising.getBalanceClaimable(addr1.address)).to.equal(addr1LinkBalance);
			expect(await taffyRaising.getBalanceClaimable(addr2.address)).to.equal(addr2LinkBalance);
		});

		it("Should revert when anyone attempts to terminate project, except for owner", async function () {
			let { ONE_YEAR_IN_SECS, ONE_GWEI, owner, addr1, addr2, currentTime, TaffyRaising, taffyRaising } = await loadFixture(setupRaiseERC20Contract);

			expect(taffyRaising.connect(addr1).terminateProject()).to.be.revertedWith("You are not authorized to terminate the project");
			expect(taffyRaising.connect(addr2).terminateProject()).to.be.revertedWith("You are not authorized to terminate the project");

			expect(await taffyRaising.projectTerminated()).equals(false);
			await taffyRaising.connect(owner).terminateProject();
			expect(await taffyRaising.projectTerminated()).equals(true);
		});

		it("Should finalize raise", async function () {
			let { ONE_YEAR_IN_SECS, ONE_GWEI, owner, addr1, addr2, currentTime, TaffyRaising, taffyRaising, link, linkWhale } = await loadFixture(setupRaiseERC20Contract);
			await fundAccounts();

			let addr1LinkBalance = await link.balanceOf(addr1.address);
			let addr2LinkBalance = await link.balanceOf(addr2.address);

			await link.connect(addr1).approve(taffyRaising.address, addr1LinkBalance);
			await link.connect(addr2).approve(taffyRaising.address, addr2LinkBalance);

			await taffyRaising.connect(addr1).deposit(addr1LinkBalance);
			await taffyRaising.connect(addr2).deposit(addr2LinkBalance);

			// Move time to endTime
			await time.increase(5000);
			currentTime = await time.latest();

			// For now - it looks like the approval from to the uniswap router is an issue
			const finalizeRaise = await taffyRaising.connect(owner).finalizeRaise();

			console.log(await link.allowance(taffyRaising.address, "0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D"));

			console.log("The result of finalizeRaise: ", finalizeRaise);

			// const erc20Address = taffyRaising.erc20Address.toString();
			// const stakingAddress = taffyRaising.stakingAddress.toString();
			// console.log("The ERC20 Address is: ", erc20Address);
			// console.log("The Staking Contract Address is: ", stakingAddress);
		});
	});

	// describe("Check for function calls in the ETH Raising Contract", function () {
	// 	it("Unlocks Georli Whale LINK account", async () => {
	// 		let { ONE_YEAR_IN_SECS, ONE_GWEI, owner, addr1, addr2, currentTime, TaffyRaising, taffyRaising, link, linkWhale, LINK_WHALE } = await loadFixture(setupRaiseERC20Contract);
	// 		const amount = 100n * 10n ** 18n;

	// 		console.log("LINK balance of whale", await link.balanceOf(linkWhale.address));
	// 		expect(await link.balanceOf(linkWhale.address)).to.gte(amount);

	// 		await network.provider.request({
	// 			method: "hardhat_impersonateAccount",
	// 			params: [LINK_WHALE],
	// 		});

	// 		await link.connect(linkWhale).transfer(addr1.address, amount);
	// 		console.log("is done");
	// 		// await link.connect(linkWhale).transfer(addr2.address, amount);

	// 		console.log("LINK balance of addr1", await link.balanceOf(addr1.address));
	// 	});

	// 	it("Should return a false ethRaising", async function () {
	// 		const { owner, taffyRaising } = await loadFixture(setupRaiseERC20Contract);

	// 		expect(await taffyRaising.raisingEth()).to.equal(false);
	// 		expect(await taffyRaising.raiseTokenAddress()).to.equal("0x326C977E6efc84E512bB9C30f76E30c160eD06FB");
	// 	});

	// 	it("Should set the right owner", async function () {
	// 		const { owner, taffyRaising } = await loadFixture(setupRaiseERC20Contract);

	// 		expect(await taffyRaising.owner()).to.equal(owner.address);
	// 	});

	// 	it("Should revert to a withdraw before end timestamp", async function () {
	// 		const { addr1, taffyRaising } = await loadFixture(setupRaiseERC20Contract);

	// 		expect(taffyRaising.connect(addr1).withdraw()).to.be.revertedWith("You can not withdraw yet");
	// 	});

	// 	it("Should deposit", async function () {
	// 		let { ONE_YEAR_IN_SECS, ONE_GWEI, owner, addr1, addr2, currentTime, TaffyRaising, taffyRaising } = await loadFixture(setupRaiseERC20Contract);

	// 		await time.increase(500);
	// 		currentTime = await time.latest();

	// 		console.log("Increased 500 seconds to timestamp: ", currentTime);

	// 		// First add balance to addr1 and addr2
	// 		await taffyRaising.connect(addr1).deposit(BigNumber.from("100000000000000000000"));
	// 		await taffyRaising.connect(addr2).deposit(BigNumber.from("300000000000000000000"));

	// 		console.log("Addr1 claimable balance: ", await taffyRaising.getTotalBalanceClaimable(addr1.address));
	// 		expect(await taffyRaising.getTotalBalanceClaimable(addr1.address)).to.equal(BigNumber.from("100000000000000000000"));
	// 		expect(await taffyRaising.getTotalBalanceClaimable(addr2.address)).to.equal(BigNumber.from("300000000000000000000"));

	// 		expect(await taffyRaising.getBalanceClaimable(addr1.address)).to.equal(BigNumber.from("100000000000000000000"));
	// 		expect(await taffyRaising.getBalanceClaimable(addr2.address)).to.equal(BigNumber.from("300000000000000000000"));
	// 	});

	// 	it("Should revert when anyone attempts to terminate project, except for owner", async function () {
	// 		let { ONE_YEAR_IN_SECS, ONE_GWEI, owner, addr1, addr2, currentTime, TaffyRaising, taffyRaising } = await loadFixture(setupRaiseERC20Contract);

	// 		console.log("Made inside should revert thing");
	// 		expect(taffyRaising.connect(addr1).terminateProject()).to.be.revertedWith("You are not authorized to terminate the project");
	// 		expect(taffyRaising.connect(addr2).terminateProject()).to.be.revertedWith("You are not authorized to terminate the project");

	// 		expect(await taffyRaising.projectTerminated()).equals(false);
	// 		await taffyRaising.connect(owner).terminateProject();
	// 		expect(await taffyRaising.projectTerminated()).equals(true);
	// 	});

	// 	it("Should finalize raise", async function () {
	// 		let { ONE_YEAR_IN_SECS, ONE_GWEI, owner, addr1, addr2, currentTime, TaffyRaising, taffyRaising, link, linkWhale } = await loadFixture(setupRaiseERC20Contract);
	// 		await fundAccounts();

	// 		let addr1LinkBalance = await link.balanceOf(addr1.address);
	// 		let addr2LinkBalance = await link.balanceOf(addr2.address);

	// 		console.log("Link balance of addr1: ", addr1LinkBalance);
	// 		console.log("Link balance of addr2: ", addr2LinkBalance);

	// 		await link.connect(addr1).approve(taffyRaising.address, addr1LinkBalance);
	// 		await link.connect(addr2).approve(taffyRaising.address, addr2LinkBalance);

	// 		await taffyRaising.connect(addr1).deposit(BigNumber.from("160000000000000000000"));
	// 		await taffyRaising.connect(addr2).deposit(BigNumber.from("100000000000000000000"));

	// 		console.log("Link balance of addr1 after deposit: ", await link.balanceOf(addr1.address));
	// 		console.log("Link balance of addr2 after deposit: ", await link.balanceOf(addr2.address));

	// 		// Move time to endTime
	// 		await time.increase(5000);
	// 		currentTime = await time.latest();

	// 		// const finalizeRaise = await taffyRaising.connect(owner).finalizeRaise();

	// 		console.log("The result of finalizeRaise: ", await taffyRaising.connect(owner).finalizeRaise());

	// 		// const erc20Address = taffyRaising.erc20Address.toString();
	// 		// const stakingAddress = taffyRaising.stakingAddress.toString();
	// 		// console.log("The ERC20 Address is: ", erc20Address);
	// 		// console.log("The Staking Contract Address is: ", stakingAddress);
	// 	});
	// });
});
