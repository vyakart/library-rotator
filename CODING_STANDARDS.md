# Coding Standards

- Solidity version: `^0.8.23`.
- Use custom errors over require strings for gas efficiency.
- Emit events for all state-changing config updates and important lifecycle actions.
- Favor `onlyOwner` for steward controls; add granular roles (e.g., curator) where needed.
- Reentrancy: avoid external calls before state updates; use OZ helpers where possible.
- Use explicit getters for important mappings; avoid exposing raw storage.
- Prefer minimal structs with explicit setters; store URIs/hashes over large blobs.
- Testing: Foundry with deterministic setup and cheatcodes (`vm.warp`) for time.
- Linting: `solhint` (recommended config), naming per Solidity style guide.

## Project Tooling
- Foundry config at `foundry.toml` with OZ remapping.
- Install dependencies:
  - `forge install OpenZeppelin/openzeppelin-contracts` (creates `lib/openzeppelin-contracts`)
- Run tests: `forge test -vv`.

## Contract Patterns
- ERC-1155 for catalog copies; ERC-721 SBT for membership.
- Deposits escrowed in contract and refunded or forfeited based on due + grace.
- Curator role can update metadata and pause specific books.
- Extensions: borrower can extend up to `maxExtensions` by `extensionDuration` each time.
