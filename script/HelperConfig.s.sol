// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {Script} from "forge-std/Script.sol";
import {MockUsdtToken} from "../test/mock/MockUsdtToken.sol";
import {MockFunctionsConsumer} from "../test/mock/MockFunctionsConsumer.sol";

contract HelperConfig is Script {
    uint constant SEPOLIA_CHAIN_ID = 11155111;

    NetworkConfig public activeNetworkConfig;

    struct NetworkConfig {
        address usdtToken;
        address oracleConsumer;
    }

    constructor() {
        if (block.chainid == SEPOLIA_CHAIN_ID) {
            activeNetworkConfig = getSepoliaNetworkConfig();
        } else {
            activeNetworkConfig = getAnvilNetworkConfig();
        }
    }

    function getSepoliaNetworkConfig() private view returns (NetworkConfig memory) {}

    function getAnvilNetworkConfig() private returns (NetworkConfig memory) {
        vm.startBroadcast();
        MockUsdtToken usdtToken = new MockUsdtToken();
        MockFunctionsConsumer consumer = new MockFunctionsConsumer();
        vm.stopBroadcast();

        NetworkConfig memory networkConfig = NetworkConfig(address(usdtToken), address(consumer));

        return networkConfig;
    }
}
