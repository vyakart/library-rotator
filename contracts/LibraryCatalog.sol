// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";
import "@openzeppelin/contracts/utils/Address.sol";

interface ILibraryMembership {
    function balanceOf(address owner) external view returns (uint256);
}

/**
 * @title LibraryCatalog
 * @notice Basic on-chain catalog to register library books and their metadata.
 * @dev Provides minimal Ownable-style access control for administrative actions.
 */
contract LibraryCatalog is ERC1155 {
    struct Book {
        string title;
        string author;
        string ipfsHash; // legacy content pointer (e.g., cover)
        string licenseInfo; // legacy license field
        string manifestURI; // JSON manifest with multi-format assets
        string provenanceURI; // external provenance record or dataset
        uint8 copyTypeFlags; // bitmask: 1=digital, 2=physical (can be both)
        string[] contributors; // optional list of contributors/credits
        bool paused; // takedown/pause flag
    }

    event BookAdded(uint256 indexed bookId, string title, string author, string ipfsHash, string license);
    event BookUpdated(uint256 indexed bookId);
    event BookContributorsUpdated(uint256 indexed bookId, uint256 count);
    event BookPaused(uint256 indexed bookId, bool paused);
    event BookBorrowed(address indexed borrower, uint256 indexed bookId, uint256 dueDate);
    event BookReturned(address indexed borrower, uint256 indexed bookId, bool late);
    event DepositForfeited(address indexed borrower, uint256 indexed bookId, uint256 amount);
    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);
    event CuratorSet(address indexed account, bool allowed);
    event BranchAddressUpdated(address indexed oldBranch, address indexed newBranch);
    event LoanDurationUpdated(uint256 oldDuration, uint256 newDuration);
    event DepositAmountUpdated(uint256 oldAmount, uint256 newAmount);
    event MembershipContractUpdated(address indexed oldContract, address indexed newContract);
    event GracePeriodUpdated(uint256 oldPeriod, uint256 newPeriod);
    event ExtensionPolicyUpdated(uint256 oldExtDuration, uint256 newExtDuration, uint8 oldMax, uint8 newMax);
    event LoanExtended(address indexed borrower, uint256 indexed bookId, uint256 newDueDate, uint8 usedExtensions);
    event ForfeitedWithdrawn(address indexed to, uint256 amount);

    address private _owner;
    uint256 private _nextBookId = 1;
    mapping(uint256 => Book) private _books;
    address public branchAddress;
    uint256 public loanDuration = 14 days;
    uint256 public depositAmount = 0.01 ether;
    uint256 public gracePeriod; // optional grace period after due date
    uint256 public extensionDuration = 7 days;
    uint8 public maxExtensions = 1;
    mapping(address => mapping(uint256 => uint256)) private _loanDueDates;
    mapping(address => mapping(uint256 => uint256)) private _loanDeposits;
    mapping(address => mapping(uint256 => uint8)) private _extensionsUsed;
    ILibraryMembership public membershipContract;
    mapping(address => bool) public isCurator;

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
    error MembershipContractNotSet();
    error InvalidMembershipContract(address membership);
    error NotCurator(address caller);
    error BookPaused(uint256 bookId);
    error MaxExtensionsReached(address borrower, uint256 bookId);
    error NoActiveLoan(address borrower, uint256 bookId);

    modifier onlyOwner() {
        if (msg.sender != _owner) {
            revert NotOwner(msg.sender);
        }
        _;
    }

    modifier onlyCuratorOrOwner() {
        if (msg.sender != _owner && !isCurator[msg.sender]) {
            revert NotCurator(msg.sender);
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
            licenseInfo: licenseInfo,
            manifestURI: "",
            provenanceURI: "",
            copyTypeFlags: 0,
            contributors: new string[](0),
            paused: false
        });

        emit BookAdded(bookId, title, author, ipfsHash, licenseInfo);
    }

    function getBook(uint256 bookId)
        external
        view
        returns (
            string memory title,
            string memory author,
            string memory ipfsHash,
            string memory licenseInfo
        )
    {
        if (bookId == 0 || bookId >= _nextBookId) {
            revert BookNotFound(bookId);
        }

        Book storage book = _books[bookId];
        return (book.title, book.author, book.ipfsHash, book.licenseInfo);
    }

    function getBookExtended(uint256 bookId)
        external
        view
        returns (
            string memory title,
            string memory author,
            string memory ipfsHash,
            string memory licenseInfo,
            string memory manifestURI,
            string memory provenanceURI,
            uint8 copyTypeFlags,
            bool paused
        )
    {
        if (bookId == 0 || bookId >= _nextBookId) {
            revert BookNotFound(bookId);
        }
        Book storage book = _books[bookId];
        return (
            book.title,
            book.author,
            book.ipfsHash,
            book.licenseInfo,
            book.manifestURI,
            book.provenanceURI,
            book.copyTypeFlags,
            book.paused
        );
    }

    function getContributors(uint256 bookId) external view returns (string[] memory) {
        if (bookId == 0 || bookId >= _nextBookId) {
            revert BookNotFound(bookId);
        }
        return _books[bookId].contributors;
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
        address old = branchAddress;
        branchAddress = newBranch;
        emit BranchAddressUpdated(old, newBranch);
    }

    function setLoanDuration(uint256 newDuration) external onlyOwner {
        if (newDuration == 0) {
            revert InvalidLoanDuration(newDuration);
        }
        uint256 old = loanDuration;
        loanDuration = newDuration;
        emit LoanDurationUpdated(old, newDuration);
    }

    function setDepositAmount(uint256 newDepositAmount) external onlyOwner {
        if (newDepositAmount == 0) {
            revert InvalidDepositAmount(newDepositAmount);
        }
        uint256 old = depositAmount;
        depositAmount = newDepositAmount;
        emit DepositAmountUpdated(old, newDepositAmount);
    }

    function setMembershipContract(address membership) external onlyOwner {
        if (membership == address(0)) {
            revert InvalidMembershipContract(membership);
        }
        address old = address(membershipContract);
        membershipContract = ILibraryMembership(membership);
        emit MembershipContractUpdated(old, membership);
    }

    function isMember(address account) public view virtual returns (bool) {
        if (address(membershipContract) == address(0)) {
            return false;
        }
        return membershipContract.balanceOf(account) > 0;
    }

    function setCurator(address account, bool allowed) external onlyOwner {
        isCurator[account] = allowed;
        emit CuratorSet(account, allowed);
    }

    function updateBookCore(
        uint256 bookId,
        string calldata title,
        string calldata author,
        string calldata ipfsHash,
        string calldata licenseInfo,
        string calldata manifestURI,
        string calldata provenanceURI,
        uint8 copyTypeFlags
    ) external onlyCuratorOrOwner {
        if (bookId == 0 || bookId >= _nextBookId) {
            revert BookNotFound(bookId);
        }
        Book storage book = _books[bookId];
        book.title = title;
        book.author = author;
        book.ipfsHash = ipfsHash;
        book.licenseInfo = licenseInfo;
        book.manifestURI = manifestURI;
        book.provenanceURI = provenanceURI;
        book.copyTypeFlags = copyTypeFlags;
        emit BookUpdated(bookId);
    }

    function setContributors(uint256 bookId, string[] calldata contributors) external onlyCuratorOrOwner {
        if (bookId == 0 || bookId >= _nextBookId) {
            revert BookNotFound(bookId);
        }
        _books[bookId].contributors = contributors;
        emit BookContributorsUpdated(bookId, contributors.length);
    }

    function setBookPaused(uint256 bookId, bool paused) external onlyCuratorOrOwner {
        if (bookId == 0 || bookId >= _nextBookId) {
            revert BookNotFound(bookId);
        }
        _books[bookId].paused = paused;
        emit BookPaused(bookId, paused);
    }

    function borrowBook(uint256 bookId) external payable {
        if (address(membershipContract) == address(0)) {
            revert MembershipContractNotSet();
        }
        if (!isMember(msg.sender)) {
            revert MembershipRequired(msg.sender);
        }
        if (bookId == 0 || bookId >= _nextBookId) {
            revert BookNotFound(bookId);
        }
        if (branchAddress == address(0)) {
            revert InvalidBranch(branchAddress);
        }
        if (_books[bookId].paused) {
            revert BookPaused(bookId);
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
        bool late;
        if (gracePeriod > 0) {
            late = block.timestamp > (dueDate + gracePeriod);
        } else {
            late = block.timestamp > dueDate;
        }

        delete _loanDueDates[msg.sender][bookId];
        delete _loanDeposits[msg.sender][bookId];

        if (!late && deposit > 0) {
            Address.sendValue(payable(msg.sender), deposit);
        } else if (late && deposit > 0) {
            // hold forfeited deposit in contract until withdrawn by steward
            emit DepositForfeited(msg.sender, bookId, deposit);
        }

        emit BookReturned(msg.sender, bookId, late);
    }

    function requestExtension(uint256 bookId) external {
        uint256 dueDate = _loanDueDates[msg.sender][bookId];
        if (dueDate == 0) {
            revert NoActiveLoan(msg.sender, bookId);
        }
        if (block.timestamp > dueDate) {
            // cannot extend after due date passes
            revert NoActiveLoan(msg.sender, bookId);
        }
        uint8 used = _extensionsUsed[msg.sender][bookId];
        if (used >= maxExtensions) {
            revert MaxExtensionsReached(msg.sender, bookId);
        }
        uint256 oldDue = dueDate;
        uint256 newDue = oldDue + extensionDuration;
        _loanDueDates[msg.sender][bookId] = newDue;
        _extensionsUsed[msg.sender][bookId] = used + 1;
        emit LoanExtended(msg.sender, bookId, newDue, used + 1);
    }

    function setGracePeriod(uint256 newGrace) external onlyOwner {
        uint256 old = gracePeriod;
        gracePeriod = newGrace;
        emit GracePeriodUpdated(old, newGrace);
    }

    function setExtensionPolicy(uint256 newExtensionDuration, uint8 newMaxExtensions) external onlyOwner {
        uint256 oldDur = extensionDuration;
        uint8 oldMax = maxExtensions;
        extensionDuration = newExtensionDuration;
        maxExtensions = newMaxExtensions;
        emit ExtensionPolicyUpdated(oldDur, newExtensionDuration, oldMax, newMaxExtensions);
    }

    function withdrawForfeited(address payable to, uint256 amount) external onlyOwner {
        require(to != address(0), "invalid to");
        Address.sendValue(to, amount);
        emit ForfeitedWithdrawn(to, amount);
    }

    function loanDueDateOf(address borrower, uint256 bookId) external view returns (uint256) {
        return _loanDueDates[borrower][bookId];
    }

    function loanDepositOf(address borrower, uint256 bookId) external view returns (uint256) {
        return _loanDeposits[borrower][bookId];
    }
}
