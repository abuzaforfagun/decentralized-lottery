## Foundry

**Foundry is a blazing fast, portable and modular toolkit for Ethereum application development written in Rust.**

Foundry consists of:

- **Forge**: Ethereum testing framework (like Truffle, Hardhat and DappTools).
- **Cast**: Swiss army knife for interacting with EVM smart contracts, sending transactions and getting chain data.
- **Anvil**: Local Ethereum node, akin to Ganache, Hardhat Network.
- **Chisel**: Fast, utilitarian, and verbose solidity REPL.

## Documentation

https://book.getfoundry.sh/

## Usage

### Build

```shell
$ forge build
```

### Test

```shell
$ forge test
```

### Format

```shell
$ forge fmt
```

### Gas Snapshots

```shell
$ forge snapshot
```

### Anvil

```shell
$ anvil
```

### Deploy

```shell
$ forge script script/Lottery.s.sol --rpc-url <your_rpc_url> --private-key <your_private_key>
```

### Join lottery

```shell
$ cast send <lottery_contract_address> "join()" --value 0.001ether --rpc-url <your_rpc_url> --private-key <your_private_key>
```

### Trigger VRF in Anvil

### Join lottery

```shell
$ cast send <vrf_mock_contract_address> "fulfillRandomWords(uint256,address)" <request_id> <lottery_contract_address> <  --rpc-url <your_rpc_url> --private-key <your_private_key>
```

### Help

```shell
$ forge --help
$ anvil --help
$ cast --help
```
