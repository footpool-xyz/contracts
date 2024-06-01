// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import "@openzeppelin/contracts/access/Ownable.sol";

contract MatchWeekFactory is Ownable {

    event MatchWeekCreated(address addr, string name);
    event MatchWeekEnabled(uint id);
    event MatchWeekClosed(uint id);

    mapping(uint => MatchWeek) public matchWeeks;
    uint[] matchWeeksIds;
    address private libraryAddress;
    address private consumerAddress;

    function setLibraryAddress(address _libraryAddress) external onlyOwner {
        libraryAddress = _libraryAddress;
    }

    function setConsumerAddress(address _consumerAddress) external onlyOwner {
        consumerAddress = _consumerAddress;
    }

    function createMatchWeek(string memory name) external onlyOwner {
        MatchWeek matchWeek = MatchWeek(Clones.clone(libraryAddress));
        uint newId = matchWeeksIds.length + 1;
        matchWeek.initialize(newId, name, msg.sender, consumerAddress);
        matchWeeks[newId] = matchWeek;
        matchWeeksIds.push(newId);
        emit MatchWeekCreated(address(matchWeek), name);
    }

    function getMatchWeeks() external view returns (MatchWeek[] memory) {
        uint length = matchWeeksIds.length;
        MatchWeek[] memory _matchWeeks = new MatchWeek[](length);
        for (uint i = 0; i < length; i++) {
            _matchWeeks[i] = matchWeeks[matchWeeksIds[i]];
        }

        return _matchWeeks;
    }

    function enable(uint matchWeekId) external onlyOwner {
        matchWeeks[matchWeekId].enable();
        emit MatchWeekEnabled(matchWeekId);
    }

    function close(uint matchWeekId) external onlyOwner {
        matchWeeks[matchWeekId].close();
        emit MatchWeekClosed(matchWeekId);
    }
}
