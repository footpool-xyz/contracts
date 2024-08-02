// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {Test, console} from "forge-std/Test.sol";
import {MatchWeekFactory} from "../src/MatchWeekFactory.sol";
import {MatchWeek} from "../src/MatchWeek.sol";
import {MockFunctionsConsumer} from "./mock/MockFunctionsConsumer.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract MatchWeekFactoryTest is Test {
    event MatchWeekCreated(address addr, string name);
    event MatchWeekEnabled(uint256 id);
    event MatchWeekClosed(uint256 id);
    event MatchWeekClonableAddressChanged(address cloneAddr);
    event ConsumerAddressChanged(address consumerAddr);

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
        vm.expectEmit(true, true, false, true);
        MatchWeek matchWeekCreated = factory.createMatchWeek("The one");
        emit MatchWeekCreated(address(matchWeekCreated), "The one");

        assertEq("The one", matchWeekCreated.description());
    }

    function testRevertsIfNoOwnerCreateMatchWeek() public {
        vm.prank(USER);
        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, USER));
        factory.createMatchWeek("A new one");
    }

    function testCanRetrieveMatchWeeks() public feedMultipleMatchWeeks {
        MatchWeek[] memory matchWeeks = factory.getMatchWeeks();

        assertEq(3, matchWeeks.length);
        assertEq("One", matchWeeks[0].description());
        assertEq("Two", matchWeeks[1].description());
        assertEq("Three", matchWeeks[2].description());
    }

    function testCanEnableMatchWeek() public feedSingleMatchWeek {
        MatchWeek matchWeek = factory.getMatchWeeks()[0];
        bool previousState = matchWeek.isEnabled();

        vm.startPrank(OWNER);
        factory.enableMatchWeekById(matchWeek.id());
        bool endState = matchWeek.isEnabled();
        vm.stopPrank();

        assertEq(false, previousState);
        assertTrue(endState);
    }

    function testRevertsOnEnableIfNoMatchWeekExists() public feedSingleMatchWeek {
        uint256 notCreatedId = 280;

        vm.expectRevert();
        vm.prank(OWNER);
        factory.enableMatchWeekById(notCreatedId);
    }

    function testCanCloseMatchWeek() public feedSingleMatchWeek {
        MatchWeek matchWeek = factory.getMatchWeeks()[0];
        bool previousState = matchWeek.isClosed();

        vm.startPrank(OWNER);
        factory.closeMatchWeekById(matchWeek.id());
        bool endState = matchWeek.isClosed();
        vm.stopPrank();

        assertFalse(previousState);
        assertTrue(endState);
    }

    function testRevertsOnCloseIfNoMatchWeekExists() public feedSingleMatchWeek {
        uint256 notExistingMatchWeekId = 500;
        vm.prank(OWNER);
        vm.expectRevert();
        factory.closeMatchWeekById(notExistingMatchWeekId);
    }

    function testCanChangeMatchWeekCloneAddress() public {
        MatchWeek newMatchWeek = new MatchWeek();
        vm.prank(OWNER);
        vm.expectEmit(true, false, false, true);
        emit MatchWeekClonableAddressChanged(address(newMatchWeek));
        factory.setMatchWeekAddress(address(newMatchWeek));
    }

    function testCanChangeConsumerAddress() public {
        MockFunctionsConsumer newConsumer = new MockFunctionsConsumer();
        vm.prank(OWNER);
        vm.expectEmit(true, false, false, true);
        emit ConsumerAddressChanged(address(newConsumer));
        factory.setConsumerAddress(address(newConsumer));
    }

    modifier feedMultipleMatchWeeks() {
        vm.startPrank(OWNER);
        factory.createMatchWeek("One");
        factory.createMatchWeek("Two");
        factory.createMatchWeek("Three");
        vm.stopPrank();
        _;
    }

    modifier feedSingleMatchWeek() {
        vm.startPrank(OWNER);
        factory.createMatchWeek("Single");
        vm.stopPrank();
        _;
    }
}
