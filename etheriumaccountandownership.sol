// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

contract Accountownership{

    //state variables
    address public owner;
    address public pendingOwner;
    uint256 public balance;
    bool private locked;

    mapping(address => uint256) public contributions;
    mapping(address => bool) public whitelist;

    //events
    event OwnershipTransferInitiated(address indexed currentOwner,address indexed pendingOwner);
    event OwnershipTransferred(address indexed previousOwner,address indexed newOwner);
    event Deposited(address indexed account,uint256 amount);
    event Withdrawn(address indexed account,uint256 amount);
    event Whitelisted(address indexed account);
    event RemovedfromWhitelist(address indexed account);
    
    //errors
    error NotOwner();
    error NotPendingOwner();
    error NotWhitelisted();
    error ZeroAddress();
    error ZeroAmount();
    error InsufficientBalance(uint256 available, uint256 required);
    error TransferFailed();
    error Reentrant();

    //modifiers
    modifier onlyOwner(){
        if(msg.sender!=owner) revert NotOwner();
        _;
    }
    modifier onlyWhitelisted(){
        if(!whitelist[msg.sender]) revert NotWhitelisted();
        _;
    }
    modifier noReentrancy(){
        if(locked) revert Reentrant();
        locked=true;
        _;
        locked=false;
    }
    modifier nonZeroAmount(uint256 amount){
        if(amount == 0) revert ZeroAmount();
        _;
    }
    modifier nonZeroAddress(address addr){
        if(addr == address(0)) revert ZeroAddress();
        _;
    }

    constructor(){
        owner=msg.sender;
        whitelist[msg.sender]=true;
        emit Whitelisted(msg.sender);
    }

    //ownership functions
    function transferOwnership(address newOwner) external onlyOwner nonZeroAddress(newOwner){
        pendingOwner=newOwner;
        emit OwnershipTransferInitiated(owner, newOwner);
    }

    function acceptOwnership(address pendingOwner) external{
        if(msg.sender != pendingOwner) revert NotPendingOwner();
        emit OwnershipTransferred(owner, pendingOwner);
        owner = pendingOwner;
        pendingOwner= address(0);
    }

    function renounceOwnership() external onlyOwner{
        emit OwnershipTransferred(owner, address(0));
        owner=address(0);
    }

    //whitelist functions
    function addToWhitelist(address account)
        external
        onlyOwner
        nonZeroAddress(account)
    {
        whitelist[account] = true;
        emit Whitelisted(account);
    }

    function removefromWhitelist(address account)
    external
    onlyOwner
    nonZeroAddress(account){
        whitelist[account]=false;
        emit RemovedfromWhitelist(account);
    }

    //account functions
    function deposit()
    external
    payable
    onlyWhitelisted
    nonZeroAmount(msg.value){
        contributions[msg.sender]+=msg.value;
        balance+=msg.value;
        emit Deposited(msg.sender,msg.value);
    }

    function withdraw(uint256 amount)
    external
    payable
    onlyOwner
    nonZeroAmount(amount){
        if(amount > balance) revert InsufficientBalance(balance, msg.value);
        balance-=amount;
        (bool success, ) = payable(owner).call{value : amount}("");
        if(!success) revert TransferFailed();
        emit Withdrawn(owner,amount);
    }

    //view functions
    function getContribution(address account) external view returns (uint256) {
        return contributions[account];
    }

    function isWhitelisted(address account) external view returns (bool) {
        return whitelist[account];
    }

    function contractBalance() external view returns (uint256) {
        return address(this).balance;
    }

    // ── Fallback ─────────────────────────────────────────
    receive() external payable {
        contributions[msg.sender] += msg.value;
        balance += msg.value;
        emit Deposited(msg.sender, msg.value);
    }

}
