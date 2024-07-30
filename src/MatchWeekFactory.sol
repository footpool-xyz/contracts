// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/proxy/Clones.sol";
import "./MatchWeek.sol";

/**
 * @title Match Week Factory.
 * @notice This contract is the manager of match weeks, creating new ones
 * and closing/enabling them also.
 */
contract MatchWeekFactory is Ownable {
    event MatchWeekCreated(address addr, string name);
    event MatchWeekEnabled(uint256 id);
    event MatchWeekClosed(uint256 id);

    mapping(uint256 => MatchWeek) public s_matchWeeks;

    uint256[] private s_matchWeeksIds;
    address private s_matchWeekAddress;
    address private s_consumerAddress;

    constructor(address initialOwner) Ownable(initialOwner) {}

    /**
     * Creation of a new match week.
     * @param name Name of match week. For example: Match Week One.
     * @dev Only owner can create new match weeks.
     */
    function createMatchWeek(string memory name) external onlyOwner returns (MatchWeek) {
        uint256 newId = s_matchWeeksIds.length + 1;

        MatchWeek newMatchWeek = MatchWeek(Clones.clone(s_matchWeekAddress));
        newMatchWeek.initialize(s_matchWeeksIds.length + 1, name, msg.sender, s_consumerAddress);
        s_matchWeeks[newId] = newMatchWeek;
        s_matchWeeksIds.push(newId);
        emit MatchWeekCreated(address(newMatchWeek), name);

        return newMatchWeek;
    }

    /**
     * Get all match weeks to list it. No state filter applied.
     */
    function getMatchWeeks() external view returns (MatchWeek[] memory) {
        uint256 numOfMatchWeeks = s_matchWeeksIds.length;
        MatchWeek[] memory matchWeeks = new MatchWeek[](numOfMatchWeeks);
        for (uint256 i = 0; i < numOfMatchWeeks; i++) {
            matchWeeks[i] = s_matchWeeks[s_matchWeeksIds[i]];
        }

        return matchWeeks;
    }

    /**
     * Can enable a Match Week by its id. Enable means that anyone can see it and
     * is ready to get submitted bets.
     * @param id Match Week id.
     * @dev Only owner can create new match weeks.
     */
    function enableMatchWeekById(uint256 id) external onlyOwner {
        s_matchWeeks[id].enable();
        emit MatchWeekEnabled(id);
    }

    /**
     * Can close a Match Week by its id. Close means that nobody can do any more actions on it.
     * Not even owner can modify state. Just withdraw remaining ERC20 amount.
     * @param id Match Week id.
     * @dev Only owner can create new match weeks.
     */
    function closeMatchWeekById(uint256 id) external onlyOwner {
        s_matchWeeks[id].close();
        emit MatchWeekClosed(id);
    }

    /**
     * Set the Match Week to be cloned from.
     * @param matchWeekAddress Match Week to be cloned from Address.
     * @dev Only owner can create new match weeks.
     */
    function setMatchWeekAddress(address matchWeekAddress) external onlyOwner {
        s_matchWeekAddress = matchWeekAddress;
    }

    /**
     * Set the consumer address. This consumer gets the matches and results from Oracles.
     * @param consumerAddress Consumer address.
     * @dev Only owner can create new match weeks.
     */
    function setConsumerAddress(address consumerAddress) external onlyOwner {
        s_consumerAddress = consumerAddress;
    }
}
