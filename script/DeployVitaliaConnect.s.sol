// // SPDX-License-Identifier: MIT
// pragma solidity ^0.8.19;

// import {Script} from "forge-std/Script.sol";
// import {VitaliaConnect} from "src/VitaliaConnect.sol";
// import {console2} from "forge-std/console2.sol";

// contract DeployVitaliaConnect is Script {
//     // Base Sepolia Chain ID
//     uint256 constant BASE_SEPOLIA_CHAIN_ID = 84532;

//     function run() external returns (VitaliaConnect) {
//         // Verify we're on Base Sepolia
//         uint256 chainId;
//         assembly {
//             chainId := chainid()
//         }
//         require(chainId == BASE_SEPOLIA_CHAIN_ID, "Not Base Sepolia");
        
//         // Load deployment private key
//         uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY_TESTNET");
        
//         // Pre-deployment logging
//         console2.log("Deploying VitaliaConnect to Base Sepolia");
//         console2.log("Deployer address:", vm.addr(deployerPrivateKey));

//         // Start broadcast
//         vm.startBroadcast(deployerPrivateKey);

//         // Deploy contract
//         VitaliaConnect vitaliaConnect = new VitaliaConnect(/* missing argument here */);

//         // Stop broadcast
//         vm.stopBroadcast();

//         // Post-deployment logging
//         console2.log("VitaliaConnect deployed to:", address(vitaliaConnect));
//         console2.log("Verify contract at: https://sepolia.basescan.org/address/%s#code", address(vitaliaConnect));

//         return vitaliaConnect;
//     }
// }