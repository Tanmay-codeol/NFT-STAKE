const { expect } = require("chai");
const hre = require("hardhat");

describe("NFTStaking", function () {
  let nftStaking;
  let mockNFT;
  let owner;
  let user1;
  let user2;

  const REWARD_PER_BLOCK = hre.ethers.parseEther("1");
  const DELAY_PERIOD = 10n;
  const UNBONDING_PERIOD = 20n;

  beforeEach(async function () {
    [owner, user1, user2] = await hre.ethers.getSigners();

    // Deploy Mock NFT
    const MockNFT = await hre.ethers.getContractFactory("MockNFT");
    mockNFT = await MockNFT.deploy();
    await mockNFT.waitForDeployment();

    // Deploy NFTStaking
    const NFTStaking = await hre.ethers.getContractFactory("NFTStaking");
    nftStaking = await hre.upgrades.deployProxy(NFTStaking, [
      owner.address,
      await mockNFT.getAddress(),
      REWARD_PER_BLOCK,
      DELAY_PERIOD,
      UNBONDING_PERIOD,
    ]);
    await nftStaking.waitForDeployment();

    // Mint NFTs to user1
    await mockNFT.connect(owner).mint(user1.address, 1);
    await mockNFT.connect(owner).mint(user1.address, 2);
  });

  describe("Initialization", function () {
    it("Should initialize with correct values", async function () {
      expect(await nftStaking.owner()).to.equal(owner.address);
      expect(await nftStaking.nft()).to.equal(await mockNFT.getAddress());
      expect(await nftStaking.rewardPerBlock()).to.equal(REWARD_PER_BLOCK);
      expect(await nftStaking.delayPeriod()).to.equal(DELAY_PERIOD);
      expect(await nftStaking.unbondingPeriod()).to.equal(UNBONDING_PERIOD);
    });
  });

  describe("Staking", function () {
    it("Should allow staking NFT", async function () {
      const userMockNFT = mockNFT.connect(user1);
      const userStaking = nftStaking.connect(user1);

      await userMockNFT.approve(await nftStaking.getAddress(), 1);
      await userStaking.stake(1);

      const stakeInfo = await nftStaking.getStakeInfo(1);
      expect(stakeInfo.owner).to.equal(user1.address);
      expect(await mockNFT.ownerOf(1)).to.equal(await nftStaking.getAddress());
    });

    it("Should revert when staking non-owned NFT", async function () {
      const user2Staking = nftStaking.connect(user2);
      await expect(user2Staking.stake(1)).to.be.reverted;
    });
  });

  describe("Pause and Unpause", function () {
    it("Should allow owner to pause and unpause the contract", async function () {
      await nftStaking.connect(owner).pause();
      expect(await nftStaking.paused()).to.be.true;

      await nftStaking.connect(owner).unpause();
      expect(await nftStaking.paused()).to.be.false;
    });

    it("Should restrict and not allow staking when contract is paused", async function () {
      const userMockNFT = mockNFT.connect(user1);
      const userStaking = nftStaking.connect(user1);

      await userMockNFT.approve(await nftStaking.getAddress(), 1);

      await nftStaking.connect(owner).pause();
      await expect(userStaking.stake(1)).to.be.reverted;
    });

    it("Should restrict and not allow unstaking when contract is paused", async function () {
      const userMockNFT = mockNFT.connect(user1);
      const userStaking = nftStaking.connect(user1);

      await userMockNFT.approve(await nftStaking.getAddress(), 1);
      await userStaking.stake(1);

      await nftStaking.connect(owner).pause();
      await expect(userStaking.unstake(1)).to.be.reverted;
    });

    it("Should allow resume of staking and unstaking after unpausing", async function () {
      const userMockNFT = mockNFT.connect(user1);
      const userStaking = nftStaking.connect(user1);

      await userMockNFT.approve(await nftStaking.getAddress(), 1);
      await nftStaking.connect(owner).pause();
      await nftStaking.connect(owner).unpause();

      await userStaking.stake(1);
      const stakeInfo = await nftStaking.getStakeInfo(1);
      expect(stakeInfo.owner).to.equal(user1.address);

      await userStaking.unstake(1);
      const updatedStakeInfo = await nftStaking.getStakeInfo(1);
      expect(updatedStakeInfo.unbondingStart).to.be.gt(0);
    });
  });

  describe("Rewards", function () {
    it("Should track active stake count correctly", async function () {
      const userMockNFT = mockNFT.connect(user1);
      const userStaking = nftStaking.connect(user1);

      await userMockNFT.approve(await nftStaking.getAddress(), 1);
      await userStaking.stake(1);
      expect(await nftStaking.activeStakeCount(user1.address)).to.equal(1);

      await userStaking.unstake(1);
      expect(await nftStaking.activeStakeCount(user1.address)).to.equal(0);
    });
  });
});