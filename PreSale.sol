// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract PreSale is Ownable {
    IERC20 public token;         // The token being sold
    IERC20 public usdt;          // USDT token contract
    uint256 public rate;         // Tokens per 1 USDT
    uint256 public cap;          // Max USDT allowed to raise
    uint256 public totalRaised;  // Total USDT raised
    uint256 public endTime;      // Pre-sale end timestamp
    address fundsWallet;

    mapping(address => uint256) public contributions;

    event TokensPurchased(address indexed buyer, uint256 usdtAmount, uint256 tokensAmount);

    constructor(
        address _tokenAddress,
        address _usdtAddress,
        uint256 _rate,
        uint256 _cap,
        uint256 _durationDays,
        address _fundsWallet
    ) {
        require(_tokenAddress != address(0), "Invalid token address");
        require(_usdtAddress != address(0), "Invalid USDT address");
        require(_fundsWallet != address(0), "Invalid USDT address");
        require(_rate > 0, "Invalid rate");
        require(_cap > 0, "Invalid cap");

        token = IERC20(_tokenAddress);
        usdt = IERC20(_usdtAddress);
        rate = _rate;
        cap = _cap;
        endTime = block.timestamp + (_durationDays * 1 days);
        fundsWallet = _fundsWallet;
    }

    modifier onlyBeforeEnd() {
        require(block.timestamp < endTime, "Pre-sale has ended");
        _;
    }

    modifier onlyAfterEnd() {
        require(block.timestamp >= endTime, "Pre-sale has not ended");
        _;
    }

    function buyTokens(uint256 usdtAmount) public onlyBeforeEnd {
        uint256 tokensAmount = usdtAmount / rate;

        require(totalRaised + usdtAmount <= cap, "Cap exceeded");

        contributions[msg.sender] += usdtAmount;
        totalRaised += usdtAmount;

        // Transfer USDT from buyer to the fundsWallet
        usdt.transferFrom(msg.sender, fundsWallet, usdtAmount);

        // Transfer tokens to the buyer
        token.transfer(msg.sender, tokensAmount);

        emit TokensPurchased(msg.sender, usdtAmount, tokensAmount);
    }

    function withdrawTokens() public onlyAfterEnd {
        uint256 usdtAmount = contributions[msg.sender];
        uint256 tokensAmount = usdtAmount * rate;

        require(tokensAmount > 0, "No tokens to withdraw");

        contributions[msg.sender] = 0;
        token.transfer(msg.sender, tokensAmount);
    }

    function withdrawUSDT() public onlyOwner onlyAfterEnd {
        usdt.transfer(owner(), usdt.balanceOf(address(this)));
    }

    function setEndTime(uint256 _endTime) public onlyOwner {
        require(_endTime > block.timestamp, "Invalid end time");
        endTime = _endTime;
    }
    function setTokenPrice (uint _newPrice) public onlyOwner{
        rate = _newPrice;
    }
}
