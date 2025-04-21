# Wrapped Hyperliquid USDC

An ERC20 stablecoin on HyperEVM fully backed by Hyperliquid L1 USDC (Spot).

## How to mint

Using precompiles, smart contracts can send spot assets on the Hyperliquid L1. Users and contracts can mint HLUSDC by sending L1 spot USDC to the HLUSDC contract. To address HyperEVM precompiles non-atomic behaviour, we introduce a 4 steps mint process:

1. Creates an `HLUSDCIssuer` account
2. Sends USDC (Spot) to HLUSDCIssuer on Hyperliquid L1
3. Invoke `initiateMintRequest`, which takes a snapshot of the account's L1 spot balance, locks the contract and initiate precompiles `sendSpot` to transfer USDC (Spot) to HLUSDC on Hyperliquid L1
4. `completeMint` checks that the new `spot balance == spotBalanceSnapshot - mintAmount`, which indicates mintAmount was sent to HLUSDC contract because in locked state, no other functions can sendSpot on Hyperliquid L1.

A successful `completeMint` will mint HLUSDC to `HLUSDCIssuer` and transfer to specified destination.

## How to withdraw

Withdrawing is easy, anyone with HLUSDC can withdraw with a single function call. Note that a withdrawal fee is applied to cover the Hyperliquid L1 account activiation fee. There is no easy way to check if an account has been activated on the L1 so the withdrawal fee is applied to every withdrawal.

1. Send a `withdraw` call to `HLUSDC` to withdraw.

### Deployed addresses

| Contract            | Address (Testnet)                          |
| ------------------- | ------------------------------------------ |
| HLUSDCIssuerFactory | 0xe9f91fcc2552224d10e7b3fcde0c99a9d6b866b3 |
| HLUSDC              | 0xd8b4ac834d667ec92d0e2ecb31466bc434a3de93 |

# Disclaimer

This is an **experimental project** created for research purposes by the team at No Limit Holdings.

⚠️ **IMPORTANT WARNING** ⚠️

This codebase:

- Is NOT ready for production use
- Has NOT been professionally audited
- May contain critical bugs or security vulnerabilities
- Should be considered highly experimental

Users who choose to interact with or deploy this code do so entirely at their own risk. The developers accept no responsibility for any loss of funds, security incidents, or other damages that may result from its use.

This research project is provided "as is" without warranty of any kind, either expressed or implied.
