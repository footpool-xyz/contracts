//SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {FunctionsConsumer} from "../../src/FunctionsConsumer.sol";

contract MockFunctionsConsumer is FunctionsConsumer {
    address public constant RANDOM_ROUTER = 0x47462Fc9F041763b47549DEf683DD785BbCFC313;

    constructor() FunctionsConsumer(RANDOM_ROUTER) {}
}
