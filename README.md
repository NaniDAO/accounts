# [accounts](https://github.com/nanidao/accounts)  [![License: AGPL-3.0-only](https://img.shields.io/badge/License-AGPL-black.svg)](https://opensource.org/license/agpl-v3/) [![solidity](https://img.shields.io/badge/solidity-%5E0.8.25-black)](https://docs.soliditylang.org/en/v0.8.25/) [![Foundry](https://img.shields.io/badge/Built%20with-Foundry-000000.svg)](https://getfoundry.sh/) ![tests](https://github.com/nanidao/accounts/actions/workflows/ci.yml/badge.svg)

Simple extendable smart account implementations. Built with *[Foundry](https://github.com/foundry-rs/forge-std)* and *[Solady](https://github.com/vectorized/solady)*.

## Getting Started

Run: `curl -L https://foundry.paradigm.xyz | bash && source ~/.bashrc && foundryup`

Build the foundry project with `forge build`. Run contract tests with `forge test`. Measure gas fees with `forge snapshot`. Format code with `forge fmt`.

## Deployments

***v0.0.0***

Chain           | Factory                                 | Implementation                          | Commit
----------------|-----------------------------------------|-----------------------------------------|------------------------------------------
Ethereum, Arbitrum, Optimism, Polygon, Base, Sepolia (testnet) | [0x0000000000001C732C15f21364Ded10Dc753feFe](https://etherscan.io/address/0x0000000000001C732C15f21364Ded10Dc753feFe#code) | [0x000000000000832Dd14268F74994ACE35799432c](https://etherscan.io/address/0x000000000000832Dd14268F74994ACE35799432c#code) | [77bc49fdf9f9695af1971cc6573500dfc7fb9786](https://github.com/NaniDAO/Account/commit/77bc49fdf9f9695af1971cc6573500dfc7fb9786)

### [Plugin Validators](https://ethereum-magicians.org/t/erc-7582-modular-accounts-with-delegated-validation/17640):

Utilizes [ERC7582 minimal modular account](https://github.com/NaniDAO/7582-account) interface.

* JointValidator: [0x000000000000D3D2b2980A7BC509018E4d88e947](https://arbiscan.io/address/0x000000000000D3D2b2980A7BC509018E4d88e947#code)
* RecoveryValidator: [0x000000000000B498889a6371092C19f0ddfCaAf6](https://arbiscan.io/address/0x000000000000B498889a6371092C19f0ddfCaAf6#code)
* TimeValidator: [0x000000000000861E1079c406DBbF2a34dDd7EecD](https://arbiscan.io/address/0x000000000000861E1079c406DBbF2a34dDd7EecD#code)
* PaymentValidator: [0x00000000000032CD4FAE890F90e61e6864e44aa7](https://arbiscan.io/address/0x00000000000032CD4FAE890F90e61e6864e44aa7#code)
* PermitValidator: [0x000000000000ab6c9FF3ed50AC4BAF2a20890835](https://arbiscan.io/address/0x000000000000ab6c9FF3ed50AC4BAF2a20890835#code)

### Paymaster:

* Paymaster: [0x0000000000008408e0fB32deEC73ebFFFbc5165E](https://arbiscan.io/address/0x0000000000008408e0fB32deEC73ebFFFbc5165E#code)
* NEETH: [0x00000000000009B4AB3f1bC2b029bd7513Fbd8ED](https://arbiscan.io/address/0x00000000000009B4AB3f1bC2b029bd7513Fbd8ED#code)

### [Governance](https://github.com/NaniDAO/NaniDAO):

* Points: [0x00000000007f7396897bf90B00e96EaE4B71d055](https://arbiscan.io/address/0x00000000007f7396897bf90b00e96eae4b71d055#code)
* Token: [0x000000000000C6A645b0E51C9eCAA4CA580Ed8e8](https://arbiscan.io/address/0x000000000000C6A645b0E51C9eCAA4CA580Ed8e8)
* Votes: [0x00000000F7000067ED10710A342eC0D09a734Bee](https://arbiscan.io/address/0x00000000f7000067ed10710a342ec0d09a734bee)
* DAO: [0xDa000000000000d2885F108500803dfBAaB2f2aA](https://arbiscan.io/address/0xDa000000000000d2885F108500803dfBAaB2f2aA#code)

### Ownership:

* [Dagon](https://github.com/Moloch-Mystics/dagon): [0x0000000000001ADDcB933DD5028159dc965b5b7f](https://arbiscan.io/address/0x0000000000001ADDcB933DD5028159dc965b5b7f#code)
* Keys: [0x000000000000B418eE0A5B649462Fb851B266522](https://arbiscan.io/address/0x000000000000B418eE0A5B649462Fb851B266522#code)

### Agents:

* [NANI](https://github.com/NaniDAO/NANI): [0x000000000000641b6A7B74F177bAbDB4417718EF](https://arbiscan.io/address/0x000000000000641b6a7b74f177babdb4417718ef#code)
* [IE](https://github.com/NaniDAO/ie): [0x1e00003a669bb466d6B49800000099E1abDD6600](https://arbiscan.io/address/0x1e00003a669bb466d6b49800000099e1abdd6600#code)
* Akashic: [0x000000000000394793B2Fe854281CeE09a98bdBC](https://arbiscan.io/address/0x000000000000394793B2Fe854281CeE09a98bdBC#code)

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
