// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

contract EtherTransfer {
    address public owner;

    event Sent(address indexed from, address indexed to, uint256 amount);//making event of sent
    event Received(address indexed from, uint256 amount);//event of received

    error ZeroAddress();
    error InsufficientBalance(uint256 available, uint256 required);
    error TransferFailed();

    modifier onlyOwner() {
        require(msg.sender == owner, "Not owner");
        _;
    }
    //condition of only owner of contract being able to enter function
    constructor() {
        owner = msg.sender;
    }

    receive() external payable {
        emit Received(msg.sender, msg.value);
    }//if msg.data is not there

    fallback() external payable {
        emit Received(msg.sender, msg.value);
    }//if msg.data is there

    /// @notice Send Ether using .call (recommended method)
    function sendViaCall(address payable to, uint256 amount) external onlyOwner {
        if (to == address(0)) revert ZeroAddress();

        uint256 bal = address(this).balance;
        if (bal < amount) revert InsufficientBalance(bal, amount);

        (bool success, ) = to.call{value: amount}("");
        if (!success) revert TransferFailed();

        emit Sent(address(this), to, amount);
    }

    function deposit() external payable {}

    function getBalance() external view returns (uint256) {
        return address(this).balance;
    }
}
