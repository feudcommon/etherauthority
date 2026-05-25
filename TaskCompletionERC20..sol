// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;
// cis

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Pausable.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Permit.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract TaskCompletionToken is ERC20,ERC20Burnable,ERC20Pausable,ERC20Permit,Ownable{
    uint256 public constant REWARD_AMOUNT = 100 * 10 ** 18;
    uint256 public constant MAX_SUPPLY = 10000000 * 10 ** 18;
    
    mapping(address => uint256) TaskCompleted;
    mapping(address => bool) AuthorizedIssuers;

    event tasksCompleted(address indexed recipient, uint256 id, uint256 Reward, uint256 TotalCompleted);
    event IssuerUpdated(address indexed issuer, bool authorized);

    error NotAuthorizedIssuer();
    error ZeroAddress();
    error SupplyCapExceeded(uint256 requested, uint256 remaining);

    constructor(address initialOwner)
        ERC20("Task Completion Token", "TCT")
        ERC20Permit("Task Completion Token")
        Ownable(initialOwner)
    {
        if (initialOwner == address(0)) revert ZeroAddress();
        _mint(initialOwner, 1_000_000 * 10 ** decimals());
        AuthorizedIssuers[initialOwner] = true;
        emit IssuerUpdated(initialOwner, true);
    }


    function _update(address from, address to, uint256 value)
        internal override(ERC20, ERC20Pausable)
    {
        super._update(from, to, value);
    }

     function completeTask(address recipient, uint256 taskId) external {
        if (!AuthorizedIssuers[msg.sender]) revert NotAuthorizedIssuer();
        if (recipient == address(0)) revert ZeroAddress();

        uint256 remaining = MAX_SUPPLY - totalSupply();
        if (REWARD_AMOUNT > remaining) revert SupplyCapExceeded(REWARD_AMOUNT, remaining);

        unchecked { TaskCompleted[recipient]++; }
        _mint(recipient, REWARD_AMOUNT);
        emit tasksCompleted(recipient, taskId, REWARD_AMOUNT, TaskCompleted[recipient]);
    }

    function completeTaskBatched(address[] calldata recipients, uint256[] calldata taskIDs) external{
        if(!AuthorizedIssuers[msg.sender]) revert NotAuthorizedIssuer();
        require(recipients.length==taskIDs.length,"TCT : length mismatched");

        uint256 total = REWARD_AMOUNT *recipients.length;
        uint256 remaining = MAX_SUPPLY - totalSupply();
        if (total > remaining) revert SupplyCapExceeded(total, remaining);

        for(uint256 i; i<recipients.length; i++){
            address r = recipients[i];
            if(r == address(0)) revert ZeroAddress();
            unchecked {TaskCompleted[r]++; i++;}
            _mint(r, REWARD_AMOUNT);
            emit tasksCompleted(recipients[i],taskIDs[i], REWARD_AMOUNT, TaskCompleted[r]);
        }
    }
    
    function setIssuer(address issuer, bool status) external onlyOwner {
        if (issuer == address(0)) revert ZeroAddress();
        AuthorizedIssuers[issuer] = status;
        emit IssuerUpdated(issuer, status);
    }

    function pause() external onlyOwner { _pause(); }
    function unpause() external onlyOwner { _unpause(); }

    function remainingSupply() external view returns (uint256) {
        return MAX_SUPPLY - totalSupply();
    }
     function nonces(address owner)
        public view override(ERC20Permit) returns (uint256)
    {
        return super.nonces(owner);
    }
}