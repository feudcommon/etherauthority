//SPDX-License-Identifier : GPL 3.0
pragma solidity  ^0.8.19;

contract counter{
    uint256 public count = 0;

    function increment() public {
        count+=1;
    }

     function decrement() public {
        count-=1;
    }

    function reset() public {
        count=0;
    }
}