require("@nomicfoundation/hardhat-toolbox");
require("@openzeppelin/hardhat-upgrades");

/** @type import('hardhat/config').HardhatUserConfig */
module.exports = {
  solidity: {
    version: "0.8.28",
    settings: {
      optimizer: {
        enabled: true,
        runs: 200
      }
    }
  },
  // networks: {
  //   sepolia: {
  //     url: `https://eth-sepolia.g.alchemy.com/v2/your-api-key{get it from alchemy}`,
  //     accounts: "ENTER YOUR PRIVATE KEy WITH SEPOLIA ETH"
      
  //   }
  // }
};