# [accounts](https://github.com/nanidao/accounts)  [![License: AGPL-3.0-only](https://img.shields.io/badge/License-AGPL-black.svg)](https://opensource.org/license/agpl-v3/) [![solidity](https://img.shields.io/badge/solidity-%5E0.8.26-black)](https://docs.soliditylang.org/en/v0.8.26/) [![Foundry](https://img.shields.io/badge/Built%20with-Foundry-000000.svg)](https://getfoundry.sh/) ![tests](https://github.com/nanidao/accounts/actions/workflows/ci.yml/badge.svg)

Simple extendable smart account implementations (*Smarter* `Accounts` or `NANI`). `v1.2.3`

Built with the *[Foundry](https://github.com/foundry-rs/forge-std)* testing suite and *[Solady](https://github.com/vectorized/solady)* solidity optimizations, this codebase demonstrates contemporary and efficient account abstractions through a representative [implementation](./src/Account.sol) (`Account`, `v1.2.3`) and [factory](./src/Accounts.sol) that deploys related `ERC1967` minimal proxies with `UUPS` upgradeability. As such, `Accounts` users can upgrade into any account implementation at any time from their NANI wallet, such as [`Kernel`](https://github.com/zerodevapp/kernel/tree/dev) or [Coinbase](https://github.com/coinbase/smart-wallet/tree/main), while the latest version of `NANI` `Accounts` will be maintained and deployed here.

All `Accounts` support the following standards: [`ERC173`](https://eips.ethereum.org/EIPS/eip-173), [`EIP712`](https://eips.ethereum.org/EIPS/eip-712), [`ERC1271`](https://eips.ethereum.org/EIPS/eip-1271), [`ERC1822`](https://eips.ethereum.org/EIPS/eip-1822), [`ERC1967`](https://eips.ethereum.org/EIPS/eip-1967), [`ERC2098`](https://eips.ethereum.org/EIPS/eip-2098), [`ERC4337`](https://eips.ethereum.org/EIPS/eip-4337), [`ERC5267`](https://eips.ethereum.org/EIPS/eip-5267), [`ERC6492`](https://eips.ethereum.org/EIPS/eip-6492), [`ERC7582`](https://eips.ethereum.org/EIPS/eip-7582)

Currently, `Accounts` is the [most optimized](https://github.com/zerodevapp/aa-benchmark) smart account implementation available to the public with a companion user interface on [`nani.ooo`](https://nani.ooo/). Incentives are designed for participation in testing and development. Governance of the `Accounts` implementation and interface models is also introduced in `v1.2.3`.

## Getting Started

Run: `curl -L https://foundry.paradigm.xyz | bash && source ~/.bashrc && foundryup`

Build the foundry project with `forge build`. Run contract tests with `forge test`. Measure gas fees with `forge snapshot`. Format code with `forge fmt`.

## Deployments

***v1.2.3***

Chain           | Factory                                 | Implementation                          | Commit
----------------|-----------------------------------------|-----------------------------------------|------------------------------------------
Ethereum, Arbitrum / Nova, Optimism, Base, Zora, Blast, Gnosis, Polygon / zkEVM, BNB, Avalanche & testnets | [0x0000000000009f1E546FC4A8F68eB98031846cb8](https://etherscan.io/address/0x0000000000009f1E546FC4A8F68eB98031846cb8#code) | [0x0000000000002259DC557B2D35A3Bbbf3A70eB75](https://etherscan.io/address/0x0000000000002259DC557B2D35A3Bbbf3A70eB75#code) | [ffe035982fc03887895bafde845ad17490063cdc](https://github.com/NaniDAO/Account/commit/ffe035982fc03887895bafde845ad17490063cdc)

#### Account URL (Unruggable): [0x0000000000004Bf084D1821a0d9D271A84E5c8E4](https://basescan.org/address/0x0000000000004bf084d1821a0d9d271a84e5c8e4#code)
> Set hard 'rug' limits for ETH txs

### [Plugin Validators](https://github.com/NaniDAO/accounts/tree/main/src/validators):

Utilizes [`ERC7582` minimal modular account](https://eips.ethereum.org/EIPS/eip-7582) interface.

#### JointValidator: [0x000000000000D3D2b2980A7BC509018E4d88e947](https://arbiscan.io/address/0x000000000000D3D2b2980A7BC509018E4d88e947#code)
> Add joint owners to your smart account with full concurrent rights
#### RecoveryValidator: [0x000000000000a78fB292191473E51Dd34700c43D](https://arbiscan.io/address/0x000000000000a78fB292191473E51Dd34700c43D#code)
> Add backups to your smart account (can set time delay and *m/n* scheme)
#### PaymentValidator: [0x00000000000032CD4FAE890F90e61e6864e44aa7](https://arbiscan.io/address/0x00000000000032CD4FAE890F90e61e6864e44aa7#code)
> Add payment plans and delegate token transfer permissions (*e.g.*, invoice agents)
#### PermitValidator: [0x000000000000ab6c9FF3ed50AC4BAF2a20890835](https://arbiscan.io/address/0x000000000000ab6c9FF3ed50AC4BAF2a20890835#code)
> Add arbitrary permissions within the Permit structure (*e.g.*, voting and swapping rights)
#### RemoteValidator: [0x0000000000159aAFCA7067005E28665a28B5B4cf](https://arbiscan.io/address/0x0000000000159aAFCA7067005E28665a28B5B4cf#code)
> Add simple scheduled transactions sequence (*e.g.*, DCA) or other 'remote' agent operations

### Plugin Owners:

#### [Dagon](https://github.com/Moloch-Mystics/dagon): [0x000000000000FEb893BB5D63bA33323EdCC237cE](https://arbiscan.io/address/0x000000000000FEb893BB5D63bA33323EdCC237cE#code)
> token-weighted ownership (simulates *multisig m/n* and *DAO* voting)
#### Keys: [0x000000000000B418eE0A5B649462Fb851B266522](https://arbiscan.io/address/0x000000000000B418eE0A5B649462Fb851B266522#code)
> token-bound ownership (NFTs are owners, *i.e.*, "my Milady is my key")

### Plugin Guards:

#### Guard: [0x00000000000076a46Ae808b2eDAE7b3f64EF5b31](https://arbiscan.io/address/0x00000000000076a46ae808b2edae7b3f64ef5b31#code)
> hard checks for smart accounts (*i.e.*, "can't spend more than 0.1 ETH")

### Paymaster:

#### NEETH (ARB): [0x00000000000009B4AB3f1bC2b029bd7513Fbd8ED](https://arbiscan.io/address/0x00000000000009B4AB3f1bC2b029bd7513Fbd8ED#code)
#### NEETH (BASE): [0x00000000000077E2072D61672eb6EC18a136c80A](https://basescan.org/address/0x00000000000077E2072D61672eb6EC18a136c80A#code)
> magic paymaster: stake ETH and use DeFi yield to sponsor transactions

## Blueprint

```txt
lib
├─ forge-std — https://github.com/foundry-rs/forge-std
├─ solady — https://github.com/vectorized/solady
src
├─ Account — Account Contract
├─ Accounts - Factory Contract
test
└─ Account.t - Test Contract
```

## Disclaimer

*These smart contracts and testing suite are being provided as is. No guarantee, representation or warranty is being made, express or implied, as to the safety or correctness of anything provided herein or through related user interfaces. This repository and related code have not been audited and as such there can be no assurance anything will work as intended, and users may experience delays, failures, errors, omissions, loss of transmitted information or loss of funds. The creators are not liable for any of the foregoing. Users should proceed with caution and use at their own risk.*

## License

See [LICENSE](./LICENSE) for more details.
