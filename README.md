# [Account](https://github.com/nanidao/Account)  [![License: AGPL-3.0-only](https://img.shields.io/badge/License-AGPL-black.svg)](https://opensource.org/license/agpl-v3/) [![solidity](https://img.shields.io/badge/solidity-%5E0.8.19-black)](https://docs.soliditylang.org/en/v0.8.19/) [![Foundry](https://img.shields.io/badge/Built%20with-Foundry-000000.svg)](https://getfoundry.sh/) ![tests](https://github.com/z0r0z/zenplate/actions/workflows/ci.yml/badge.svg)

Simple extendable smart account implementation. Built with *[Foundry](https://github.com/foundry-rs/forge-std)* and *[Solady](https://github.com/vectorized/solady)*.

## Getting Started

Run: `curl -L https://foundry.paradigm.xyz | bash && source ~/.bashrc && foundryup`

Build the foundry project with `forge build`. Run contract tests with `forge test`. Measure gas fees with `forge snapshot`. Format code with `forge fmt`.

## Deployments

Chain           | Factory                                 | Implementation                          | Commit
----------------|-----------------------------------------|-----------------------------------------|------------------------------------------
base-goerli    | [0x17c8c526CC73F969f510d20027BF2f96a7f41A2e](https://goerli.basescan.org/address/0x17c8c526cc73f969f510d20027bf2f96a7f41a2e#code) | [0xd673BdCBCC054f0B149FF0376937f1CE15d9cd2D](https://goerli.basescan.org/address/0xd673BdCBCC054f0B149FF0376937f1CE15d9cd2D#code) | [d379a653246d2953489a29413a6c6e59bda1db24](https://github.com/NaniDAO/Account/commit/d379a653246d2953489a29413a6c6e59bda1db24)


## Blueprint

```txt
lib
├─ forge-std — https://github.com/foundry-rs/forge-std
├─ solady — https://github.com/vectorized/solady
src
├─ Account — Account Contract
test
└─ Account.t - Test Contract
```

## Disclaimer

*These smart contracts and testing suite are being provided as is. No guarantee, representation or warranty is being made, express or implied, as to the safety or correctness of anything provided herein or through related user interfaces. This repository and related code have not been audited and as such there can be no assurance anything will work as intended, and users may experience delays, failures, errors, omissions, loss of transmitted information or loss of funds. The creators are not liable for any of the foregoing. Users should proceed with caution and use at their own risk.*

## License

See [LICENSE](./LICENSE) for more details.
