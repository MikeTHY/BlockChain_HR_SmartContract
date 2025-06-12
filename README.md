# BlockChain_HR_SmartContract
# HumanResources Smart Contract on Optimism

## Summary
This project implements a Solidity-based `HumanResources` contract for managing an HR payroll system on the Optimism network. It allows an HR Manager to register or terminate employees, handle salary accrual, and process withdrawals in either USDC or ETH using real-time Chainlink price feeds and Uniswap AMM swaps.

## Key Features
- **Role-Based Access Control:** Only HR Manager can register/terminate employees.
- **Salary Accrual System:** Employees accrue salary continuously, withdrawable at any time.
- **Multi-Currency Withdrawal:** Employees choose USDC or ETH, with on-demand swaps via Uniswap.
- **Price Security:** Integrates Chainlink Oracle for real-time ETH/USD price feeds, protecting against AMM manipulation.
- **Safe ETH Transfers:** Implements re-entrancy guards during ETH payments.

## Technologies Used
- Solidity (v0.8.x)
- Foundry (Forge) for testing and deployment
- Chainlink Oracle (ETH/USD price feed)
- Uniswap V3 Swap Router (AMM)
- Optimism L2 Network

## File Structure
- `/src/HumanResources.sol` - Main smart contract
- `/test/HumanResources.t.sol` - Comprehensive test suite (success & failure cases)
- `/deployed-address.txt` - Optimism deployment address
- `/submit-transaction.txt` - Submission transaction hash
- `/README.md` - This documentation

## Deployment Details
- **Deployed Address:** *(fill this after deployment)*  
- **Submit Transaction Hash:** *(fill this after submit function call)*  

## Oracle & AMM Integration
- **Chainlink ETH/USD Price Feed:** [0x13e3Ee699D1909E989722E753853AE30b17e08c5](https://optimistic.etherscan.io/address/0x13e3Ee699D1909E989722E753853AE30b17e08c5)
- **Uniswap V3 Router:** [0xE592427A0AEce92De3Edee1F18E0157C05861564](https://optimistic.etherscan.io/address/0xE592427A0AEce92De3Edee1F18E0157C05861564)

## Security Considerations
- Access control enforced for sensitive functions.
- Slippage protection implemented for Uniswap swaps.
- Re-entrancy guards in place for ETH withdrawals.

## Testing
- 100% function coverage via Foundry Forge.
- Forked Optimism network tests simulate Oracle & AMM interactions.
- Edge cases for unauthorized access, over-withdrawal, and failed swaps.

## Author
Michael (Hing Yuen) Tsang
