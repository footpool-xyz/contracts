// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {Test, console} from "forge-std/Test.sol";
import {MatchWeek} from "../src/MatchWeek.sol";
import {MockFunctionsConsumer} from "./mock/MockFunctionsConsumer.sol";
import {MockUsdtToken} from "./mock/MockUsdtToken.sol";
import {OwnableUpgradeable} from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract MatchWeekTest is Test {
    event EnabledMatchWeek(uint256 id);
    event MatchAdded(uint256 id);

    MockFunctionsConsumer consumer;
    MatchWeek.Match[] matchesToAdd;
    MatchWeek.Bet[] betsToAdd;
    MockUsdtToken token;

    address OWNER = makeAddr("owner");
    address USER = makeAddr("user");

    function setUp() public {
        consumer = new MockFunctionsConsumer();

        token = new MockUsdtToken();
    }

    function testCanEnableMatchWeek() public {
        MatchWeek matchWeek = _initializeMatchWeek();
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
        MatchWeek matchWeek = _initializeMatchWeek();

        vm.prank(USER);
        vm.expectRevert(MatchWeek.MatchWeek__OnlyFactoryOrOwnerAllowed.selector);
        matchWeek.enable();
    }

    function testCanCloseOnlyWhenIsOpen() public {
        MatchWeek matchWeek = _initializeMatchWeek();

        vm.prank(OWNER);
        matchWeek.close();
    }

    function testRevertsClosingWhenIsAlreadyClosed() public {
        MatchWeek matchWeek = _initializeMatchWeek();

        vm.startPrank(OWNER);
        matchWeek.close();
        vm.expectRevert(MatchWeek.MatchWeek__AlreadyClosed.selector);
        matchWeek.close();
        vm.stopPrank();
    }

    function testCanAddMatches() public {
        MatchWeek matchWeek = _initializeMatchWeek();
        _populateMatchesToAdd();

        vm.prank(OWNER);
        vm.expectEmit(true, false, false, true);
        emit MatchAdded(1);
        vm.expectEmit(true, false, false, true);
        emit MatchAdded(2);
        matchWeek.addMatches(matchesToAdd);

        MatchWeek.Match[] memory matchesAdded = matchWeek.getMatches();
        assertEq(2, matchesAdded.length);
    }

    function testOnlyOwnerCanAddMatches() public {
        MatchWeek matchWeek = _initializeMatchWeek();
        _populateMatchesToAdd();

        vm.prank(USER);
        vm.expectRevert(abi.encodeWithSelector(OwnableUpgradeable.OwnableUnauthorizedAccount.selector, USER));
        matchWeek.addMatches(matchesToAdd);
    }

    function testRevertsWhenTryingToAddMatchesAndMatchWeekIsClosed() public {
        MatchWeek matchWeek = _initializeMatchWeek();
        _populateMatchesToAdd();

        vm.prank(OWNER);
        matchWeek.close();

        vm.expectRevert(MatchWeek.MatchWeek__AlreadyClosed.selector);
        vm.prank(OWNER);
        matchWeek.addMatches(matchesToAdd);
    }

    function testCanAddBets() public {
        MatchWeek matchWeek = _initializeMatchWeek();
        _populateMatchesToAdd();
        _populateBetsToAdd();

        vm.startPrank(USER);
        token.mint(USER);
        token.approve(address(matchWeek), 5 * 1e18);
        matchWeek.addBets(betsToAdd, address(token));
        vm.stopPrank();

        MatchWeek.Bet[] memory myBets = matchWeek.getMyBets(USER);
        assert(MatchWeek.Result.LOCAL_WIN == myBets[0].result);
        assert(MatchWeek.Result.DRAW == myBets[1].result);
    }

    function testCantBetWhenNoTokenAllowance() public {
        MatchWeek matchWeek = new MatchWeek();
        matchWeek.initialize(1, "First MatchWeek", OWNER, address(consumer));
        betsToAdd.push(MatchWeek.Bet(1, MatchWeek.Result.LOCAL_WIN));
        betsToAdd.push(MatchWeek.Bet(2, MatchWeek.Result.DRAW));

        vm.prank(OWNER);
        matchWeek.addMatches(matchesToAdd);

        token.mint(USER);

        vm.prank(USER);
        vm.expectRevert(MatchWeek.MatchWeek__NotEnoughTokenAllowance.selector);
        matchWeek.addBets(betsToAdd, address(token));
    }

    /**
     * Helper functions
     */
    function _initializeMatchWeek() private returns (MatchWeek) {
        MatchWeek matchWeek = new MatchWeek();
        matchWeek.initialize(1, "First MatchWeek", OWNER, address(consumer));

        return matchWeek;
    }

    function _populateBetsToAdd() private {
        betsToAdd.push(MatchWeek.Bet(1, MatchWeek.Result.LOCAL_WIN));
        betsToAdd.push(MatchWeek.Bet(2, MatchWeek.Result.DRAW));
    }

    function _populateMatchesToAdd() private {
        vm.startPrank(OWNER);
        matchesToAdd.push(MatchWeek.Match(1, "RMadrid", "FCBarcelona", MatchWeek.Result.UNDEFINED));
        matchesToAdd.push(MatchWeek.Match(2, "ATMadrid", "Athletic", MatchWeek.Result.UNDEFINED));
        vm.stopPrank();
    }
}
