//SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

/**
 * @title Raffle Contract
 * @author Dean Krupka
 * @notice Contract creates a sweepstakes/drawing/raffle
 * @dev Implements Chainlink VRFv2
 */

import {VRFCoordinatorV2Interface} from "@chainlink/contracts/src/v0.8/interfaces/VRFCoordinatorV2Interface.sol";
import {VRFConsumerBaseV2} from "@chainlink/contracts/src/v0.8/VRFConsumerBaseV2.sol";

contract Raffle is VRFConsumerBaseV2 {
    error Raffle__NotEnoughETHToEnterRaffle();
    error Raffle__TransferFailed();
    error Raffle__RaffleNotOpen();
    error Raffle__UpkeepNotNeeded(
        uint256 currentBalance,
        uint256 numPlayers,
        uint256 raffleStatus
    );

    //Type Declarations
    enum RaffleStatus {
        OPEN,
        CALCULATING
    }

    //State Variables
    uint16 private constant REQUEST_CONFIRMATIONS = 3;
    uint32 private constant NUM_WORDS = 1;

    uint256 private immutable i_entranceFee;
    VRFCoordinatorV2Interface private immutable i_vrfCoordinator;
    bytes32 private immutable i_gasLane;
    uint256 private immutable i_interval; // @Dev i_interval is duration of lottery in seconds
    uint64 private immutable i_subscriptionId;
    uint32 private immutable i_callbackGasLimit;
    address payable[] private s_players; // payable bc they need to be able to win
    uint256 private s_lastTimeStamp;
    address private s_mostRecentWinner;
    RaffleStatus private s_raffleStatus;

    event PlayerEnteredRaffle(address indexed player);
    event PickedWinner(address indexed winner);
    event RequestedRaffleWinner(uint256 indexed requestId);

    constructor(
        uint256 entranceFee,
        uint256 interval,
        address vrfCoordinator,
        bytes32 gasLane,
        uint64 subscriptionId,
        uint32 callbackGasLimit
    ) VRFConsumerBaseV2(vrfCoordinator) {
        i_entranceFee = entranceFee;
        i_interval = interval;
        i_vrfCoordinator = VRFCoordinatorV2Interface(vrfCoordinator);
        i_gasLane = gasLane;
        i_subscriptionId = subscriptionId;
        i_callbackGasLimit = callbackGasLimit;

        s_lastTimeStamp = block.timestamp;
        s_raffleStatus = RaffleStatus.OPEN;
    }

    function enterRaffle() external payable {
        if (msg.value < i_entranceFee) {
            revert Raffle__NotEnoughETHToEnterRaffle();
        }
        if (s_raffleStatus != RaffleStatus.OPEN) {
            revert Raffle__RaffleNotOpen();
        }
        s_players.push(payable(msg.sender));

        emit PlayerEnteredRaffle(msg.sender);
    }

    /**
     * @dev checkUpKeep is function Chainlink Automation calls
     * to determine if upkeep is necessary. The following should be
     * true for this to return true:
     * 1. the time interval has passed between raffle runs
     * 2. The raffles is in the OPEN state
     * 3. The contract has ETH, AKA players
     * 4. (implicit) Subscription is funded with LINK
     * */
    function checkUpkeep(
        bytes memory /* checkdata */
    ) public view returns (bool upKeepNeeded, bytes memory /* performData */) {
        bool enoughTimePassed = (block.timestamp - s_lastTimeStamp) >=
            i_interval;
        bool isOpen = RaffleStatus.OPEN == s_raffleStatus;
        bool hasBalance = address(this).balance > 0;
        bool hasPlayers = s_players.length > 0;
        upKeepNeeded = (enoughTimePassed && isOpen && hasBalance && hasPlayers);
        return (upKeepNeeded, "0x0");
    }

    function performUpkeep(bytes calldata /*performData*/) external {
        (bool upKeepNeeded, ) = checkUpkeep("");
        if (!upKeepNeeded) {
            revert Raffle__UpkeepNotNeeded(
                address(this).balance,
                s_players.length,
                uint256(s_raffleStatus)
            );
        }
        s_raffleStatus = RaffleStatus.CALCULATING;
        uint256 requestId = i_vrfCoordinator.requestRandomWords(
            i_gasLane,
            i_subscriptionId,
            REQUEST_CONFIRMATIONS,
            i_callbackGasLimit,
            NUM_WORDS
        );
        emit RequestedRaffleWinner(requestId);
    }

    function fulfillRandomWords(
        uint256 /* requestId */,
        uint256[] memory randomWords
    ) internal override {
        uint256 indexOfWinner = randomWords[0] % s_players.length;
        address payable winner = s_players[indexOfWinner];
        s_mostRecentWinner = winner;
        s_raffleStatus = RaffleStatus.OPEN;

        s_players = new address payable[](0);
        s_lastTimeStamp = block.timestamp;
        emit PickedWinner(winner);

        (bool success, ) = winner.call{value: address(this).balance}("");
        if (!success) {
            revert();
        }
    }

    //Getter Functions:
    function getEntranceFee() public view returns (uint256) {
        return i_entranceFee;
    }

    function getMostRecentWinner() public view returns (address) {
        return s_mostRecentWinner;
    }

    function getRaffleStatus() external view returns (RaffleStatus) {
        return s_raffleStatus;
    }

    function getPlayers(uint256 indexOfPlayer) external view returns (address) {
        return s_players[indexOfPlayer];
    }

    function getLengthOfPlayers() external view returns (uint256) {
        return s_players.length;
    }

    function getLastTimeStamp() external view returns (uint256) {
        return s_lastTimeStamp;
    }
}
