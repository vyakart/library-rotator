// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";

/**
 * @title LibraryCatalog
 * @notice Basic on-chain catalog to register library books and their metadata.
 * @dev Provides minimal Ownable-style access control for administrative actions.
 */
contract LibraryCatalog is ERC1155 {
    struct Book {
        string title;
        string author;
        string ipfsHash;
        string licenseInfo;
    }

    event BookAdded(uint256 indexed bookId, string title, string author, string ipfsHash, string license);
    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

    address private _owner;
    uint256 private _nextBookId = 1;
    mapping(uint256 => Book) private _books;

    error NotOwner(address caller);
    error InvalidNewOwner(address newOwner);
    error BookNotFound(uint256 bookId);
    error InvalidMintAmount(uint256 amount);

    modifier onlyOwner() {
        if (msg.sender != _owner) {
            revert NotOwner(msg.sender);
        }
        _;
    }

    constructor(string memory baseURI) ERC1155(baseURI) {
        _owner = msg.sender;
        emit OwnershipTransferred(address(0), msg.sender);
    }

    function owner() public view returns (address) {
        return _owner;
    }

    function transferOwnership(address newOwner) public onlyOwner {
        if (newOwner == address(0)) {
            revert InvalidNewOwner(newOwner);
        }
        address previousOwner = _owner;
        _owner = newOwner;
        emit OwnershipTransferred(previousOwner, newOwner);
    }

    function renounceOwnership() public onlyOwner {
        address previousOwner = _owner;
        _owner = address(0);
        emit OwnershipTransferred(previousOwner, address(0));
    }

    function addBook(
        string calldata title,
        string calldata author,
        string calldata ipfsHash,
        string calldata licenseInfo
    ) external onlyOwner returns (uint256 bookId) {
        bookId = _nextBookId++;

        _books[bookId] = Book({
            title: title,
            author: author,
            ipfsHash: ipfsHash,
            licenseInfo: licenseInfo
        });

        emit BookAdded(bookId, title, author, ipfsHash, licenseInfo);
    }

    function getBook(uint256 bookId)
        external
        view
        returns (string memory title, string memory author, string memory ipfsHash, string memory licenseInfo)
    {
        if (bookId == 0 || bookId >= _nextBookId) {
            revert BookNotFound(bookId);
        }

        Book storage book = _books[bookId];
        return (book.title, book.author, book.ipfsHash, book.licenseInfo);
    }

    function totalBooks() external view returns (uint256) {
        return _nextBookId - 1;
    }

    function mintCopies(address to, uint256 bookId, uint256 amount) external onlyOwner {
        if (bookId == 0 || bookId >= _nextBookId) {
            revert BookNotFound(bookId);
        }
        if (amount == 0) {
            revert InvalidMintAmount(amount);
        }

        _mint(to, bookId, amount, "");
    }
}
