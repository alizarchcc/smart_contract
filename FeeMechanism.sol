// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;


contract FeeMechanism {
    address public owner;
    uint256 public transferFeePercentage;

    event TransferFeePercentageUpdated(uint256 newFeePercentage);

    constructor() {
        owner = msg.sender;
        transferFeePercentage = 3; // Default transfer fee percentage (1%)
    }

    modifier onlyOwner() {

        // Modifier to restrict access to the owner only

        require(msg.sender == owner, "Only the contract owner can call this function");
        _;
    }

    function updateTransferFeePercentage(uint256 newFeePercentage) public onlyOwner {

        // For update transfer fee percentage

        require(newFeePercentage <= 100, "Fee percentage must be between 0 and 100");
        transferFeePercentage = newFeePercentage;

        emit TransferFeePercentageUpdated(newFeePercentage);
    }

    function calculateTransferFee(uint256 amount) public view returns (uint256) {

        // Calculate fee

        return (amount * transferFeePercentage) / 100;
    }
}
