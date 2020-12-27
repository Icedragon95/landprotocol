// SPDX-License-Identifier: MIT
pragma solidity 0.6.12;

import "./interfaces/Burnable.sol";
import "./interfaces/UniswapRouterV2.sol";
import "./interfaces/TokenTimelock.sol";

import "./libraries/math/SafeMath.sol"; 
import "./libraries/token/SafeERC20.sol";   
import "./libraries/access/Ownable.sol";
import "./libraries/token/ERC20.sol";

contract LandPresale is Ownable {
    using SafeMath for uint256;
    using SafeERC20 for IERC20;

    // the token being sold
    IERC20 public token;

    // the addresses where collected funds are sent
    address payable public team;
    address payable public marketing;
    address payable public listing;

    // controller contract
    address public controller;

    // treasury contract
    address payable public treasury = 0xe04af79053639D2c4C1c3827F72e52459eE0E88e;

    // timelock contract
    address public timelock;

    // presale duration
    uint256 public start;
    uint256 public duration = 5 days;
    uint256 public grace = 12 days;

    // token max cap
    uint256 public cap = 100000000000000000000000; // 100,000 $LAND

    // presale threshold to close
    uint256 public threshold = 90; // 90 % of token cap

    // total to be distributed
    uint256 public total;

    // total wei deposited
    uint256 public deposited;

    // total number of depositors
    uint256 public depositors;

    // limits for investment
    uint256 public min = 200000000000000000; // 0.2 eth
    uint256 public max = 50000000000000000000; // 50 eth

    // token exchange rate for base amount (1 eth = 100 $LAND)
    uint256 public rate = 100000000000000000000;

    // public contact information
    string public contact;

    // is the presale finalized
    bool public finalized = false;

    // is the distribution finished
    bool public completed = false;

    // is the presale cancelled
    bool public cancelled = false;

    // is the presale closed
    bool public closed = false;

    // mappings for deposited, claimable
    mapping(address => uint256) public deposits;
    mapping(address => uint256) public balances;

    UniswapRouterV2 internal uniswap = UniswapRouterV2(0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D);
    UniswapV2Factory internal factory = UniswapV2Factory(0x5C69bEe701ef814a2B6a3EDD4B1652CB9cc5aA6f);

    address internal weth = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;

    /**
    * event for presale enter logging
    * @param account who will receive the tokens
    * @param value weis entered into presale
    * @param amount amount of tokens to be distributed
    */ 
    event PresaleEntered(address indexed account, uint256 value, uint256 amount);

    /**
    * event for referral earned from user
    * @param beneficiary that receives the referral bonus
    * @param amount amount of bonus tokens from daily
    */ 
    event DailyBonusEarned(address indexed beneficiary, uint256 amount);

    /**
    * event for referral earned from user
    * @param beneficiary that receives the referral bonus
    * @param account that entered presale with referral code
    * @param amount amount of bonus tokens from referral
    */ 
    event ReferrerEarned(address indexed beneficiary, address indexed account, uint256 amount);

    /**
    * event for referral earned from user
    * @param account that entered presale with referral code
    * @param amount amount of bonus tokens from referral
    */ 
    event DepositorEarned(address indexed account, uint256 amount);

    /**
    * event for claim of tokens
    * @param recipient that received the tokens
    * @param amount amount of tokens received
    */ 
    event Claimed(address indexed recipient, uint256 amount);

    /**
    * event for refund of wei
    * @param recipient that received the wei
    * @param amount amount of wei received
    */ 
    event Refunded(address indexed recipient, uint256 amount);

    /**
    * event for setting a referral
    * @param account the account that set the referral code
    * @param code referral string from 8 characters
    */ 
    event ReferralSet(address indexed account, bytes12 code);

    /**
    * event for signaling liquidity creation & lock
    * @param amount amount of lp tokens created
    * @param timelock address of timelock contract
    */
    event LiquidityAddedAndLocked(uint256 amount, address timelock);

    /**
    * event for signaling salvaged non-token assets
    * @param token salvaged token address
    * @param amount amount of tokens salvaged
    */
    event Salvaged(address token, uint256 amount);

    /**
    * event for signaling dist collection of wei
    * @param recipient address that received the wei
    * @param amount amount of wei collected
    */
    event DustCollected(address recipient, uint256 amount);

    /**
    * event for signaling destruction of leftover tokens
    * @param amount amount of tokens burned
    */
    event Destroyed(uint256 amount);

    /**
    * event for signaling presale completion
    */
    event Completed();

    // CONSTRUCTOR

    constructor(
        address _token,
        address _timelock,
        uint256 _start,
        string memory _contact
    ) public {
        //require(_start >= block.timestamp);
        
        token = IERC20(_token);
        timelock = _timelock;
        start = _start;
        contact = _contact;

        team = 0x0dB32cD2805c541375DFa609D4866D132A4687A6;
        marketing = 0x685Da6c75698611ac875d8a485d6eFB18A88921D;
        listing = 0xBF2Ba575C25F36Ea507726656a7fdB4374974Aa2;
    }

    // fallback function to enter presale
    receive () external payable {
        // will probably fail unless gas limit is set high
        enter(msg.value);
    }

    /**
    * Low level presale enter function
    * @param _amount the wei amount
    */
    function enter(uint256 _amount) public payable active {
        require(msg.value == _amount);
        require(msg.sender != address(0));
        require(valid(msg.sender, _amount));

        uint256 amount;
        uint256 acquired;

        // calculate base tokens
        amount = _amount.mul(rate).div(1e18);
        require(distributable(amount), "not enough tokens for distribution");

        // calculate daily bonus
        uint256 dailyBonus = calculateDailyBonus(amount);
        
        if (dailyBonus > 0) {
            if (distributable(amount.add(dailyBonus))) {
                acquired = acquired.add(dailyBonus);
                emit DailyBonusEarned(msg.sender, dailyBonus);
            }
        }

        // store in dictionary
        uint256 distribution = amount.add(acquired);
        deposits[msg.sender] = deposits[msg.sender].add(_amount);
        balances[msg.sender] = balances[msg.sender].add(distribution);
        emit PresaleEntered(msg.sender, amount, distribution);

        deposited = deposited.add(_amount);
        depositors = depositors.add(1);
        total = total.add(distribution);
    }

    function calculateDailyBonus(uint256 amount) internal view returns (uint256 dailyBonus) {
        if (block.timestamp <= start.add(1 days)) {
            dailyBonus = amount.mul(125).div(1000); // 12.5 % for first day
        }
        else if (block.timestamp <= start.add(2 days)) {
            dailyBonus = amount.mul(75).div(1000); // 7.5 % for second day
        }
        else if (block.timestamp <= start.add(3 days)) {
            dailyBonus = amount.mul(50).div(1000); // 5.0 % for third day
        }
        else if (block.timestamp <= start.add(4 days)) {
            dailyBonus = amount.mul(25).div(1000); // 2.5 % for fourth day
        }
    }

    /**
    * Refund collected eth from user if presale is cancelled
    */
    function refund() external {
        require(cancelled, "presale is not cancelled");
        require(deposits[msg.sender] > 0, "you have not deposited anything");

        // return collected ether
        uint256 amount = deposits[msg.sender];

        total = total.sub(balances[msg.sender]);
        deposited = deposited.sub(amount);
        deposits[msg.sender] = 0;
        balances[msg.sender] = 0;
        
        msg.sender.transfer(amount);
        emit Refunded(msg.sender, amount);
    }

    /**
    * Claim tokens after presale is distributed
    */
    function claim() external distributed {
        require(balances[msg.sender]> 0, "you can not claim any tokens");

        // send claimable token to user
        uint256 amount = balances[msg.sender];
        balances[msg.sender] = 0;

        token.safeTransfer(msg.sender, amount);
        emit Claimed(msg.sender, amount);
    }

    /**
    * Distribute wei, create liquidity pair and start rewards after presale end
    */
    function distribute() external {
        require(concluded(), "presale is not concluded");
        require(address(this).balance >= deposited, "!balance >= deposited");
        
        if (deposited > 0) {
            // calculate distribution amounts
            uint256 _liquidity = deposited.mul(30).div(100); // 30 % to liquidity
            uint256 _team = deposited.mul(20).div(100); // 20 % to team
            uint256 _marketing = deposited.mul(30).div(100); // 30 % to marketing
            uint256 _listing = deposited
                .sub(_liquidity)
                .sub(_team)
                .sub(_marketing); // 20 % to exchange listings

            // calculate token uniswap liquidity amount
            uint256 _uniswap = _liquidity.mul(rate).div(1e18);

            // create uniswap pair
            token.safeApprove(address(uniswap), _uniswap);
            ( , , uint256 added) = uniswap.addLiquidityETH{value: _liquidity}(address(token), _uniswap, 0, 0, address(timelock), block.timestamp + 5 minutes);
            emit LiquidityAddedAndLocked(added, timelock);

            // get uniswap pair address
            address pair = factory.getPair(address(token), weth);

            // set token in timelock contract
            ITokenTimelock(timelock).set_token(pair);

            // transfer wei to addresses
            team.transfer(_team);
            marketing.transfer(_marketing);
            listing.transfer(_listing);
        }

        // signal distribution complete
        completed = true;
        emit Completed();
    }

    /**
    * Salvage unrelated tokens to presale
    * @param _token address of token to salvage
    */
    function salvage(address _token) external distributed onlyOwner {
        require(_token != address(token), "can not salvage token");

        uint256 balance = IERC20(_token).balanceOf(address(this));
        if (balance > 0) {
            IERC20(_token).safeTransfer(treasury, balance);
            emit Salvaged(_token, balance);
        }
    }

    /**
    * Collect wei left as dust on contract after grace period
    */
    function collect_dust() external distributed onlyOwner {
        require(!cancelled);
        require(block.timestamp >= start.add(grace), "grace period not over");

        uint256 balance = address(this).balance;
        if (balance > 0) {
            treasury.transfer(balance);
            emit DustCollected(treasury, balance);
        }
    }

    /**
    * Destroy (burn) leftover tokens from presale
    */
    function destroy() external distributed onlyOwner {
        require(!cancelled);
        require(block.timestamp >= start.add(grace), "grace period not over");

        uint256 balance = token.balanceOf(address(this));
        if (balance > 0) {
            Burnable(address(token)).burn(balance);
            emit Destroyed(balance);
        }
    }

    // *** RESTRICTED ***

    /**
    * Set controller contract for the presale
    * @param _controller address of controller contract
    */
    function set_controller(address _controller) external onlyOwner {
        require(controller == address(0), "!controller");
        controller = _controller;
    }

    /**
    * Update contact information on the contract
    * @param _contact text to set as contact information
    */
    function update(string memory _contact) external onlyOwner {
        contact = _contact;
    }

    /**
    * Cancel presale, stop accepting wei and enable refunds
    */
    function cancel() external onlyOwner {
        cancelled = true;
    }

    /**
    * Close presale if threshold is reached
    */
    function close() external onlyOwner {
        require(reached(), "threshold is not reached");

        closed = true;
    }

    // *** VIEWS **** //

    /**
    * Returns deposited ETH amount for address
    */
    function depositedBy() external view returns (uint256) {
        return deposits[msg.sender];
    }

    /**
    * Returns claimable amount for address
    */
    function claimable() external view returns (uint256 amount) {
        if (!cancelled) {
            amount = balances[msg.sender];
        }
        return amount;
    }

    /**
    * Check if wei amount is within limits
    */
    function valid(address account, uint256 amount) internal view returns (bool) {
        bool above = deposits[account].add(amount) >= min;
        bool below = deposits[account].add(amount) <= max;

        return (above && below);
    }

    /**
    * Check if token amount can be distributed
    */
    function distributable(uint256 amount) internal view returns (bool) {
        bool below = total.add(amount) <= cap;

        return (below);
    }

    /**
    * Check if presale if concluded
    */
    function concluded() internal view returns (bool) {
        if (closed) {
            return true;
        }

        if (block.timestamp > start.add(duration) && !cancelled) {
            return true;
        }

        return false;
    }

    /**
    * Check if threshold is reached
    */
    function reached() internal view returns (bool) {
        bool above = total.mul(100).div(cap) >= threshold;

        return (above);
    }

    // *** MODIFIERS **** //

    modifier distributed {
        require(
            completed,
            "tokens were not distributed yet"
        );

        _;
    }

    modifier active {
        // require(
        //     block.timestamp >= start,
        //     "presale has not started yet"
        // );

        // require(
        //     block.timestamp <= start.add(duration),
        //     "presale has concluded"
        // );

        // require(
        //     !cancelled,
        //     "presale was cancelled"
        // );

        require(
            !closed,
            "presale was closed"
        );

        _;
    }
}