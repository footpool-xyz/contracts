// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {Script, console} from "forge-std/Script.sol";

import {MatchWeek} from "../src/MatchWeek.sol";
import {MatchWeekFactory} from "../src/MatchWeekFactory.sol";
import {FunctionsConsumer} from "../src/FunctionsConsumer.sol";
import {MockFunctionsConsumer} from "../test//mock/MockFunctionsConsumer.sol";
import {HelperConfig} from "./HelperConfig.s.sol";

contract DeployMatchWeekFactory is Script {
    function run() external {
        HelperConfig helperConfig = new HelperConfig();
        (address usdtToken, address oracleConsumer) = helperConfig.activeNetworkConfig();

        vm.startBroadcast();
        MatchWeek matchWeek = new MatchWeek();
        MatchWeekFactory factory = new MatchWeekFactory(msg.sender);
        factory.setLibraryAddress(address(matchWeek));
        factory.setConsumerAddress(oracleConsumer);
        vm.stopBroadcast();

        console.log("Factory contract deployed at: %s", address(factory));
        console.log("USDT token contract deployed at: %s", usdtToken);
        console.log("Consumer contract deployed at: %s", oracleConsumer);
    }
}
