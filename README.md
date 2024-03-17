# [accounts](https://github.com/nanidao/accounts)  [![License: AGPL-3.0-only](https://img.shields.io/badge/License-AGPL-black.svg)](https://opensource.org/license/agpl-v3/) [![solidity](https://img.shields.io/badge/solidity-%5E0.8.19-black)](https://docs.soliditylang.org/en/v0.8.19/) [![Foundry](https://img.shields.io/badge/Built%20with-Foundry-000000.svg)](https://getfoundry.sh/) ![tests](https://github.com/nanidao/accounts/actions/workflows/ci.yml/badge.svg)

Simple extendable smart account implementations. Built with *[Foundry](https://github.com/foundry-rs/forge-std)* and *[Solady](https://github.com/vectorized/solady)*.

## Getting Started

Run: `curl -L https://foundry.paradigm.xyz | bash && source ~/.bashrc && foundryup`

Build the foundry project with `forge build`. Run contract tests with `forge test`. Measure gas fees with `forge snapshot`. Format code with `forge fmt`.

## Deployments

***v0.0.0***

Chain           | Factory                                 | Implementation                          | Commit
----------------|-----------------------------------------|-----------------------------------------|------------------------------------------
Ethereum, Arbitrum, Optimism, Polygon, Base, Sepolia (testnet) | [0x000000000000dD366cc2E4432bB998e41DFD47C7](https://etherscan.io/address/0x000000000000dD366cc2E4432bB998e41DFD47C7#code) | [0x0000000000001C05075915622130c16f6febC541](https://etherscan.io/address/0x0000000000001C05075915622130c16f6febC541#code) | [77bc49fdf9f9695af1971cc6573500dfc7fb9786](https://github.com/NaniDAO/Account/commit/77bc49fdf9f9695af1971cc6573500dfc7fb9786)

### Plugin Validators:

* JointValidator: [0x0000000000bBe5e59600001E15b9A59B42f52b75](https://etherscan.io/address/0x0000000000bbe5e59600001e15b9a59b42f52b75#code)
* RecoveryValidator: [0x00000000002d3440001c53656DB7aEE3B37E3152](https://etherscan.io/address/0x00000000002d3440001c53656db7aee3b37e3152#code)

### Paymasters:

[0x0000000000002bB5E405174504eEB2AF43ADd753](https://etherscan.io/address/0x0000000000002bB5E405174504eEB2AF43ADd753#code)

### Governance:

* DAO: [0xDa000000000000d2885F108500803dfBAaB2f2aA](https://arbiscan.io/address/0xDa000000000000d2885F108500803dfBAaB2f2aA#code)
* Points: [0x00000000007f7396897bf90B00e96EaE4B71d055](https://arbiscan.io/address/0x00000000007f7396897bf90b00e96eae4b71d055#code)
* Token: [0x000000000000C6A645b0E51C9eCAA4CA580Ed8e8](https://arbiscan.io/address/0x000000000000C6A645b0E51C9eCAA4CA580Ed8e8)
* Votes: [0x00000000F7000067ED10710A342eC0D09a734Bee](https://arbiscan.io/address/0x00000000f7000067ed10710a342ec0d09a734bee)

### Ownership:

* Dagon: [0x0000000000001ADDcB933DD5028159dc965b5b7f](https://arbiscan.io/address/0x0000000000001ADDcB933DD5028159dc965b5b7f#code)
* Keys: [0x000000000000082ffb07deF3DdfB5D3AFA9b9668](https://arbiscan.io/address/0x000000000000082ffb07def3ddfb5d3afa9b9668#code)

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
