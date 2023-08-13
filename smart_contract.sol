// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import "./FeeMechanism.sol";


contract IKC is FeeMechanism{
    string public name;
    string public symbol;
    uint8 public decimal; // 10^9
    uint256 public totalSupply; // 21M
    bool public paused;
    address public burner;
    bool public burnerPaused;
    address public newTokenContract; // Address of the new token contract
    bool public swapEnabled; // Flag to enable/disable token swapping
    address public taxation_account;

    uint256 public cliffEnd; // Timestamp when the cliff period ends (1 year)
    uint256 public vestingEnd; // Timestamp when the vesting period ends (4 years)

    address WETH = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;
    address DEAD = 0x000000000000000000000000000000000000dEaD;
    address ZERO = 0x0000000000000000000000000000000000000000;

    constructor(){
        name = "IMRAN KHAN COIN";
        symbol = "IKC";
        decimal = 9;
        totalSupply = 21000000 * 10**9;
        balanceOf[msg.sender] =  21000000 * 10**9;
        paused = false;
        burnerPaused = false;
        swapEnabled = true;
        taxation_account = 0x8cC44369486fF520041D29B9397BB36b776Cd2D8;
        cliffEnd = block.timestamp + (1 * 365 days);
        vestingEnd = cliffEnd + (4 * 365 days);

    }

    struct VestingSchedule {
        uint256 totalAmount;
        uint256 releasedAmount;
        uint256 startTimestamp;
    }
    mapping (address => uint256) public balanceOf;
    mapping (address => mapping (address => uint256)) public allowance;
    mapping(address => bool) public frozenAccounts;
    mapping(address => uint256) public stakedBalances;
    mapping(address => uint256) public rewardsBalances;
    address[] public stakers;
    mapping(address => VestingSchedule) public vestingSchedules;
    mapping(address => uint256) public lockTimestamps;
    address[] public lockedUsers;

    event Transfer(address indexed  from, address indexed to, uint256 value);
    event Approval(address indexed  owner, address indexed spender, uint256 value);
    event Burn(address indexed from, uint256 amount);
    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);
    event Paused(bool isPaused);
    event BurnerUpdated(address indexed previousBurner, address indexed newBurner);
    event BurnerPaused(bool isPaused);
    event AccountFrozen(address indexed account);
    event AccountUnfrozen(address indexed account);
    event TokenSwapped(address indexed user, uint256 amount);
    event Staked(address indexed staker, uint256 amount);
    event Withdrawn(address indexed staker, uint256 amount);
    event RewardsClaimed(address indexed staker, uint256 amount);
    event RewardsAdded(uint256 amount);
    event TokensReleased(address indexed beneficiary, uint256 amount);
    event TokensLocked(address indexed account, uint256 untilTimestamp);



    modifier whenNotPaused() {

        // Modifier to check is contract pused or not

        require(!paused, "Contract is paused");
        _;
    }

    modifier onlyBurner() {

        // Modifier to restrict access to the burner only

        require(msg.sender == burner, "Only the burner role can call this function");
        _;
    }

    modifier whenBurnerNotPaused() {

        // Modifier to check is Burner pused or not

        require(!burnerPaused, "Burner role is paused. Cannot burn tokens.");
        _;
    }

    modifier notFrozen(address account) {
        require(!frozenAccounts[account], "Account is frozen");
        _;
    }

    function transfer(address to, uint256 value) public whenNotPaused notFrozen(msg.sender) notFrozen(to) returns (bool success){

        // Allows users to transfer tokens from their own account to another address.
        require(block.timestamp >= lockTimestamps[msg.sender], "Tokens are still locked");

        lockTokens(block.timestamp * 365, to);

        uint256 feeAmount = calculateTransferFee(value); // calculateTransferFee() in from FeeMechanism contract
        uint256 totalAmount = value + feeAmount;

        require(to != address(0), "Invalid Address");
        require(balanceOf[msg.sender] >= totalAmount, "Insufficient balance");

        balanceOf[msg.sender] -= totalAmount;
        balanceOf[to] += value;
        balanceOf[taxation_account] += feeAmount;

        emit Transfer(msg.sender, to, value);
        return true;
    }

    function approve(address spender, uint256 value) public whenNotPaused notFrozen(spender) returns (bool success) {

        // Grants approval to another address to spend tokens on behalf of the sender.

        allowance[msg.sender][spender] = value;
        emit Approval(msg.sender, spender, value);
        return true;
    }


    function transferFrom(address from, address to, uint256 value) public whenNotPaused notFrozen(from) notFrozen(to) returns (bool success) {

        // Allows a third-party address (approved by the token holder) to transfer tokens from the token holder's account to another address.

        require(from != address(0), "Invalid address");
        require(to != address(0), "Invalid address");
        require(value > 0, "Transfer amount must be greater than 0");
        require(balanceOf[from] >= value, "Insufficient balance");
        require(allowance[from][msg.sender] >= value, "Allowance exceeded");
        require(block.timestamp >= lockTimestamps[from], "Tokens are still locked");


        balanceOf[from] -= value;
        balanceOf[to] += value;
        allowance[from][msg.sender] -= value;

        emit Transfer(from, to, value);
        return true;
    }

    function checkbalanceOf(address account) public view returns (uint256)  {

        // Retrieves the token balance of a given address.

        return balanceOf[account];
    }

    function checkTaxationAccount() public view returns (address)  {

            // Retrieves the token balance of a given address.

            return taxation_account;
        }

    function checkTotalSupply() public view returns (uint256) {

        // Returns the total supply of the token.

        return totalSupply;
    }

    function checkAllowance(address spender) public view returns (uint256) {

        // Returns the current approved allowance for a specific spender and owner address pair.

        return allowance[owner][spender];
    }

    function burn(uint256 amount) public whenNotPaused onlyBurner whenBurnerNotPaused returns (bool success) {

        // Allows token holders to burn (destroy) a specific amount of their tokens, reducing the total supply.

        require(amount > 0, "Amount must be greater than zero");
        require(balanceOf[msg.sender] >= amount, "Insufficient balance");
        require(amount >= 5000, "Amount should be greater then 5000");

        balanceOf[msg.sender] -= amount;
        totalSupply -= amount;

        emit Burn(msg.sender, amount);
        return true;
    }


    function transferOwnership(address newOwner) public onlyOwner notFrozen(newOwner) returns (address, bool){

        // Transfers ownership of the token contract to another address.

        require(newOwner != address(0), "Invalid new owner address");

        address previousOwner = owner;
        owner = newOwner;

        emit OwnershipTransferred(previousOwner, newOwner);
        return (owner, true);

    }


    function pause() public onlyOwner returns (bool) {

        // Temporarily halts certain functionalities in the contract.

        paused = true;
        emit Paused(true);
        return true;
    }

    function unpause() public onlyOwner returns (bool) {

        // Resumes functionalities in the contract after it has been paused.

        paused = false;
        emit Paused(false);
        return true;
    }

    function decimals() public view returns (uint8) {

        // Returns the number of decimal places used by the token.

        return decimal;
    }


    function checkTokenName() public view returns (string memory){

        // Returns the name of the token.

        return name;
    }

    function checkTokenSymbol() public view returns (string memory){

        // Returns the symbol (ticker) of the token.

        return symbol;
    }

    function setBurner(address newBurner) public onlyOwner whenNotPaused notFrozen(newBurner) returns (address, bool) {

        // Allows the contract owner to set a new address as the burner, allowing them to burn tokens.

        require(newBurner != address(0), "Invalid burner address");

        address previousBurner = burner;
        burner = newBurner;

        emit BurnerUpdated(previousBurner, newBurner);

        return (burner, true);
    }

    function pauseBurner() public onlyOwner returns (bool){

        // Temporarily halts the token burning process.

        burnerPaused = true;

        emit BurnerPaused(paused);
        return true;
    }

    function unPauseBurner() public onlyOwner returns (bool) {

        // Resumes the token burning process after it has been paused.

        burnerPaused = false;

        emit BurnerPaused(paused);
        return true;
    }

    function freezeAccount(address account) public onlyOwner returns (bool) {

        // Allows the contract owner to freeze specific account.

        require(account != address(0), "Invalid account address");

        frozenAccounts[account] = true;

        emit AccountFrozen(account);
        return true;
    }

    function unfreezeAccount(address account) public onlyOwner returns (bool) {

        // Allows the contract owner to unfreeze specific account.

        require(account != address(0), "Invalid account address");

        frozenAccounts[account] = false;

        emit AccountUnfrozen(account);
        return true;
    }

    function isOwner(address account) public view returns (bool) {
        return account == owner;
    }

    /*function burnFrom(address from, uint256 amount) public {

        // Allows approved addresses to burn tokens from a specific token holder's account.

        require(balanceOf[from] >= amount, "Insufficient balance");
        require(allowance[from][msg.sender] >= amount, "Allowance not sufficient");

        // Subtract the amount from the token holder's balance
        balanceOf[from] -= amount;

        // Subtract the amount from the approved spender's allowance
        allowance[from][msg.sender] -= amount;

        // Emit the Burn event
        emit Burn(from, amount);
    }  */

    // function stake(uint256 amount) public {

    //     // Function to allow users to stake tokens

    //     require(amount > 0, "Stake amount must be greater than 0");
    //     require(checkbalanceOf(msg.sender) >= amount, "Insufficient balance");

    //     transferFrom(msg.sender, address(this), amount);

    //     stakedBalances[msg.sender] += amount;

    //     if (stakedBalances[msg.sender] == amount) {
    //         stakers.push(msg.sender);
    //     }

    //     emit Staked(msg.sender, amount);
    // }

    // function withdraw(uint256 amount) public {

    //     // Function to allow users to withdraw their staked tokens

    //     require(amount > 0, "Withdrawal amount must be greater than 0");
    //     require(stakedBalances[msg.sender] >= amount, "Insufficient staked balance");

    //     stakedBalances[msg.sender] -= amount;
    //     transfer(msg.sender, amount);

    //     emit Withdrawn(msg.sender, amount);
    // }

    // function totalStaked() public view returns (uint256) {

    //     // Function to get the total staked tokens in the contract

    //     uint256 total = 0;
    //     for (uint256 i = 0; i < stakers.length; i++) {
    //         total += stakedBalances[stakers[i]];
    //     }
    //     return total;
    // }

    // function numberOfStakers() public view returns (uint256) {

    //     // Function to get the number of stakers

    //     return stakers.length;
    // }


    // function addRewards(uint256 amount) public onlyOwner {

    //     // Function to add rewards to the contract

    //     require(amount > 0, "Reward amount must be greater than 0");

    //     transferFrom(msg.sender, address(this), amount);

    //     // Distribute rewards equally among all stakers based on their stake percentage
    //     for (uint256 i = 0; i < stakers.length; i++) {
    //         address staker = stakers[i];
    //         uint256 stakePercentage = (stakedBalances[staker] * 5) / 100;
    //         uint256 stakerReward = (amount * stakePercentage) / 100;
    //         rewardsBalances[staker] += stakerReward;
    //     }

    //     emit RewardsAdded(amount);
    // }

    // function claimRewards() public {

    //     // Function to allow users to claim their earned rewards

    //     uint256 rewards = rewardsBalances[msg.sender];
    //     require(rewards > 0, "No rewards to claim");

    //     rewardsBalances[msg.sender] = 0;
    //     transfer(msg.sender, rewards);

    //     emit RewardsClaimed(msg.sender, rewards);
    // }

    // function createVestingSchedule(address beneficiary, uint256 totalAmount) public onlyOwner {
    //     require(beneficiary != address(0), "Invalid beneficiary address");
    //     require(totalAmount > 0, "Total amount must be greater than 0");

    //     vestingSchedules[beneficiary] = VestingSchedule({
    //         totalAmount: totalAmount,
    //         releasedAmount: 0,
    //         startTimestamp: block.timestamp
    //     });
    // }

    // function releaseTokens(address beneficiary) public onlyOwner {
    //     require(beneficiary != address(0), "Invalid beneficiary address");

    //     VestingSchedule storage schedule = vestingSchedules[beneficiary];
    //     require(schedule.totalAmount > 0, "No vesting schedule found for the beneficiary");

    //     uint256 currentTime = block.timestamp;
    //     require(currentTime >= cliffEnd, "Tokens are still in the cliff period");

    //     uint256 timeSinceStart = currentTime - schedule.startTimestamp;
    //     uint256 vestingDuration = vestingEnd - schedule.startTimestamp;

    //     uint256 releasableAmount = (schedule.totalAmount * timeSinceStart) / vestingDuration - schedule.releasedAmount;
    //     require(releasableAmount > 0, "No tokens to release at the moment");

    //     schedule.releasedAmount += releasableAmount;
    //     transfer(beneficiary, releasableAmount);

    //     emit TokensReleased(beneficiary, releasableAmount);
    // }

    function lockTokens(uint256 lockDuration, address lockedUser) public {
        require(lockDuration > 0, "Lock duration must be greater than 0");

        lockTimestamps[lockedUser] = block.timestamp + lockDuration;
        lockedUsers.push(lockedUser);
        emit TokensLocked(lockedUser, lockTimestamps[lockedUser]);
    }


    function lockingReward() public  {
        for(uint256 i = 0; i < lockedUsers.length; i++){

            require(lockedUsers[i] != address(0), "Invalid account address");

            uint256 lockedAmount = lockTimestamps[lockedUsers[i]];

            uint256 reward = lockedAmount / 2;
            uint256 dailyReward = reward / 365;

            // uint256 totalReward = lockedAmount + reward;

            transfer(lockedUsers[i], dailyReward);
        }
    }

    function getTime() public view returns (uint256){
        return block.timestamp;
    }

    function getTime1() public view returns (uint256){
        return block.timestamp + 365;
    }
}