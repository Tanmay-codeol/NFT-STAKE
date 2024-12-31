// SPDX-License-Identifier: MIT
pragma solidity ^0.8.22;

import {ERC20Upgradeable} from "@openzeppelin/contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol";
import {ERC20PausableUpgradeable} from "@openzeppelin/contracts-upgradeable/token/ERC20/extensions/ERC20PausableUpgradeable.sol";
import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import {OwnableUpgradeable} from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import {UUPSUpgradeable} from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import {IERC721} from "@openzeppelin/contracts/token/ERC721/IERC721.sol";

contract NFTStaking is
    Initializable,
    ERC20Upgradeable,
    ERC20PausableUpgradeable,
    OwnableUpgradeable,
    UUPSUpgradeable
{
    IERC721 public nft;
    uint256 public rewardPerBlock;
    uint256 public delayPeriod;
    uint256 public unbondingPeriod;

    struct Stake {
        uint256 tokenId;
        uint256 stakedAt;
        uint256 unbondingStart;
    }

    // New variables for optimization
    mapping(address => uint256) public lastRewardCalculation;
    mapping(address => uint256) public accumulatedRewards;
    mapping(address => uint256) public activeStakeCount;

    mapping(address => Stake[]) public stakes;
    mapping(address => uint256) public rewards;

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    function initialize(
        address initialOwner,
        address nftAddress,
        uint256 _rewardPerBlock,
        uint256 _delayPeriod,
        uint256 _unbondingPeriod
    ) public initializer {
        __ERC20_init("MyToken", "MTK");
        __ERC20Pausable_init();
        __Ownable_init(initialOwner);
        __UUPSUpgradeable_init();
        _transferOwnership(initialOwner);
        nft = IERC721(nftAddress);
        rewardPerBlock = _rewardPerBlock;
        delayPeriod = _delayPeriod;
        unbondingPeriod = _unbondingPeriod;
    }

    function stake(uint256 tokenId) external whenNotPaused {
        // Calculate and update accumulated rewards before adding new stake
        _updateRewards(msg.sender);

        nft.transferFrom(msg.sender, address(this), tokenId);
        stakes[msg.sender].push(Stake(tokenId, block.number, 0));
        activeStakeCount[msg.sender]++;
    }

    function unstake(uint256 tokenId) external whenNotPaused {
        _updateRewards(msg.sender);

        Stake[] storage userStakes = stakes[msg.sender];
        for (uint256 i = 0; i < userStakes.length; i++) {
            if (
                userStakes[i].tokenId == tokenId &&
                userStakes[i].unbondingStart == 0
            ) {
                userStakes[i].unbondingStart = block.number;
                activeStakeCount[msg.sender]--;
                return;
            }
        }
        revert("Token not staked or already unstaking");
    }

    function withdraw(uint256 tokenId) external {
        Stake[] storage userStakes = stakes[msg.sender];
        for (uint256 i = 0; i < userStakes.length; i++) {
            if (
                userStakes[i].tokenId == tokenId &&
                userStakes[i].unbondingStart > 0
            ) {
                require(
                    block.number >=
                        userStakes[i].unbondingStart + unbondingPeriod,
                    "Unbonding period not over"
                );
                nft.transferFrom(address(this), msg.sender, tokenId);
                userStakes[i] = userStakes[userStakes.length - 1];
                userStakes.pop();
                return;
            }
        }
        revert("Token not unstaking or already withdrawn");
    }

    // New internal function to update rewards
    function _updateRewards(address user) internal {
        uint256 lastCalculation = lastRewardCalculation[user];
        if (lastCalculation > 0 && activeStakeCount[user] > 0) {
            uint256 blocksPassed = block.number - lastCalculation;
            accumulatedRewards[user] +=
                blocksPassed *
                rewardPerBlock *
                activeStakeCount[user];
        }
        lastRewardCalculation[user] = block.number;
    }

    // Optimized rewards calculation
    function calculateRewards(address user) internal view returns (uint256) {
        uint256 pendingRewards = accumulatedRewards[user];

        // Add the rewarrds from previos calculation
        if (activeStakeCount[user] > 0) {
            uint256 blocksSinceLastCalculation = block.number -
                lastRewardCalculation[user];
            pendingRewards +=
                blocksSinceLastCalculation *
                rewardPerBlock *
                activeStakeCount[user];
        }

        return pendingRewards;
    }

    function claimRewards() external {
        require(
            block.number >= rewards[msg.sender] + delayPeriod,
            "Delay period not over"
        );

        _updateRewards(msg.sender);
        uint256 reward = accumulatedRewards[msg.sender];
        accumulatedRewards[msg.sender] = 0;
        rewards[msg.sender] = block.number;

        _mint(msg.sender, reward);
    }

    function updateRewardPerBlock(
        uint256 newRewardPerBlock
    ) external onlyOwner {
        rewardPerBlock = newRewardPerBlock;
    }

    function _authorizeUpgrade(
        address newImplementation
    ) internal override onlyOwner {}

    function pause() public onlyOwner {
        _pause();
    }

    function unpause() public onlyOwner {
        _unpause();
    }

    function _update(
        address from,
        address to,
        uint256 value
    ) internal override(ERC20Upgradeable, ERC20PausableUpgradeable) {
        super._update(from, to, value);
    }
}
