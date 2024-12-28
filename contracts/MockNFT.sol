// SPDX-License-Identifier: MIT

pragma solidity ^0.8.22;



import "@openzeppelin/contracts/token/ERC721/ERC721.sol";

import "@openzeppelin/contracts/access/Ownable.sol";



contract MockNFT is ERC721, Ownable {

    constructor() ERC721("MockNFT", "MNFT") Ownable(msg.sender) {}



    function mint(address to, uint256 tokenId) public onlyOwner {

        _mint(to, tokenId);

    }

}
