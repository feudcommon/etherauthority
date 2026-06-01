// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

/**
 * @title InternshipReward
 * @dev Manages intern registration, task completion, and ETH reward distribution.
 *      Deploy this contract on Remix IDE (Ethereum / Sepolia testnet).
 *
 * REMIX DEPLOY STEPS:
 *  1. Open https://remix.ethereum.org
 *  2. Create new file → paste this contract
 *  3. Compile with Solidity 0.8.20+
 *  4. Deploy tab → Environment: "Injected Provider - MetaMask" (Sepolia)
 *  5. Fund the contract by sending ETH on deploy (Value field) or via fundContract()
 *  6. Copy the deployed contract address → paste into backend/.env
 */
contract InternshipReward {

    // ─── Types ────────────────────────────────────────────────────────────────

    struct Intern {
        address wallet;
        string  name;
        uint256 totalRewardsEarned;  // wei
        uint256 tasksCompleted;
        bool    isActive;
        bool    exists;
    }

    struct Task {
        uint256 taskId;
        string  title;
        string  description;
        uint256 rewardAmount;        // wei
        bool    isActive;
    }

    struct CompletionRecord {
        uint256 internId;
        uint256 taskId;
        uint256 timestamp;
        uint256 rewardPaid;
        bool    rewarded;
    }

    // ─── State ────────────────────────────────────────────────────────────────

    address public owner;

    uint256 private _internCounter;
    uint256 private _taskCounter;
    uint256 private _completionCounter;

    mapping(uint256 => Intern)           public interns;
    mapping(address => uint256)          public addressToInternId;  // wallet → internId
    mapping(uint256 => Task)             public tasks;
    mapping(uint256 => CompletionRecord) public completions;

    // internId → taskId → already completed?
    mapping(uint256 => mapping(uint256 => bool)) public hasCompleted;

    // ─── Events ───────────────────────────────────────────────────────────────

    event InternRegistered(uint256 indexed internId, address indexed wallet, string name);
    event InternDeactivated(uint256 indexed internId);
    event TaskCreated(uint256 indexed taskId, string title, uint256 rewardAmount);
    event TaskDeactivated(uint256 indexed taskId);
    event TaskCompleted(uint256 indexed completionId, uint256 indexed internId, uint256 indexed taskId, uint256 rewardPaid);
    event ContractFunded(address indexed by, uint256 amount);
    event OwnerWithdraw(uint256 amount);

    // ─── Modifiers ────────────────────────────────────────────────────────────

    modifier onlyOwner() {
        require(msg.sender == owner, "Not owner");
        _;
    }

    modifier internExists(uint256 internId) {
        require(interns[internId].exists, "Intern not found");
        _;
    }

    modifier taskActive(uint256 taskId) {
        require(tasks[taskId].isActive, "Task not active");
        _;
    }

    // ─── Constructor ──────────────────────────────────────────────────────────

    constructor() payable {
        owner = msg.sender;
        // Seed counters from 1 so 0 is an invalid ID
        _internCounter     = 1;
        _taskCounter       = 1;
        _completionCounter = 1;
    }

    // ─── Funding ──────────────────────────────────────────────────────────────

    /// @notice Send ETH to the contract so it can pay out rewards.
    receive() external payable {
        emit ContractFunded(msg.sender, msg.value);
    }

    function fundContract() external payable {
        require(msg.value > 0, "Send some ETH");
        emit ContractFunded(msg.sender, msg.value);
    }

    function getContractBalance() external view returns (uint256) {
        return address(this).balance;
    }

    // ─── Intern Management ────────────────────────────────────────────────────

    /// @notice Register a new intern. Can be called by owner or the intern themselves.
    function registerIntern(address wallet, string calldata name)
        external
        onlyOwner
        returns (uint256 internId)
    {
        require(wallet != address(0), "Zero address");
        require(bytes(name).length > 0, "Name required");
        require(addressToInternId[wallet] == 0, "Already registered");

        internId = _internCounter++;
        interns[internId] = Intern({
            wallet:             wallet,
            name:               name,
            totalRewardsEarned: 0,
            tasksCompleted:     0,
            isActive:           true,
            exists:             true
        });
        addressToInternId[wallet] = internId;

        emit InternRegistered(internId, wallet, name);
    }

    function deactivateIntern(uint256 internId)
        external
        onlyOwner
        internExists(internId)
    {
        interns[internId].isActive = false;
        emit InternDeactivated(internId);
    }

    function getIntern(uint256 internId)
        external
        view
        internExists(internId)
        returns (Intern memory)
    {
        return interns[internId];
    }

    function getInternByAddress(address wallet)
        external
        view
        returns (Intern memory)
    {
        uint256 id = addressToInternId[wallet];
        require(id != 0, "Not registered");
        return interns[id];
    }

    function getTotalInterns() external view returns (uint256) {
        return _internCounter - 1;
    }

    // ─── Task Management ──────────────────────────────────────────────────────

    /// @notice Create a reward task. rewardAmount is in wei.
    function createTask(
        string calldata title,
        string calldata description,
        uint256 rewardAmount
    )
        external
        onlyOwner
        returns (uint256 taskId)
    {
        require(bytes(title).length > 0, "Title required");
        require(rewardAmount > 0, "Reward must be > 0");

        taskId = _taskCounter++;
        tasks[taskId] = Task({
            taskId:       taskId,
            title:        title,
            description:  description,
            rewardAmount: rewardAmount,
            isActive:     true
        });

        emit TaskCreated(taskId, title, rewardAmount);
    }

    function deactivateTask(uint256 taskId) external onlyOwner taskActive(taskId) {
        tasks[taskId].isActive = false;
        emit TaskDeactivated(taskId);
    }

    function getTask(uint256 taskId) external view returns (Task memory) {
        require(tasks[taskId].rewardAmount > 0, "Task not found");
        return tasks[taskId];
    }

    function getTotalTasks() external view returns (uint256) {
        return _taskCounter - 1;
    }

    // ─── Reward Distribution ──────────────────────────────────────────────────

    /**
     * @notice Mark a task as completed by an intern and pay out the reward.
     * @dev Called by the owner (backend relayer wallet). Intern cannot call this.
     */
    function completeTaskAndReward(uint256 internId, uint256 taskId)
        external
        onlyOwner
        internExists(internId)
        taskActive(taskId)
        returns (uint256 completionId)
    {
        Intern storage intern = interns[internId];
        require(intern.isActive, "Intern not active");
        require(!hasCompleted[internId][taskId], "Already completed");

        Task storage task = tasks[taskId];
        uint256 reward    = task.rewardAmount;

        require(address(this).balance >= reward, "Insufficient contract balance");

        // Update state before transfer (checks-effects-interactions)
        hasCompleted[internId][taskId]   = true;
        intern.totalRewardsEarned       += reward;
        intern.tasksCompleted           += 1;

        completionId = _completionCounter++;
        completions[completionId] = CompletionRecord({
            internId:   internId,
            taskId:     taskId,
            timestamp:  block.timestamp,
            rewardPaid: reward,
            rewarded:   true
        });

        // Transfer reward to intern's wallet
        (bool success, ) = payable(intern.wallet).call{value: reward}("");
        require(success, "Transfer failed");

        emit TaskCompleted(completionId, internId, taskId, reward);
    }

    /// @notice Check if an intern has completed a specific task.
    function checkCompletion(uint256 internId, uint256 taskId)
        external
        view
        returns (bool)
    {
        return hasCompleted[internId][taskId];
    }

    function getCompletion(uint256 completionId)
        external
        view
        returns (CompletionRecord memory)
    {
        require(completions[completionId].timestamp > 0, "Record not found");
        return completions[completionId];
    }

    function getTotalCompletions() external view returns (uint256) {
        return _completionCounter - 1;
    }

    // ─── Owner Withdraw ───────────────────────────────────────────────────────

    function withdrawAll() external onlyOwner {
        uint256 bal = address(this).balance;
        require(bal > 0, "Nothing to withdraw");
        (bool ok, ) = payable(owner).call{value: bal}("");
        require(ok, "Withdraw failed");
        emit OwnerWithdraw(bal);
    }

    function transferOwnership(address newOwner) external onlyOwner {
        require(newOwner != address(0), "Zero address");
        owner = newOwner;
    }
}
