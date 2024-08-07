// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "./FunctionsConsumer.sol";

contract MatchWeek is Initializable, OwnableUpgradeable {
    error MatchWeek__AlreadyClosed();
    error MatchWeek_NotClosedYet();
    error MatchWeek__OnlyFactoryOrOwnerAllowed();

    event BetAdded(address indexed sender, uint256 amount, Bet[] bets);
    event RewardSended(address indexed to, uint256 reward);
    event RefundSent(address to, uint256 refunded);
    event EnabledMatchWeek(uint256 id);
    event MatchAdded(uint256 id);

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
    address private s_factoryAddress;

    IERC20 s_token;
    FunctionsConsumer s_consumer;

    function initialize(uint256 id, string memory _title, address owner, address consumer) public initializer {
        __Ownable_init(owner);
        s_id = id;
        s_isEnabled = false;
        s_title = _title;
        s_isClosed = false;
        s_consumer = FunctionsConsumer(consumer);
        s_factoryAddress = msg.sender;
    }

    function enable() external onlyOwnerOrFactory {
        s_isEnabled = true;
        emit EnabledMatchWeek(s_id);
    }

    function summary() external view returns (string memory, bool, bool, uint256, uint256) {
        return (s_title, s_isEnabled, s_isClosed, s_stakeholders.length, s_id);
    }

    function close() external onlyOpen {
        s_isClosed = true;
    }

    function getResults() external view returns (string memory) {
        return s_consumer.getResponse();
    }

    function addMatches(Match[] calldata matchesToAdd) external onlyOwner onlyOpen {
        uint256 matchesLength = matchesToAdd.length;

        for (uint8 i; i < matchesLength; ++i) {
            uint32 matchId = matchesToAdd[i].id;
            Match memory newMatch =
                Match(matchId, matchesToAdd[i].localTeam, matchesToAdd[i].awayTeam, Result.UNDEFINED);
            s_matches[matchId] = newMatch;
            s_matchesIds.push(matchId);
            emit MatchAdded(matchId);
            s_numOfMatches++;
        }
    }

    function addBets(Bet[] calldata bets, address paymentTokenAddress) external onlyOpen {
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

    function addResults(MatchResult[] calldata results) external onlyOwner onlyOpen {
        uint256 resultsLength = results.length;
        for (uint8 i = 0; i < resultsLength; ++i) {
            s_matches[results[i].matchId].result = results[i].result;
        }

        _sendRewardsToWinners();
        s_isClosed = true;
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

    function getMatches() external view returns (Match[] memory) {
        uint256 matchesIdsLentgh = s_numOfMatches;
        Match[] memory matchesArray = new Match[](s_numOfMatches);
        for (uint8 i = 0; i < matchesIdsLentgh; ++i) {
            matchesArray[i] = s_matches[s_matchesIds[i]];
        }

        return matchesArray;
    }

    function title() external view returns (string memory) {
        return s_title;
    }

    function getMyBets(address user) external view returns (Bet[] memory) {
        return s_betsByStakeholder[user];
    }

    /**
     * Private functions
     */
    function _sendRewardsToWinners() private onlyOwner {
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
            _sendReward(winners, winnersCount);
        }
    }

    function _sendReward(address[] memory to, uint8 winnersCount) private {
        uint256 reward = _getRewardToSend(winnersCount);

        for (uint32 i; i < winnersCount; ++i) {
            s_token.transfer(to[i], reward);
            emit RewardSended(to[i], reward);
        }
    }

    function _getRewardToSend(uint256 winnersLength) private view returns (uint256) {
        uint256 currentBalance = s_token.balanceOf(address(this));

        uint256 reward = currentBalance / BASE_PERCENTAGE * REWARD_PERCENTAGE;
        uint256 userReward = reward / winnersLength;

        return userReward;
    }

    /**
     * Modifiers
     */
    modifier onlyOpen() {
        if (s_isClosed == true) {
            revert MatchWeek__AlreadyClosed();
        }
        _;
    }

    modifier onlyOwnerOrFactory() {
        if (msg.sender != s_factoryAddress && msg.sender != owner()) {
            revert MatchWeek__OnlyFactoryOrOwnerAllowed();
        }
        _;
    }
}
