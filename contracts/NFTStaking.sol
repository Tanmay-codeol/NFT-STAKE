// SPDX-License-Identifier: MIT
// Compatible with OpenZeppelin Contracts ^5.0.0
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
        nft.transferFrom(msg.sender, address(this), tokenId);
        stakes[msg.sender].push(Stake(tokenId, block.number, 0));
    }

    function unstake(uint256 tokenId) external whenNotPaused {
        Stake[] storage userStakes = stakes[msg.sender];
        for (uint256 i = 0; i < userStakes.length; i++) {
            if (
                userStakes[i].tokenId == tokenId &&
                userStakes[i].unbondingStart == 0
            ) {
                userStakes[i].unbondingStart = block.number;
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

    function claimRewards() external {
        require(
            block.number >= rewards[msg.sender] + delayPeriod,
            "Delay period not over"
        );
        uint256 reward = calculateRewards(msg.sender);
        rewards[msg.sender] = block.number;
        _mint(msg.sender, reward);
    }

    function calculateRewards(address user) internal view returns (uint256) {
        Stake[] storage userStakes = stakes[user];
        uint256 totalReward = 0;
        for (uint256 i = 0; i < userStakes.length; i++) {
            if (userStakes[i].unbondingStart == 0) {
                totalReward +=
                    (block.number - userStakes[i].stakedAt) *
                    rewardPerBlock;
            } else {
                totalReward +=
                    (userStakes[i].unbondingStart - userStakes[i].stakedAt) *
                    rewardPerBlock;
            }
        }
        return totalReward;
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
