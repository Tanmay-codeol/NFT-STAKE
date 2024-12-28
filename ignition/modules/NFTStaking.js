const hre = require("hardhat");

async function main() {
  const [deployer] = await hre.ethers.getSigners();

  console.log("Deploying contracts with the account:", deployer.address);

  // Deploy MockNFT
  const MockNFT = await hre.ethers.getContractFactory("MockNFT");
  const mockNFT = await MockNFT.deploy();
  await mockNFT.waitForDeployment();
  console.log("MockNFT deployed to:", await mockNFT.getAddress());

  // Deploy NFTStaking
  const NFTStaking = await hre.ethers.getContractFactory("NFTStaking");
  const nftStaking = await hre.upgrades.deployProxy(NFTStaking, [
    deployer.address,
    await mockNFT.getAddress(),
    hre.ethers.parseEther("1"), // REWARD_PER_BLOCK
    10, // DELAY_PERIOD
    20, // UNBONDING_PERIOD
  ]);
  await nftStaking.waitForDeployment();
  console.log("NFTStaking deployed to:", await nftStaking.getAddress());
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });