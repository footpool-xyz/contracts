// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {Test} from "forge-std/Test.sol";
import {MatchWeek} from "../src/MatchWeek.sol";
import {MockFunctionsConsumer} from "./mock/MockFunctionsConsumer.sol";
import {MockUsdtToken} from "./mock/MockUsdtToken.sol";

contract MatchWeekTest is Test {
    event EnabledMatchWeek(uint256 id);
    event MatchAdded(uint256 id);

    MockFunctionsConsumer consumer;
    MatchWeek.Match[] matchesToAdd;

    address OWNER = makeAddr("owner");
    address USER = makeAddr("user");

    function setUp() public {
        consumer = new MockFunctionsConsumer();

        matchesToAdd.push(MatchWeek.Match(1, "RMadrid", "FCBarcelona", MatchWeek.Result.UNDEFINED));
        matchesToAdd.push(MatchWeek.Match(2, "ATMadrid", "Athletic", MatchWeek.Result.UNDEFINED));
    }

    function testCanEnableMatchWeek() public {
        MatchWeek matchWeek = new MatchWeek();
        matchWeek.initialize(1, "First MatchWeek", OWNER, address(consumer));
        bool previousState = matchWeek.s_isEnabled();

        vm.startPrank(OWNER);
        vm.expectEmit(false, false, false, false);
        emit EnabledMatchWeek(matchWeek.s_id());
        matchWeek.enable();
        bool finalState = matchWeek.s_isEnabled();
        vm.stopPrank();

        assertFalse(previousState);
        assertTrue(finalState);
    }

    function testOnlyOwnerCanEnableMatchWeek() public {
        MatchWeek matchWeek = new MatchWeek();
        matchWeek.initialize(1, "First MatchWeek", OWNER, address(consumer));

        vm.prank(USER);
        vm.expectRevert(MatchWeek.MatchWeek__OnlyFactoryOrOwnerAllowed.selector);
        matchWeek.enable();
    }

    function testCanCloseOnlyWhenIsOpen() public {
        MatchWeek matchWeek = new MatchWeek();
        matchWeek.initialize(1, "First MatchWeek", OWNER, address(consumer));

        vm.prank(OWNER);
        matchWeek.close();
    }

    function testRevertsClosingWhenIsAlreadyClosed() public {
        MatchWeek matchWeek = new MatchWeek();
        matchWeek.initialize(1, "First MatchWeek", OWNER, address(consumer));

        vm.startPrank(OWNER);
        matchWeek.close();
        vm.expectRevert(MatchWeek.MatchWeek__AlreadyClosed.selector);
        matchWeek.close();
        vm.stopPrank();
    }

    function testCanAddMatches() public {
        MatchWeek matchWeek = new MatchWeek();
        matchWeek.initialize(1, "First MatchWeek", OWNER, address(consumer));

        vm.prank(OWNER);
        vm.expectEmit(true, false, false, true);
        emit MatchAdded(1);
        vm.expectEmit(true, false, false, true);
        emit MatchAdded(2);
        matchWeek.addMatches(matchesToAdd);

        MatchWeek.Match[] memory matchesAdded = matchWeek.getMatches();
        assertEq(2, matchesAdded.length);
    }
}
