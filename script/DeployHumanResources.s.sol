// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.24;

import "forge-std/Script.sol";
import "../src/HumanResources.sol";

contract DeployHumanResources is Script {
    function run() external {
        vm.startBroadcast(); // Start broadcasting transactions

        // Deploy the HumanResources contract
        HumanResources hr = new HumanResources();
        console.log("HumanResources deployed at:", address(hr));

        vm.stopBroadcast(); // Stop broadcasting transactions
    }
}
