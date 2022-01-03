require("@nomiclabs/hardhat-waffle");
require('@openzeppelin/hardhat-upgrades');
require('@nomiclabs/hardhat-etherscan');
require('hardhat-abi-exporter');
require('dotenv').config();

// This is a sample Hardhat task. To learn how to create your own go to
// https://hardhat.org/guides/create-task.html
task("accounts", "Prints the list of accounts", async () => {
  const accounts = await ethers.getSigners();

  for (const account of accounts) {
    console.log(account.address);
  }
});

require('./tasks/new-meta');
require('./tasks/read-meta');

// You need to export an object to set up your config
// Go to https://hardhat.org/config/ to learn more

const defaultNetwork = "localhost";

/**
 * @type import('hardhat/config').HardhatUserConfig
 */
module.exports = {
  defaultNetwork,
  networks: {
    localhost: {
      url: "http://localhost:8545",
    },
    emerald: {
      url: process.env.EMERALD_RPC,
      accounts: [`0x${process.env.PRIVATE_KEY}`]
    },
    emeraldTestnet: {
      url: process.env.EMERALD_TESTNET_RPC,
      accounts: [`0x${process.env.PRIVATE_KEY}`]
    },
    rinkeby: {
      url: process.env.RINKEBY_RPC || "https://rinkeby.infura.io/v3/55fa2103e26d4e7b9d6ce8b3280815b1", // <---- YOUR INFURA ID! (or it won't work)
      accounts: [`0x${process.env.PRIVATE_KEY}`]
    },
    kovan: {
      url: "https://kovan.infura.io/v3/460f40a260564ac4a4f4b3fffb032dad", // <---- YOUR INFURA ID! (or it won't work)
      accounts: [`0x${process.env.PRIVATE_KEY}`]
    },
    mainnet: {
      url: "https://mainnet.infura.io/v3/460f40a260564ac4a4f4b3fffb032dad", // <---- YOUR INFURA ID! (or it won't work)
      accounts: [`0x${process.env.PRIVATE_KEY}`]
    },
    ropsten: {
      url: "https://ropsten.infura.io/v3/460f40a260564ac4a4f4b3fffb032dad", // <---- YOUR INFURA ID! (or it won't work)
      accounts: [`0x${process.env.PRIVATE_KEY}`]
    },
    goerli: {
      url: "https://goerli.infura.io/v3/460f40a260564ac4a4f4b3fffb032dad", // <---- YOUR INFURA ID! (or it won't work)
      accounts: [`0x${process.env.PRIVATE_KEY}`]
    },
    xdai: {
      url: "https://rpc.xdaichain.com/",
      gasPrice: 1000000000,
      accounts: [`0x${process.env.PRIVATE_KEY}`]
    },
    matic: {
      url: "https://rpc-mainnet.maticvigil.com/",
      gasPrice: 1000000000,
      accounts: [`0x${process.env.PRIVATE_KEY}`]
    },
    mumbai: {
      url: process.env.MUMBAI_RPC,
      accounts: [`0x${process.env.PRIVATE_KEY}`]
    },
    stardust: {
      url: "https://stardust.metis.io/?owner=588",
      accounts: [`0x${process.env.PRIVATE_KEY}`]
    },
  },
  solidity: {
    compilers: [
      {
        version: "0.8.4",
        settings: {
          optimizer: {
            enabled: true,
            runs: 200,
          },
        },
      },
    ],
  },
  abiExporter: {
    path: "./data/abi",
    clear: true,
    flat: true,
    spacing: 2,
  },
  etherscan: {
    // Your API key for Etherscan
    // Obtain one at https://etherscan.io/
    apiKey: process.env.ETHER_SCAN_API_KEY || '',
  },
};

