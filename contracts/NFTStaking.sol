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
    struct StakeInfo {
        address owner; // Owner of the stake
        uint96 stakedAt; // Block number when staked
        uint96 unbondingStart; // Block number when unbonding started
    }

    IERC721 public nft;
    uint96 public rewardPerBlock;
    uint32 public delayPeriod;
    uint32 public unbondingPeriod;

    mapping(address => uint256) public lastRewardCalculation;
    mapping(address => uint256) public accumulatedRewards;
    mapping(address => uint32) public activeStakeCount;
    mapping(address => uint256) public rewards;

    // New mapping to track token stakes directly
    mapping(uint256 => StakeInfo) public tokenStakes;

    error NotTokenOwner();
    error TokenNotStaked();
    error TokenAlreadyStaked();
    error UnbondingPeriodNotOver();
    error DelayPeriodNotOver();
    error TokenNotUnstaking();

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    function initialize(
        address initialOwner,
        address nftAddress,
        uint96 _rewardPerBlock,
        uint32 _delayPeriod,
        uint32 _unbondingPeriod
    ) public initializer {
        __ERC20_init("MyToken", "MTK");
        __ERC20Pausable_init();
        __Ownable_init(initialOwner);
        __UUPSUpgradeable_init();

        nft = IERC721(nftAddress);
        rewardPerBlock = _rewardPerBlock;
        delayPeriod = _delayPeriod;
        unbondingPeriod = _unbondingPeriod;
    }

    function stake(uint256 tokenId) external whenNotPaused {
        if (tokenStakes[tokenId].owner != address(0))
            revert TokenAlreadyStaked();

        _updateRewards(msg.sender);

        nft.transferFrom(msg.sender, address(this), tokenId);

        tokenStakes[tokenId] = StakeInfo({
            owner: msg.sender,
            stakedAt: uint96(block.number),
            unbondingStart: 0
        });

        unchecked {
            activeStakeCount[msg.sender]++;
        }
    }

    function unstake(uint256 tokenId) external whenNotPaused {
        StakeInfo storage stakeInfo = tokenStakes[tokenId];

        if (stakeInfo.owner != msg.sender) revert NotTokenOwner();
        if (stakeInfo.unbondingStart != 0) revert TokenNotStaked();

        _updateRewards(msg.sender);

        stakeInfo.unbondingStart = uint96(block.number);
        unchecked {
            activeStakeCount[msg.sender]--;
        }
    }

    function withdraw(uint256 tokenId) external {
        StakeInfo storage stakeInfo = tokenStakes[tokenId];

        if (stakeInfo.owner != msg.sender) revert NotTokenOwner();
        if (stakeInfo.unbondingStart == 0) revert TokenNotUnstaking();
        if (block.number < stakeInfo.unbondingStart + unbondingPeriod) {
            revert UnbondingPeriodNotOver();
        }

        nft.transferFrom(address(this), msg.sender, tokenId);
        delete tokenStakes[tokenId];
    }

    function _updateRewards(address user) internal {
        uint256 lastCalculation = lastRewardCalculation[user];
        uint32 activeStakes = activeStakeCount[user];

        if (lastCalculation > 0 && activeStakes > 0) {
            unchecked {
                uint256 blocksPassed = block.number - lastCalculation;
                accumulatedRewards[user] +=
                    blocksPassed *
                    rewardPerBlock *
                    activeStakes;
            }
        }
        lastRewardCalculation[user] = block.number;
    }

    function calculateRewards(address user) internal view returns (uint256) {
        uint256 pendingRewards = accumulatedRewards[user];
        uint32 activeStakes = activeStakeCount[user];

        if (activeStakes > 0) {
            unchecked {
                uint256 blocksSinceLastCalculation = block.number -
                    lastRewardCalculation[user];
                pendingRewards +=
                    blocksSinceLastCalculation *
                    rewardPerBlock *
                    activeStakes;
            }
        }

        return pendingRewards;
    }

    function claimRewards() external {
        if (block.number < rewards[msg.sender] + delayPeriod) {
            revert DelayPeriodNotOver();
        }

        _updateRewards(msg.sender);
        uint256 reward = accumulatedRewards[msg.sender];
        accumulatedRewards[msg.sender] = 0;
        rewards[msg.sender] = block.number;

        _mint(msg.sender, reward);
    }

    function getStakeInfo(
        uint256 tokenId
    )
        external
        view
        returns (address owner, uint96 stakedAt, uint96 unbondingStart)
    {
        StakeInfo memory info = tokenStakes[tokenId];
        return (info.owner, info.stakedAt, info.unbondingStart);
    }

    function updateRewardPerBlock(uint96 newRewardPerBlock) external onlyOwner {
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
