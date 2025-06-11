## Foundry

**Foundry is a blazing fast, portable and modular toolkit for Ethereum application development written in Rust.**

Foundry consists of:

-   **Forge**: Ethereum testing framework (like Truffle, Hardhat and DappTools).
-   **Cast**: Swiss army knife for interacting with EVM smart contracts, sending transactions and getting chain data.
-   **Anvil**: Local Ethereum node, akin to Ganache, Hardhat Network.
-   **Chisel**: Fast, utilitarian, and verbose solidity REPL.

## Documentation
The registerEmployee function add a employee to the list of employee under the mapping of their address, it initiate a list of information for the employee. The terminateEmployee function modify the struct (list of information) for the employee to a terminated status. Those two function can only be called by the hr manager. 

Function getEmployeeInfo is only use to get a specific employee informations from it's struct. Function getActiveEmployeeCount is for getting the current total active employee number.

Function salaryAvailable is used to get a specific employee's accumulated unclaim salary in his/her prefered currency (eth or usdc). By getting the amount salary in usd from struct and if prefered currency is eth, use chainlink feed to get eth price, then calculate the salary amount in eth. If in usdc, simpily adjust the decimals.

Function withdrawSalary can only be called by employees. it is used to claim his/her accumulated unclaim salary in prefered currency by the help of calling salaryAvailble function to know the amount first. If prefered currency is eth, the original exact amount of USD salary is used to exchange into weth and then unwrap to eth. It is re-entrance safe as struct values are adjusted before the exchange, the exchange of currency use uniswap. The exact amount of USD salary is adjust to USDC by decimals, then with uniswap, we can swap to the according value of WETH. The weth must be at least 98% of the original value of USDC to protect against front-running slippage, revert if otherwise. Then Weth is then unwrap into same amount of eth. Then in both situation of prefered currency will then be transfer to employee's address.

Function switchCurrency is used to toggles the employee's preferred payment currency between usdc and eth, the preference is store inside the struct of each employee. Employee must be active to call this function and withdrawSalary function will run before the switch to ensure the unclaim salary will be withdraw in previous prefered currency.



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
$ forge script script/Counter.s.sol:CounterScript --rpc-url <your_rpc_url> --private-key <your_private_key>
```

### Cast

```shell
$ cast <subcommand>
```

### Help

```shell
$ forge --help
$ anvil --help
$ cast --help
```
