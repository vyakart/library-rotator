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
    error InvalidTier(uint8 tier);

    uint256 private _nextTokenId;
    // 0 = none/unknown, 1 = free, 2 = paid, 3 = partner (customizable)
    mapping(uint256 => uint8) private _tierOfToken;
    mapping(address => uint256) private _tokenOf;

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
        _tierOfToken[tokenId] = 1; // default to free
        _tokenOf[to] = tokenId;
    }

    function issueCardWithTier(address to, uint8 tier) external onlyOwner returns (uint256 tokenId) {
        if (to == address(0)) {
            revert InvalidRecipient(to);
        }
        if (balanceOf(to) != 0) {
            revert AlreadyMember(to);
        }
        if (tier == 0) {
            revert InvalidTier(tier);
        }
        tokenId = ++_nextTokenId;
        _safeMint(to, tokenId);
        _tierOfToken[tokenId] = tier;
        _tokenOf[to] = tokenId;
    }

    function setTier(uint256 tokenId, uint8 tier) external onlyOwner {
        if (_ownerOf(tokenId) == address(0)) revert("invalid token");
        if (tier == 0) {
            revert InvalidTier(tier);
        }
        _tierOfToken[tokenId] = tier;
    }

    function tierOfToken(uint256 tokenId) external view returns (uint8) {
        return _tierOfToken[tokenId];
    }

    function tierOf(address account) external view returns (uint8) {
        uint256 tid = _tokenOf[account];
        if (tid == 0) return 0;
        return _tierOfToken[tid];
    }

    function revokeCard(uint256 tokenId) external onlyOwner {
        address owner = _ownerOf(tokenId);
        if (owner != address(0)) {
            delete _tokenOf[owner];
        }
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
        address prev = super._update(to, tokenId, auth);
        // maintain reverse index only on mint/burn
        if (to == address(0)) {
            if (from != address(0)) delete _tokenOf[from];
        } else if (from == address(0)) {
            _tokenOf[to] = tokenId;
        }
        return prev;
    }
}
