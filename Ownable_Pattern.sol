// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

contract Ownable {

    address private _owner;

    // Events
    event OwnershipTransferred(
        address indexed previousOwner,
        address indexed newOwner
    );

    //custom errors
    error NotOwner(address caller);
    error ZeroAddress();

   // constructor
    constructor() {
        _transferOwnership(msg.sender);
    }

    //modifier
    modifier onlyOwner() {
        if (msg.sender != _owner) revert NotOwner(msg.sender);
        _;
    }

    //view function
    function owner() public view returns (address) {
        return _owner;
    }

    //external protected function
    //only owner can call it
    //used to transfer ownership to another address
    //newOwner cannot be address(0)
    //calls _transferOwnership to do the actual transfer

    function transferOwnership(address newOwner) external onlyOwner {
        if (newOwner == address(0)) revert ZeroAddress();
        _transferOwnership(newOwner);
    }

    //protected function
    //remove ownership completely
    //external implies outside callers can use it(not contract itself)
    function renounceOwnership() external onlyOwner {
        _transferOwnership(address(0));
    }

    //(internal)only this contract or contracts that inherit can call this function
    //(external)only outside callers can call this function
    //(public)both inside and outside callers can call this function
    //the below function stores the old owner in a local variable then fires the event(emit) to write change to blockchain forever    
    function _transferOwnership(address newOwner) internal {
        address previous = _owner;
        _owner = newOwner;
        emit OwnershipTransferred(previous, newOwner);
    }
}
