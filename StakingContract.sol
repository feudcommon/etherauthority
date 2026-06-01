// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

contract StakingContract {

    // ── State variables ──────────────────────────────────────────────────────

    address public owner;
    uint256 public apyBasisPoints = 1200;      // 12% APY (1200 / 10000)
    uint256 public lockPeriod = 30 days;
    uint256 public minStakeAmount = 1 ether;   // 1 SCAI minimum
    uint256 public emergencyPenaltyBps = 1000; // 10% early-exit penalty
    uint256 public totalStaked;

    // ── Stake position (one per stake() call) ────────────────────────────────

    struct StakeInfo {
        uint256 amount;      // SCAI deposited
        uint256 stakedAt;    // Timestamp of deposit
        uint256 lockUntil;   // Earliest normal-exit timestamp
        uint256 rewardDebt;  // Rewards already claimed mid-lock
        bool    active;      // False once unstaked
    }

    mapping(address => StakeInfo[]) private _stakes;

    // ── Events ───────────────────────────────────────────────────────────────

    event Staked(address indexed user, uint256 indexed positionId,
                 uint256 amount, uint256 lockUntil);
    event Unstaked(address indexed user, uint256 indexed positionId,
                   uint256 principal, uint256 reward);
    event EmergencyWithdraw(address indexed user, uint256 indexed positionId,
                            uint256 returned, uint256 penalty);
    event RewardsClaimed(address indexed user, uint256 indexed positionId,
                         uint256 reward);
    event RewardPoolFunded(address indexed funder, uint256 amount);
    event APYUpdated(uint256 oldApyBps, uint256 newApyBps);
    event LockPeriodUpdated(uint256 oldPeriod, uint256 newPeriod);
    event MinStakeUpdated(uint256 oldMin, uint256 newMin);
    event OwnershipTransferred(address indexed previousOwner,
                               address indexed newOwner);

    // ── Modifiers ────────────────────────────────────────────────────────────

    modifier onlyOwner() {
        require(msg.sender == owner, "Staking: caller is not owner");
        _;
    }

    modifier validPosition(address user, uint256 posId) {
        require(posId < _stakes[user].length, "Staking: invalid position");
        require(_stakes[user][posId].active,  "Staking: position not active");
        _;
    }

    // ── Constructor ──────────────────────────────────────────────────────────

    constructor() payable {
        owner = msg.sender;
        if (msg.value > 0) emit RewardPoolFunded(msg.sender, msg.value);
    }

    // ── Core staking functions ───────────────────────────────────────────────

    /// @notice Deposit SCAI. Creates a new position. Returns positionId.
    function stake() external payable returns (uint256 positionId) {
        require(msg.value >= minStakeAmount, "Staking: below minimum stake");

        uint256 lockUntil = block.timestamp + lockPeriod;
        positionId = _stakes[msg.sender].length;

        _stakes[msg.sender].push(StakeInfo({
            amount:     msg.value,
            stakedAt:   block.timestamp,
            lockUntil:  lockUntil,
            rewardDebt: 0,
            active:     true
        }));

        totalStaked += msg.value;
        emit Staked(msg.sender, positionId, msg.value, lockUntil);
    }

    /// @notice Withdraw principal + rewards after lock period ends.
    function unstake(uint256 positionId)
        external validPosition(msg.sender, positionId)
    {
        StakeInfo storage pos = _stakes[msg.sender][positionId];
        require(block.timestamp >= pos.lockUntil, "Staking: still locked");

        uint256 principal = pos.amount;
        uint256 reward    = _pendingReward(pos);
        uint256 totalOut  = principal + reward;

        require(address(this).balance >= totalOut,
                "Staking: insufficient reward pool");

        pos.active   = false;
        totalStaked -= principal;

        _safeTransfer(msg.sender, totalOut);
        emit Unstaked(msg.sender, positionId, principal, reward);
    }

    /// @notice Collect accrued rewards without touching principal.
    function claimRewards(uint256 positionId)
        external validPosition(msg.sender, positionId)
    {
        StakeInfo storage pos = _stakes[msg.sender][positionId];
        uint256 reward = _pendingReward(pos);
        require(reward > 0, "Staking: no rewards yet");
        require(address(this).balance >= reward,
                "Staking: insufficient reward pool");

        pos.rewardDebt += reward;   // mark as paid
        _safeTransfer(msg.sender, reward);
        emit RewardsClaimed(msg.sender, positionId, reward);
    }

    /// @notice Exit before lock ends — 10% penalty on principal, rewards lost.
    function emergencyWithdraw(uint256 positionId)
        external validPosition(msg.sender, positionId)
    {
        StakeInfo storage pos = _stakes[msg.sender][positionId];
        require(block.timestamp < pos.lockUntil,
                "Staking: lock expired, use unstake");

        uint256 principal = pos.amount;
        uint256 penalty   = (principal * emergencyPenaltyBps) / 10_000;
        uint256 returned  = principal - penalty;

        pos.active   = false;
        totalStaked -= principal;

        _safeTransfer(msg.sender, returned);
        emit EmergencyWithdraw(msg.sender, positionId, returned, penalty);
    }

    // ── View helpers ─────────────────────────────────────────────────────────

    function getPositions(address user)
        external view returns (StakeInfo[] memory)
    { return _stakes[user]; }

    function pendingReward(address user, uint256 positionId)
        external view returns (uint256)
    {
        require(positionId < _stakes[user].length, "Staking: invalid position");
        StakeInfo storage pos = _stakes[user][positionId];
        return pos.active ? _pendingReward(pos) : 0;
    }

    function rewardPool() external view returns (uint256) {
        uint256 bal = address(this).balance;
        return bal > totalStaked ? bal - totalStaked : 0;
    }

    function positionCount(address user) external view returns (uint256)
    { return _stakes[user].length; }

    // ── Owner functions ──────────────────────────────────────────────────────

    function fundRewardPool() external payable onlyOwner {
        require(msg.value > 0, "Staking: send SCAI to fund");
        emit RewardPoolFunded(msg.sender, msg.value);
    }

    receive() external payable {
        emit RewardPoolFunded(msg.sender, msg.value);
    }

    function setAPY(uint256 newApyBps) external onlyOwner {
        require(newApyBps <= 50_000, "Staking: APY too high (max 500%)");
        emit APYUpdated(apyBasisPoints, newApyBps);
        apyBasisPoints = newApyBps;
    }

    function setLockPeriod(uint256 newLockPeriod) external onlyOwner {
        require(newLockPeriod <= 365 days, "Staking: lock too long");
        emit LockPeriodUpdated(lockPeriod, newLockPeriod);
        lockPeriod = newLockPeriod;
    }

    function setMinStakeAmount(uint256 newMin) external onlyOwner {
        emit MinStakeUpdated(minStakeAmount, newMin);
        minStakeAmount = newMin;
    }

    function setEmergencyPenalty(uint256 penaltyBps) external onlyOwner {
        require(penaltyBps <= 3000, "Staking: penalty too high");
        emergencyPenaltyBps = penaltyBps;
    }

    function transferOwnership(address newOwner) external onlyOwner {
        require(newOwner != address(0), "Staking: zero address");
        emit OwnershipTransferred(owner, newOwner);
        owner = newOwner;
    }

    function withdrawExcess(uint256 amount) external onlyOwner {
        uint256 excess = address(this).balance > totalStaked
            ? address(this).balance - totalStaked : 0;
        require(amount <= excess, "Staking: would drain staker funds");
        _safeTransfer(owner, amount);
    }

    // ── Internal helpers ─────────────────────────────────────────────────────

    // reward = principal × APY × elapsed_seconds / (365 days × 10000)
    function _pendingReward(StakeInfo storage pos)
        internal view returns (uint256)
    {
        uint256 elapsed = block.timestamp - pos.stakedAt;
        uint256 gross   = (pos.amount * apyBasisPoints * elapsed)
                          / (365 days * 10_000);
        return gross > pos.rewardDebt ? gross - pos.rewardDebt : 0;
    }

    function _safeTransfer(address to, uint256 amount) internal {
        (bool ok, ) = payable(to).call{value: amount}("");
        require(ok, "Staking: transfer failed");
    }
}