import { HardhatUserConfig } from "hardhat/config";
import "@nomicfoundation/hardhat-toolbox";
import "dotenv/config";
import "hardhat-contract-sizer";

const ALCHEMY_API_KEY = process.env.ALCHEMY_API_KEY;
const GOERLI_PRIVATE_KEY = process.env.GOERLI_PRIVATE_KEY as string;

const config: HardhatUserConfig = {
	solidity: {
		version: "0.8.9",
		settings: {
			optimizer: {
				enabled: true,
				runs: 10,
			},
		},
	},
	networks: {
		hardhat: {
			chainId: 31337,
			forking: {
				// Using Alchemy
				url: `https://eth-goerli.g.alchemy.com/v2/${ALCHEMY_API_KEY}`, // url to RPC node, ${ALCHEMY_KEY} - must be your API key
				// Using Infura
				// url: `https://mainnet.infura.io/v3/${INFURA_KEY}`, // ${INFURA_KEY} - must be your API key
				// blockNumber: 12821000, // a specific block number with which you want to work
			},
		},
		goerli: {
			url: `https://eth-goerli.g.alchemy.com/v2/${ALCHEMY_API_KEY}`,
			accounts: [GOERLI_PRIVATE_KEY],
		},
	},
	contractSizer: {
		alphaSort: true,
		disambiguatePaths: false,
		runOnCompile: true,
		strict: true,
		// only: [":ERC20$"],
	},
};

export default config;
