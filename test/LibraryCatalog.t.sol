// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import "contracts/LibraryCatalog.sol";
import "contracts/LibraryMembership.sol";

interface Vm {
    function warp(uint256) external;
}

contract LibraryCatalogTest {
    Vm constant vm = Vm(address(uint160(uint256(keccak256("hevm cheat code")))));

    LibraryCatalog private catalog;
    LibraryMembership private membership;
    uint256 private bookId;

    receive() external payable {}

    function setUp() public {
        catalog = new LibraryCatalog("ipfs://base/{id}");
        membership = new LibraryMembership(address(this));
        catalog.setMembershipContract(address(membership));

        // Add a book and mint 1 copy to branch (deployer is branch)
        bookId = catalog.addBook("Title", "Author", "QmHash", "CC-BY");
        catalog.mintCopies(address(this), bookId, 1);

        // Issue membership to this contract
        membership.issueCard(address(this));
    }

    function testBorrowAndReturnOnTime() public {
        setUp();
        uint256 preBalance = address(this).balance;

        // Borrow with deposit
        catalog.borrowBook{value: catalog.depositAmount()}(bookId);
        // Move time just before due date
        uint256 due = catalog.loanDueDateOf(address(this), bookId);
        vm.warp(due - 1);
        // Return on time
        catalog.returnBook(bookId);

        // Deposit refunded
        uint256 postBalance = address(this).balance;
        assert(postBalance == preBalance);
    }

    function testBorrowLateForfeit() public {
        setUp();
        uint256 preBalance = address(this).balance;

        // Configure small grace period
        catalog.setGracePeriod(0);

        // Borrow
        catalog.borrowBook{value: catalog.depositAmount()}(bookId);

        // Advance past due
        uint256 due = catalog.loanDueDateOf(address(this), bookId);
        vm.warp(due + 1);

        // Return late
        catalog.returnBook(bookId);

        // Deposit not refunded
        uint256 postBalance = address(this).balance;
        assert(postBalance + catalog.depositAmount() == preBalance);
    }

    function testExtensionAndGrace() public {
        setUp();
        catalog.setGracePeriod(2 days);
        catalog.setExtensionPolicy(3 days, 2);

        // Borrow
        catalog.borrowBook{value: catalog.depositAmount()}(bookId);
        uint256 due1 = catalog.loanDueDateOf(address(this), bookId);

        // Request extension before due
        vm.warp(due1 - 10);
        catalog.requestExtension(bookId);
        uint256 due2 = catalog.loanDueDateOf(address(this), bookId);
        assert(due2 == due1 + 3 days);

        // Return within grace after extended due
        vm.warp(due2 + 1 days);
        uint256 pre = address(this).balance;
        catalog.returnBook(bookId);
        uint256 post = address(this).balance;
        // within grace → refunded
        assert(post == pre);
    }
}

