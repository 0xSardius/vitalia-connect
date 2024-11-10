// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {Script} from "forge-std/Script.sol";
import {VitaliaConnect} from "src/VitaliaConnect.sol";
import {console2} from "forge-std/console2.sol";

contract DeployVitaliaConnect is Script {
    function run() external returns (VitaliaConnect) {
        // Check if we're on a testnet
        uint256 chainId;
        assembly {
            chainId := chainid()
        }
        
        // Load environment variables
        string memory rpcUrl = vm.envString("RPC_URL");
        
        // Private key only loaded for test networks
        uint256 deployerPrivateKey;
        if (chainId != 1) { // Not mainnet
            deployerPrivateKey = vm.envUint("PRIVATE_KEY_TESTNET");
        }

        // Log deployment information (remove for production)
        console2.log("Deploying VitaliaConnect to chain:", chainId);
        console2.log("RPC URL:", rpcUrl);

        // Start broadcast for deployment transaction
        if (chainId == 1) {
            // Use ledger for mainnet
            vm.startBroadcast();
        } else {
            // Use private key for testnets
            vm.startBroadcast(deployerPrivateKey);
        }

        // Deploy the contract
        VitaliaConnect vitaliaConnect = new VitaliaConnect();

        // Stop recording transactions
        vm.stopBroadcast();

        // Log the deployed address
        console2.log("VitaliaConnect deployed to:", address(vitaliaConnect));

        return vitaliaConnect;
    }
}