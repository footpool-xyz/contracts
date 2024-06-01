// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/proxy/Clones.sol";
import "./MatchWeek.sol";

contract MatchWeekFactory is Ownable {
    event MatchWeekCreated(address addr, string name);
    event MatchWeekEnabled(uint256 id);
    event MatchWeekClosed(uint256 id);

    mapping(uint256 => MatchWeek) public matchWeeks;
    uint256[] matchWeeksIds;
    address private libraryAddress;
    address private consumerAddress;

    constructor(address initialOwner) Ownable(initialOwner) {}

    function setLibraryAddress(address _libraryAddress) external onlyOwner {
        libraryAddress = _libraryAddress;
    }

    function setConsumerAddress(address _consumerAddress) external onlyOwner {
        consumerAddress = _consumerAddress;
    }

    function createMatchWeek(string memory name) external onlyOwner {
        MatchWeek matchWeek = MatchWeek(Clones.clone(libraryAddress));
        uint256 newId = matchWeeksIds.length + 1;
        matchWeek.initialize(newId, name, msg.sender, consumerAddress);
        matchWeeks[newId] = matchWeek;
        matchWeeksIds.push(newId);
        emit MatchWeekCreated(address(matchWeek), name);
    }

    function getMatchWeeks() external view returns (MatchWeek[] memory) {
        uint256 length = matchWeeksIds.length;
        MatchWeek[] memory _matchWeeks = new MatchWeek[](length);
        for (uint256 i = 0; i < length; i++) {
            _matchWeeks[i] = matchWeeks[matchWeeksIds[i]];
        }

        return _matchWeeks;
    }

    function enable(uint256 matchWeekId) external onlyOwner {
        matchWeeks[matchWeekId].enable();
        emit MatchWeekEnabled(matchWeekId);
    }

    function close(uint256 matchWeekId) external onlyOwner {
        matchWeeks[matchWeekId].close();
        emit MatchWeekClosed(matchWeekId);
    }
}
