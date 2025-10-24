# Onchain Library Protocol (OLP)
A modular Ethereum-based protocol that lets communities catalog, acquire, lend, and fund books (and other media) with on-chain transparency while the actual materials stay in the real world.

OLP is designed as a public library you can fork. It provides verifiable records for catalog metadata, branch inventories, membership, borrowing attestations, and funding flows—without forcing every file or physical item on-chain.

## Why OLP exists
- Empower local stewards, schools, and DAOs to run shared catalogs with transparent rules.
- Offer borrowers portable membership cards and time-bound loan attestations.
- Unlock community-driven acquisition, grants, and retroactive rewards for curators.
- Respect patron privacy and copyright while embracing open-licensed knowledge.

## On-chain vs off-chain
- **On-chain truth + money**: catalog IDs, license hashes, branch inventory balances, membership cards, deposit/late-fee rules, acquisition proposals, grants, loan attestations.
- **Off-chain assets**: digital files (IPFS/S3), physical copies tagged with NFC/QR, local circulation logs, steward playbooks.

## Core protocol objects
- **Work**: a title/resource (book, zine, dataset, toolkit).
- **Copy**: a specific digital license or physical item tied to a Work.
- **Member Card**: a non-transferable NFT (SBT) granting borrowing rights.
- **Loan Token**: a time-limited NFT minted when borrowing; burns on completion; may escrow deposits.
- **Branch**: a library node (school, community space, DAO, pop-up library).

## Repository structure
- `contracts/LibraryCatalog.sol` – ERC-1155 catalog tracking works, copies, and loan lifecycle.
- `contracts/LibraryMembership.sol` – Soulbound ERC-721 membership cards managed by stewards.
- `roadmap.md` – Curated task list and milestone tracker (not yet published).

## Current smart contracts
| Contract | Description | Status |
| --- | --- | --- |
| `LibraryCatalog` | Registers works, manages branch-held copies, enforces deposits and loan durations. | Prototype |
| `LibraryMembership` | Issues non-transferable membership NFTs to authorized borrowers. | Prototype |

### Key flows (v0)
1. **Borrow (digital or physical)**: Member requests a copy → `Loan Token` minted via `LibraryCatalog` → deposit escrowed → due date recorded.
2. **Return**: Borrower returns copy → NFT burned internally via transfer back to branch → deposit refunded if on time; late returns flagged.
3. **Stewardship**: Branch owner configures loan duration, deposit amount, and membership contract; only stewards can add books or mint copies.

## Getting started
Option A: Foundry (recommended for contracts)

```bash
forge --version             # ensure Foundry is installed
forge install OpenZeppelin/openzeppelin-contracts
forge test -vv
```

Option B: Hardhat (WIP)

```bash
pnpm install
pnpm test
```

> Tooling assumptions: Foundry for Solidity tests with OZ remapping. Hardhat support can be added if preferred.

### Local development checklist
- Configure `.env` with RPC URLs and deployer keys before deploying.
- Ensure the branch address holds catalog copies before testing loan logic.
- Use mock borrowers and simulated time jumps to cover overdue paths.

## Protocol design pillars
- **Modular**: Swap out catalog, membership, governance modules without rewriting core flows.
- **Compliant**: Default to open-licensed digital content; support fast takedowns for disputes.
- **Community-first**: Grants, quadratic boosts, and retro tips reward contributors.
- **Privacy-aware**: On-chain data avoids personal identifiers; hashes or ZK attestations are used for borrower logs.
- **Upgrade-ready**: Future releases will add reputation scoring, branch federation, and acquisition marketplaces.

## Governance roles
- **Stewards**: configure policies, approve new branches, curate metadata, respond to disputes.
- **Members**: borrow items, propose acquisitions, participate in votes.
- **Curators**: enrich metadata, verify licenses, and earn retro rewards.
- **Donors/Grantors**: fund branches or thematic “shelves,” optionally via quadratic matches.

## Physical vs digital flows
- **Digital circulation**: Loan token unlocks DRM/capability-gated file; auto-expires after `N` days with optional deposit slashing.
- **Physical circulation**: NFC/QR tag ties the item to its on-chain `Copy ID`; scanning mints and settles loans at checkout and return.
- **Depositless mode**: Integrate reputation scores to limit borrowing instead of using deposits.

## Contributing
1. Fork the repository and create a feature branch (`feature/add-loan-ext`).
2. Write tests for your changes (integration + edge cases).
3. Submit a PR describing the problem, solution, and testing evidence.
4. Coordinate audits for high-impact contract changes.

We welcome protocol design feedback, governance playbooks, and tooling contributions. Reach out via issues or community channels to coordinate work.

## License
OLP is released under the GNU GPL 3.0 License. See `LICENSE` for details.
