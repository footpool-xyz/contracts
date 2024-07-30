// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {Test} from "forge-std/Test.sol";
import {MatchWeekFactory} from "../src/MatchWeekFactory.sol";
import {MatchWeek} from "../src/MatchWeek.sol";
import {MockFunctionsConsumer} from "./mock/MockFunctionsConsumer.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract MatchWeekFactoryTest is Test {
    MatchWeekFactory factory;

    address public OWNER = makeAddr("owner");
    address public USER = makeAddr("user");

    function setUp() public {
        vm.startPrank(OWNER);
        MockFunctionsConsumer consumer = new MockFunctionsConsumer();
        MatchWeek matchWeek = new MatchWeek();
        factory = new MatchWeekFactory(OWNER);

        factory.setConsumerAddress(address(consumer));
        factory.setMatchWeekAddress(address(matchWeek));
        vm.stopPrank();
    }

    function testCanCreateANewMatchWeek() public {
        vm.prank(OWNER);
        MatchWeek matchWeekCreated = factory.createMatchWeek("The one");

        assertEq("The one", matchWeekCreated.description());
    }

    function testRevertsIfNoOwnerCreateMatchWeek() public {
        vm.prank(USER);
        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, USER));
        factory.createMatchWeek("A new one");
    }

    /*function testCanRetrieveMatchWeeks() public {}

    function testCanEnableMatchWeek() public {}

    function testRevertsOnEnableIfNoMatchWeekExists() public {}

    function testCanCloseMatchWeek() public {}

    function testRevertsOnCloseIfNoMatchWeekExists() public {}

    function testCanChangeMatchWeekCloneAddress() public {}

    function testCanChangeConsumerAddress() public {}*/
}
