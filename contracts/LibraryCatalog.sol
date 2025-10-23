// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";
import "@openzeppelin/contracts/utils/Address.sol";

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
    event BookBorrowed(address indexed borrower, uint256 indexed bookId, uint256 dueDate);
    event BookReturned(address indexed borrower, uint256 indexed bookId, bool late);
    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

    address private _owner;
    uint256 private _nextBookId = 1;
    mapping(uint256 => Book) private _books;
    address public branchAddress;
    uint256 public loanDuration = 14 days;
    uint256 public depositAmount = 0.01 ether;
    mapping(address => mapping(uint256 => uint256)) private _loanDueDates;
    mapping(address => mapping(uint256 => uint256)) private _loanDeposits;

    error NotOwner(address caller);
    error InvalidNewOwner(address newOwner);
    error BookNotFound(uint256 bookId);
    error InvalidMintAmount(uint256 amount);
    error MembershipRequired(address borrower);
    error BookUnavailable(uint256 bookId);
    error ActiveLoan(address borrower, uint256 bookId);
    error LoanNotFound(address borrower, uint256 bookId);
    error BorrowerNotHolder(address borrower, uint256 bookId);
    error DepositTooLow(uint256 sent, uint256 required);
    error InvalidBranch(address branch);
    error InvalidLoanDuration(uint256 duration);
    error InvalidDepositAmount(uint256 amount);

    modifier onlyOwner() {
        if (msg.sender != _owner) {
            revert NotOwner(msg.sender);
        }
        _;
    }

    constructor(string memory baseURI) ERC1155(baseURI) {
        _owner = msg.sender;
        branchAddress = msg.sender;
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

    function setBranchAddress(address newBranch) external onlyOwner {
        if (newBranch == address(0)) {
            revert InvalidBranch(newBranch);
        }
        branchAddress = newBranch;
    }

    function setLoanDuration(uint256 newDuration) external onlyOwner {
        if (newDuration == 0) {
            revert InvalidLoanDuration(newDuration);
        }
        loanDuration = newDuration;
    }

    function setDepositAmount(uint256 newDepositAmount) external onlyOwner {
        if (newDepositAmount == 0) {
            revert InvalidDepositAmount(newDepositAmount);
        }
        depositAmount = newDepositAmount;
    }

    function isMember(address account) public view virtual returns (bool) {
        return account == _owner;
    }

    function borrowBook(uint256 bookId) external payable {
        if (!isMember(msg.sender)) {
            revert MembershipRequired(msg.sender);
        }
        if (bookId == 0 || bookId >= _nextBookId) {
            revert BookNotFound(bookId);
        }
        if (branchAddress == address(0)) {
            revert InvalidBranch(branchAddress);
        }
        if (_loanDueDates[msg.sender][bookId] != 0) {
            revert ActiveLoan(msg.sender, bookId);
        }
        if (msg.value < depositAmount) {
            revert DepositTooLow(msg.value, depositAmount);
        }
        if (balanceOf(branchAddress, bookId) == 0) {
            revert BookUnavailable(bookId);
        }

        uint256 dueDate = block.timestamp + loanDuration;

        _loanDueDates[msg.sender][bookId] = dueDate;
        _loanDeposits[msg.sender][bookId] = msg.value;

        _safeTransferFrom(branchAddress, msg.sender, bookId, 1, "");

        emit BookBorrowed(msg.sender, bookId, dueDate);
    }

    function returnBook(uint256 bookId) external {
        uint256 dueDate = _loanDueDates[msg.sender][bookId];
        if (dueDate == 0) {
            revert LoanNotFound(msg.sender, bookId);
        }
        if (balanceOf(msg.sender, bookId) == 0) {
            revert BorrowerNotHolder(msg.sender, bookId);
        }

        _safeTransferFrom(msg.sender, branchAddress, bookId, 1, "");

        uint256 deposit = _loanDeposits[msg.sender][bookId];
        bool late = block.timestamp > dueDate;

        delete _loanDueDates[msg.sender][bookId];
        delete _loanDeposits[msg.sender][bookId];

        if (!late && deposit > 0) {
            Address.sendValue(payable(msg.sender), deposit);
        }

        emit BookReturned(msg.sender, bookId, late);
    }
}
