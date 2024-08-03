// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "./FunctionsConsumer.sol";

contract MatchWeek is Initializable, OwnableUpgradeable {
    error MatchWeek__AlreadyClosed();
    error MatchWeek_NotClosedYet();

    event BetAdded(address indexed sender, uint256 amount, Bet[] bets);
    event RewardSended(address indexed to, uint256 reward);
    event RefundSent(address to, uint256 refunded);

    uint256 private constant AMOUNT_TO_BET = 5 * 1e18;
    uint256 private constant REWARD_PERCENTAGE = 90;
    uint256 private constant BASE_PERCENTAGE = 91000;

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
        UNDEFINED // 3

    }

    uint256 public s_id;
    string public s_title;
    bool public s_isEnabled;
    bool public s_isClosed;

    uint256[] private s_matchesIds;
    uint8 private s_numOfMatches;
    mapping(uint256 => Match) public s_matches;
    mapping(address => Bet[]) private s_betsByStakeholder;
    address[] private s_stakeholders;

    IERC20 s_token;
    FunctionsConsumer s_consumer;

    function initialize(uint256 id, string memory _title, address owner, address consumer) public initializer {
        __Ownable_init(owner);
        s_id = id;
        s_isEnabled = false;
        s_title = _title;
        s_isClosed = false;
        s_consumer = FunctionsConsumer(consumer);
    }

    function enable() external {
        s_isEnabled = true;
    }

    function summary() external view returns (string memory, bool, bool, uint256, uint256) {
        return (s_title, s_isEnabled, s_isClosed, s_stakeholders.length, s_id);
    }

    function close() external ifNotClosed {
        s_isClosed = true;
    }

    function addMatches(Match[] calldata matchesToAdd) public onlyOwner ifNotClosed {
        uint256 matchesLength = matchesToAdd.length;

        for (uint8 i; i < matchesLength; ++i) {
            uint32 matchId = matchesToAdd[i].id;
            Match memory newMatch =
                Match(matchId, matchesToAdd[i].localTeam, matchesToAdd[i].awayTeam, Result.UNDEFINED);
            s_matches[matchId] = newMatch;
            s_matchesIds.push(matchId);
            s_numOfMatches++;
        }
    }

    function addBets(Bet[] calldata bets, address paymentTokenAddress) public ifNotClosed {
        s_token = IERC20(paymentTokenAddress);
        uint256 allowedAmountToTransfer = s_token.allowance(msg.sender, address(this)) * (10 ** 18);
        require(AMOUNT_TO_BET <= allowedAmountToTransfer, "You need to approve your tokens first");
        s_token.transferFrom(msg.sender, address(this), AMOUNT_TO_BET);

        uint256 betsLength = bets.length;
        for (uint8 i; i < betsLength; ++i) {
            uint32 matchId = bets[i].matchId;
            Result result = bets[i].result;

            s_betsByStakeholder[msg.sender].push(Bet(matchId, result));
        }
        s_stakeholders.push(msg.sender);
        emit BetAdded(msg.sender, AMOUNT_TO_BET, s_betsByStakeholder[msg.sender]);
    }

    function getResults() external view returns (string memory) {
        return s_consumer.getResponse();
    }

    function addResults(MatchResult[] calldata results) public onlyOwner ifNotClosed {
        uint256 resultsLength = results.length;
        for (uint8 i = 0; i < resultsLength; ++i) {
            s_matches[results[i].matchId].result = results[i].result;
        }

        sendRewardsToWinners();
        s_isClosed = true;
    }

    function sendRewardsToWinners() private onlyOwner {
        uint256 stakeholdersLength = s_stakeholders.length;
        address[] memory winners = new address[](s_stakeholders.length);
        uint8 winnersCount = 0;
        for (uint8 i; i < stakeholdersLength; ++i) {
            address currentStakeHolder = s_stakeholders[i];
            Bet[] memory allBetsByStakeHolder = s_betsByStakeholder[currentStakeHolder];
            bool allBetsHitted = true;

            uint8 j = 0;
            uint256 allBetsByStakeHolderLength = allBetsByStakeHolder.length;
            while (j < allBetsByStakeHolderLength && allBetsHitted == true) {
                Bet memory betToCompare = allBetsByStakeHolder[j];

                if (s_matches[betToCompare.matchId].result != betToCompare.result) {
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

    function getRewardToSend(uint256 winnersLength) private view returns (uint256) {
        uint256 currentBalance = s_token.balanceOf(address(this));

        uint256 reward = currentBalance / BASE_PERCENTAGE * REWARD_PERCENTAGE;
        uint256 userReward = reward / winnersLength;

        return userReward;
    }

    function sendReward(address[] memory to, uint8 winnersCount) private {
        uint256 reward = getRewardToSend(winnersCount);

        for (uint32 i; i < winnersCount; ++i) {
            s_token.transfer(to[i], reward);
            emit RewardSended(to[i], reward);
        }
    }

    function withdrawFunds() external onlyOwner {
        if (s_isClosed == false) {
            revert MatchWeek_NotClosedYet();
        }
        require(s_isClosed == true, "This is not closed yet!");

        address owner = owner();
        uint256 balance = s_token.balanceOf(address(this));
        s_token.transfer(owner, balance);
    }

    function refundToStakeholders() external onlyOwner {
        uint256 stakeholdersLength = s_stakeholders.length;
        uint256 amount = AMOUNT_TO_BET;
        for (uint32 i; i < stakeholdersLength; i++) {
            address to = s_stakeholders[i];
            s_token.transfer(to, amount);
            emit RefundSent(to, amount);
        }
    }

    /**
     * Getters
     */
    function title() public view returns (string memory) {
        return s_title;
    }

    function getMyBets(address user) public view returns (Bet[] memory) {
        return s_betsByStakeholder[user];
    }

    function getMatches() public view returns (Match[] memory) {
        uint256 matchesIdsLentgh = s_numOfMatches;
        Match[] memory matchesArray = new Match[](s_numOfMatches);
        for (uint8 i = 0; i < matchesIdsLentgh; ++i) {
            matchesArray[i] = s_matches[s_matchesIds[i]];
        }

        return matchesArray;
    }

    /*
    * Modifiers
    */
    modifier ifNotClosed() {
        if (s_isClosed == true) {
            revert MatchWeek__AlreadyClosed();
        }
        _;
    }
}
