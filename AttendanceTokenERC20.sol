// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Pausable.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Permit.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract AttendanceToken is ERC20,ERC20Burnable,ERC20Pausable,ERC20Permit,Ownable{

    uint256 public constant ATTENDANCE_REWARD = 10 * 10 ** 18;
    uint256 public constant STREAK_BONUS      = 5  * 10 ** 18;
    uint256 public constant MAX_SUPPLY        = 50_000_000 * 10 ** 18;
    uint256 public constant STREAK_WINDOW     = 2 days;

    mapping(address => uint256) public attendanceCount;
    mapping(address => uint256) public lastCheckIn;
    mapping(address => uint256) public streakCount;
    mapping(address => bool)    public authorizedRecorders;

    event AttendanceRecorded(address indexed attendee, uint256 indexed sessionId, uint256 reward, uint256 streak, uint256 totalAttendance);
    event RecorderUpdated(address indexed recorder, bool authorized);

    error NotAuthorizedRecorder();
    error ZeroAddress();
    error AlreadyCheckedIn(uint256 lastCheckIn);
    error SupplyCapExceeded(uint256 requested, uint256 remaining);
     
      constructor(address initialOwner)
        ERC20("Attendance Token", "ATT")
        ERC20Permit("Attendance Token")
        Ownable(initialOwner)
    {
        if (initialOwner == address(0)) revert ZeroAddress();
        _mint(initialOwner, 500_000 * 10 ** decimals());
        authorizedRecorders[initialOwner] = true;
        emit RecorderUpdated(initialOwner, true);
    }

    function recordAttendance(address attendee, uint256 sessionId) external {
        if (!authorizedRecorders[msg.sender]) revert NotAuthorizedRecorder();
        if (attendee == address(0)) revert ZeroAddress();

        uint256 last = lastCheckIn[attendee];
        if (last != 0 && block.timestamp < last + 12 hours) revert AlreadyCheckedIn(last);

        uint256 streak = _updateStreak(attendee);
        uint256 reward = ATTENDANCE_REWARD + (streak * STREAK_BONUS);

        uint256 remaining = MAX_SUPPLY - totalSupply();
        if (reward > remaining) revert SupplyCapExceeded(reward, remaining);

        unchecked { attendanceCount[attendee]++; }
        lastCheckIn[attendee] = block.timestamp;

        _mint(attendee, reward);
        emit AttendanceRecorded(attendee, sessionId, reward, streak, attendanceCount[attendee]);
    }

    function recordAttendanceBatch(address[] calldata attendees, uint256 sessionId) external {
        if (!authorizedRecorders[msg.sender]) revert NotAuthorizedRecorder();

        for (uint256 i = 0; i < attendees.length;) {
            address a = attendees[i];
            if (a == address(0)) revert ZeroAddress();

            uint256 last = lastCheckIn[a];
            if (last == 0 || block.timestamp >= last + 12 hours) {
                uint256 streak = _updateStreak(a);
                uint256 reward = ATTENDANCE_REWARD + (streak * STREAK_BONUS);

                uint256 remaining = MAX_SUPPLY - totalSupply();
                if (reward > remaining) revert SupplyCapExceeded(reward, remaining);

                unchecked { attendanceCount[a]++; }
                lastCheckIn[a] = block.timestamp;

                _mint(a, reward);
                emit AttendanceRecorded(a, sessionId, reward, streak, attendanceCount[a]);
            }
            unchecked { i++; }
        }
    }

     function setRecorder(address recorder, bool status) external onlyOwner {
        if (recorder == address(0)) revert ZeroAddress();
        authorizedRecorders[recorder] = status;
        emit RecorderUpdated(recorder, status);
    }

    function pause() external onlyOwner { _pause(); }
    function unpause() external onlyOwner { _unpause(); }

    function remainingSupply() external view returns (uint256) {
        return MAX_SUPPLY - totalSupply();
    }


    function previewReward(address attendee) external view returns (uint256) {
        uint256 last = lastCheckIn[attendee];
        uint256 streak = streakCount[attendee];
        if (last == 0 || block.timestamp > last + STREAK_WINDOW) streak = 0;
        return ATTENDANCE_REWARD + (streak * STREAK_BONUS);
    }

    function _updateStreak(address attendee) internal returns (uint256) {
        uint256 last = lastCheckIn[attendee];
        uint256 streak;
        if (last != 0 && block.timestamp <= last + STREAK_WINDOW) {
            unchecked { streak = streakCount[attendee] + 1; }
        } else {
            streak = 1;
        }
        streakCount[attendee] = streak;
        return streak;
    }

    function _update(address from, address to, uint256 value)
        internal override(ERC20, ERC20Pausable)
    {
        super._update(from, to, value);
    }

    function nonces(address owner)
        public view override(ERC20Permit) returns (uint256)
    {
        return super.nonces(owner);
    }

}