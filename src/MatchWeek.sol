// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "./FunctionsConsumer.sol";

contract MatchWeek is Initializable, OwnableUpgradeable {

    event BetAdded(address indexed sender, uint amount, Bet[] bets);
    event RewardSended(address indexed to, uint reward);
    event RefundSent(address to, uint refunded);

    struct Bet {
        uint32 matchId;
        Result result;
    }

    struct Match {
        uint32 id;
        string localTeam;
        string awayTeam;
        Result result;
    }

    struct MatchResult {
        uint32 matchId;
        Result result;
    }

    enum Result {
        LOCAL_WIN, // 0
        DRAW, // 1
        AWAY_WIN, // 2
        UNDEFINED  // 3
    }

    mapping(uint => Match) public matches;
    uint[] private matchesIds;
    uint8 private matchesLength;
    mapping(address => Bet[]) private betsByStakeholder;
    address[] private stakeholders;
    FunctionsConsumer public consumer;
    IERC20 token;

    uint id;
    string public description;
    bool public isEnabled;
    bool public isClosed;

    function initialize(uint _id, string memory _description, address _owner, address _consumer) public initializer {
        __Ownable_init(_owner);
        id = _id;
        isEnabled = false;
        description = _description;
        isClosed = false;
        consumer = FunctionsConsumer(_consumer);
    }

    function enable() external {
        isEnabled = true;
    }

    function summary() external view returns (string memory, bool, bool, uint, uint) {
        return (description, isEnabled, isClosed, stakeholders.length, id);
    }

    function close() external ifNotClosed {
        isClosed = true;
    }

    function addMatches(Match[] calldata _matches) public onlyOwner ifNotClosed {
        matchesLength = uint8(_matches.length);
        for (uint8 i; i < matchesLength; ++i) {
            uint32 matchId = _matches[i].id;
            Match memory newMatch = Match(matchId, _matches[i].localTeam, _matches[i].awayTeam, Result.UNDEFINED);
            matches[matchId] = newMatch;
            matchesIds.push(matchId);
        }
    }

    function getMatches() public view returns (Match[] memory) {
        uint matchesIdsLentgh = matchesIds.length;
        Match[] memory _matches = new Match[](matchesLength);
        for (uint8 i = 0; i < matchesIdsLentgh; ++i) {
            _matches[i] = matches[matchesIds[i]];
        }

        return _matches;
    }

    function addBets(Bet[] calldata bets, address paymentTokenAddress) public ifNotClosed {
        token = IERC20(paymentTokenAddress);
        uint256 amount = 5 * (10 ** 18);
        uint256 allowedAmountToTransfer = token.allowance(msg.sender, address(this)) * (10 ** 18);
        require(amount <= allowedAmountToTransfer, "You need to approve your tokens first");
        token.transferFrom(msg.sender, address(this), amount);

        uint256 betsLength = bets.length;
        for (uint8 i; i < betsLength; ++i) {
            uint32 matchId = bets[i].matchId;
            Result result = bets[i].result;

            betsByStakeholder[msg.sender].push(Bet(matchId, result));
        }
        stakeholders.push(msg.sender);
        emit BetAdded(msg.sender, amount, betsByStakeholder[msg.sender]);

    }

    function getMyBets(address user) public view returns (Bet[] memory) {
        return betsByStakeholder[user];
    }

    function getResults() external view returns (string memory) {
        return consumer.getResponse();
    }

    function addResults(MatchResult[] calldata _results) public onlyOwner ifNotClosed {
        uint256 _resultsLength = _results.length;
        for (uint8 i; i < _resultsLength; ++i) {
            matches[_results[i].matchId].result = _results[i].result;
        }

        sendRewardsToWinners();
        isClosed = true;
    }

    function sendRewardsToWinners() private onlyOwner {
        uint stakeholdersLength = stakeholders.length;
        address[] memory winners = new address[](stakeholders.length);
        uint8 winnersCount = 0;
        for (uint8 i; i < stakeholdersLength; ++i) {
            address currentStakeHolder = stakeholders[i];
            Bet[] memory allBetsByStakeHolder = betsByStakeholder[currentStakeHolder];
            bool allBetsHitted = true;

            uint8 j = 0;
            uint256 allBetsByStakeHolderLength = allBetsByStakeHolder.length;
            while (j < allBetsByStakeHolderLength && allBetsHitted == true) {
                Bet memory betToCompare = allBetsByStakeHolder[j];

                if (matches[betToCompare.matchId].result != betToCompare.result) {
                    allBetsHitted = false;
                }

                ++j;
            }

            if (allBetsHitted) {
                winners[winnersCount] = currentStakeHolder;
                winnersCount++;
            }
        }

        if (winnersCount > 0) {
            sendReward(winners, winnersCount);
        }
    }

    function getRewardToSend(uint winnersLength) private view returns (uint) {
        uint currentBalance = token.balanceOf(address(this));
        uint32 rewardPercentage = 90;

        uint reward = currentBalance / 100 * rewardPercentage;
        uint userReward = reward / winnersLength;

        return userReward;
    }

    function sendReward(address[] memory to, uint8 winnersCount) private {
        uint256 reward = getRewardToSend(winnersCount);

        for (uint32 i; i < winnersCount; ++i) {
            token.transfer(to[i], reward);
            emit RewardSended(to[i], reward);
        }
    }

    function withdrawFunds() external onlyOwner {
        require(isClosed == true, "This is not closed yet!");

        address owner = owner();
        uint balance = token.balanceOf(address(this));
        token.transfer(owner, balance);
    }

    function refundToStakeholders() external onlyOwner {
        uint stakeholdersLength = stakeholders.length;
        uint256 amount = 5 * (10 ** 18);
        for (uint32 i; i < stakeholdersLength; i++) {
            address to = stakeholders[i];
            token.transfer(to, amount);
            emit RefundSent(to, amount);
        }
    }

    /*
    * Modifiers
    */
    modifier ifNotClosed() {
        require(isClosed == false, "This matchweek is already closed.");
        _;
    }
}
