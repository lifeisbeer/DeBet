pragma solidity ^0.8.1;
pragma abicoder v2;
pragma experimental SMTChecker;

contract DeBet {

    address payable public creator;
    uint new_bet_id;
    enum Vote { N, T, F }
    // Stores details about each actor (maker or player or validator)
    struct Actor {
        uint stake;
        Vote vote;
    }
    // Stores details about each bet
    struct Bet {
        string name;
        address maker;
        uint makerStake;
        uint expiration;
        address[] validators;
        mapping(address => Actor) validatorDetails;
        uint guarantee;
        address[] players;
        mapping(address => Actor) playerDetails;
        uint pool;
        bool outcome;
    }
    mapping(uint => Bet) public bets;

    constructor() {
        // store creator address to resolve disputes which are not resolved
        // by community vote (eg tie) and give small incentive (eg 1%)
        creator = payable(msg.sender);
        // initialise bet ids
        new_bet_id = 0;
    }

    function make_bet(string memory name, uint time) external payable returns (uint) {
        // need to have available spots for new bets
        require(new_bet_id < 2**256-1, "Run out of bet spots, consider deploying new contract");
        // this is the name of the bet that the users will see, must be binary
        // (eg "MUN to beat ARS on Friday" or link to sport event or anything else)
        bets[new_bet_id].name = name;
        // store maker's details
        bets[new_bet_id].maker = msg.sender;
        // players can see maker's stake to deside on bet value, the maker needs to call some functions,
        // if they don't execute those funcions then their stake will remain locked in the contract
        // players are insentivised to choose bets with large maker stake
        bets[new_bet_id].makerStake = msg.value;
        // user should check manually that the expiration is a reasonable
        // amount of time before the end of the actual event they are betting,
        // as otherwise bets might be placed after the event ended!
        bets[new_bet_id].expiration = time;
        // increament id counter
        new_bet_id++;
        // return bet id for this bet
        return new_bet_id-1;
    }

    // validators are the people that report back the result of the bet in exchange for a persentage of the
    // bets proportional to their stake. if a validator reports incorrect result or fails to report then they
    // lose their stake. players are insentivised to choose bets with a lot of validators and a high validator
    // stake (guarantee). total bets are equal to half of the amount staked by validators (guarantee/2)
    function become_validator(uint bet_id) payable external {
        // bet must already be created
        require(bet_id < new_bet_id, "Event doesn't exist");
        // shouldn't add any validators after half time (to give users time to respond)
        require(block.number <= bets[bet_id].expiration/2, "Can't add more validators (time limit)");
        // check that user is not already a validator
        require(bets[bet_id].validatorDetails[msg.sender].stake == 0);
        // check that the stake is not zero
        require(msg.value > 0);
        // assign as validator
        bets[bet_id].validatorDetails[msg.sender] = Actor(msg.value, Vote.N);
        // keep validator address
        bets[bet_id].validators.push(msg.sender);
        // to remove the stupid warning
        require(bets[bet_id].guarantee < 2**255-msg.value-1);
        // increse guarantee
        bets[bet_id].guarantee += msg.value;
    }
}
