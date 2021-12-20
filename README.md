# meta-protocol

The Smart Contracts (Proxy and Implementation) to create/mint NFTs used in Metaworth

NFTs will be minted randomly instead change the token IDs incrementally, which is pretty easy to predict the NFT's rarities from the metadata.

The random feature in the current implementation is buit on top of the [ERC721-extensions](https://github.com/1001-digital/erc721-extensions) maintained by the 1001-digital team. We can replace it with an Oracle like Chainlink pretty easily and straightforward later on.

## Install dependencies

`yarn` or `npm install`

## Run a local ETH node

`npx hardhat node`

## Compile

`npx hardhat compile`

## Run tests

`npx hardhat test`

## Deploy

`npx hardhat --network emeraldTestnet run script/factory-deploy.js`

> NOTES: once the contract get deployed you need to update the [factory contract address](https://github.com/metaworth/meta-interface/blob/main/src/helpers/contracts.ts) in the interface repo.

## Etherscan verification

`npx hardhat verify --network NETWORK_NAME CONTRACT_ADDRESS`


This is project is built with hardhat, more info about hardhat please refer to https://hardhat.org.
