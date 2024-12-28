# NFT Staking Project

This project involves deploying and interacting with smart contracts for NFT staking. Follow the steps below to get started.

## Prerequisites

- Ensure you have Node.js and npm installed
- Install Hardhat globally by running `npm install -g hardhat`

## Steps to Set Up and Deploy

### Step 1: Clone the Repository

`git clone https://github.com/Tanmay-codeol/NFT-STAKE.git`

### Step 2: Channge the directory

`cd <folder name>`

### Step 3: Channge the directory

`npm install`

or

`npm install --force`

### Step 5: Compile the Smart Contracts

`npx hardhat compile`

### Step 6: Run Smart Contracts Tests Script

`npx hardhat test`

### Step 7: DEPLOY

#### Start a local node using hardhat

`npx hardhat node`

> **IMPORTANT**: KEEP THE TERMINAL OPEN, OPEN A NEW TERMINAL FOR FURTHER COMMANDS (it will spin up a hardhat blockcchain where our contract will be deployed!)

#### Deploy the contracts:

`npx hardhat run ignition/modules/NFTStaking.js --network localhost`

## Deploy on Sepolia Testnet

### Step 1

Get an Alchemy Sepolia endpoint and your private key.

### Step 2

Edit the hardhat.config.js file:

Uncomment the following section:

```javascript
networks: {
  sepolia: {
    url: `https://eth-sepolia.g.alchemy.com/v2/your-api-key`,
    accounts: ["ENTER YOUR PRIVATE KEY WITH SEPOLIA ETH"],
  },
}
```

### Deploy on Sepolia

`npx hardhat run ignition/modules/NFTStaking.js --network sepolia`

> **Note**: Please ensure that you have sufficient ETH in sepolia wallet

THANKS
