// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

/**
 * @title LibraryMembership
 * @notice Soulbound ERC-721 token representing membership eligibility for the library.
 */
contract LibraryMembership is ERC721, Ownable {
    error AlreadyMember(address account);
    error NonTransferable();
    error InvalidRecipient(address account);

    uint256 private _nextTokenId;

    constructor(address initialOwner) ERC721("LibraryMembership", "LIBCARD") Ownable(initialOwner) {}

    function issueCard(address to) external onlyOwner returns (uint256 tokenId) {
        if (to == address(0)) {
            revert InvalidRecipient(to);
        }
        if (balanceOf(to) != 0) {
            revert AlreadyMember(to);
        }

        tokenId = ++_nextTokenId;
        _safeMint(to, tokenId);
    }

    function revokeCard(uint256 tokenId) external onlyOwner {
        _burn(tokenId);
    }

    function transferFrom(address, address, uint256) public virtual override {
        revert NonTransferable();
    }

    function safeTransferFrom(address, address, uint256) public virtual override {
        revert NonTransferable();
    }

    function safeTransferFrom(address, address, uint256, bytes memory) public virtual override {
        revert NonTransferable();
    }

    function approve(address, uint256) public virtual override {
        revert NonTransferable();
    }

    function setApprovalForAll(address, bool) public virtual override {
        revert NonTransferable();
    }

    function _update(address to, uint256 tokenId, address auth) internal virtual override returns (address) {
        address from = _ownerOf(tokenId);
        if (from != address(0) && to != address(0)) {
            revert NonTransferable();
        }
        return super._update(to, tokenId, auth);
    }
}
