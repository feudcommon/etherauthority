// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

contract InternshipTracker {

    error NotOwner();
    error NotIntern(address caller);
    error AlreadyIntern(address intern);
    error InternNotFound(address intern);
    error TaskNotFound(uint256 taskId);
    error NotAssignedToYou(uint256 taskId);
    error TaskAlreadyCompleted(uint256 taskId);
    error EmptyField();
    error InvalidStatus();

    enum Status {
        Pending,      // 0 — not started
        InProgress,   // 1 — actively working
        UnderReview,  // 2 — submitted, awaiting mentor review
        Completed,    // 3 — approved and done
        Rejected      // 4 — sent back for rework
    }

    enum Priority {
        Low,          // 0
        Medium,       // 1
        High          // 2
    }

    struct Task {
        uint256   id;
        string    title;
        string    description;
        address   assignedTo;
        Status    status;
        Priority  priority;
        uint256   createdAt;
        uint256   updatedAt;
        string    remarks;       // mentor or intern notes on last update
    }

    struct Intern {
        address wallet;
        string  name;
        bool    isActive;
        uint256[] taskIds;
    }

    address public owner;
    uint256 private taskCounter;

    mapping(uint256 => Task)    public tasks;
    mapping(address => Intern)  public interns;
    address[] public internList;


    event InternAdded(address indexed intern, string name);
    event InternRemoved(address indexed intern);
    event TaskCreated(uint256 indexed taskId, address indexed assignedTo, string title);
    event TaskStatusUpdated(uint256 indexed taskId, address indexed updatedBy, Status oldStatus, Status newStatus);
    event TaskReassigned(uint256 indexed taskId, address indexed from, address indexed to);
    event RemarksAdded(uint256 indexed taskId, string remarks);

    // ─────────────────────────────────────────────
    //  Modifiers
    // ─────────────────────────────────────────────

    modifier onlyOwner() {
        if (msg.sender != owner) revert NotOwner();
        _;
    }

    modifier onlyIntern() {
        if (!interns[msg.sender].isActive) revert NotIntern(msg.sender);
        _;
    }

    modifier taskExists(uint256 _taskId) {
        if (_taskId == 0 || _taskId > taskCounter) revert TaskNotFound(_taskId);
        _;
    }

    // ─────────────────────────────────────────────
    //  Constructor
    // ─────────────────────────────────────────────

    constructor() {
        owner = msg.sender;
    }

    // ─────────────────────────────────────────────
    //  Intern Management  (owner only)
    // ─────────────────────────────────────────────

    /**
     * @notice Register a new intern
     */
    function addIntern(address _wallet, string calldata _name) external onlyOwner {
        if (interns[_wallet].isActive) revert AlreadyIntern(_wallet);
        if (bytes(_name).length == 0)  revert EmptyField();

        uint256[] memory empty;
        interns[_wallet] = Intern({
            wallet:  _wallet,
            name:    _name,
            isActive: true,
            taskIds: empty
        });
        internList.push(_wallet);

        emit InternAdded(_wallet, _name);
    }

    /**
     * @notice Deactivate an intern (keeps their task history)
     */
    function removeIntern(address _wallet) external onlyOwner {
        if (!interns[_wallet].isActive) revert InternNotFound(_wallet);
        interns[_wallet].isActive = false;
        emit InternRemoved(_wallet);
    }

    // ─────────────────────────────────────────────
    //  Task Management  (owner only)
    // ─────────────────────────────────────────────

    /**
     * @notice Create and assign a task to an intern
     */
    function createTask(
        address         _intern,
        string calldata _title,
        string calldata _description,
        Priority        _priority
    ) external onlyOwner {
        if (!interns[_intern].isActive) revert InternNotFound(_intern);
        if (bytes(_title).length == 0)  revert EmptyField();

        taskCounter++;
        uint256 tid = taskCounter;

        tasks[tid] = Task({
            id:          tid,
            title:       _title,
            description: _description,
            assignedTo:  _intern,
            status:      Status.Pending,
            priority:    _priority,
            createdAt:   block.timestamp,
            updatedAt:   block.timestamp,
            remarks:     ""
        });

        interns[_intern].taskIds.push(tid);

        emit TaskCreated(tid, _intern, _title);
    }

    /**
     * @notice Reassign a task to a different intern
     */
    function reassignTask(uint256 _taskId, address _newIntern)
        external
        onlyOwner
        taskExists(_taskId)
    {
        if (!interns[_newIntern].isActive) revert InternNotFound(_newIntern);

        Task storage t = tasks[_taskId];
        address oldIntern = t.assignedTo;

        // Remove taskId from old intern's list
        uint256[] storage oldTasks = interns[oldIntern].taskIds;
        for (uint256 i = 0; i < oldTasks.length; i++) {
            if (oldTasks[i] == _taskId) {
                oldTasks[i] = oldTasks[oldTasks.length - 1];
                oldTasks.pop();
                break;
            }
        }

        t.assignedTo = _newIntern;
        t.updatedAt  = block.timestamp;
        interns[_newIntern].taskIds.push(_taskId);

        emit TaskReassigned(_taskId, oldIntern, _newIntern);
    }

    /**
     * @notice Owner can set any status + add remarks (e.g. Completed or Rejected)
     */
    function reviewTask(
        uint256         _taskId,
        Status          _newStatus,
        string calldata _remarks
    ) external onlyOwner taskExists(_taskId) {
        Task storage t = tasks[_taskId];
        Status old = t.status;

        t.status    = _newStatus;
        t.updatedAt = block.timestamp;
        t.remarks   = _remarks;

        emit TaskStatusUpdated(_taskId, msg.sender, old, _newStatus);
        emit RemarksAdded(_taskId, _remarks);
    }

    // ─────────────────────────────────────────────
    //  Intern Actions
    // ─────────────────────────────────────────────

    /**
     * @notice Intern updates the status of their own task
     *         Allowed transitions: Pending → InProgress → UnderReview
     *         (Owner handles Completed / Rejected via reviewTask)
     */
    function updateTaskStatus(
        uint256         _taskId,
        Status          _newStatus,
        string calldata _remarks
    ) external onlyIntern taskExists(_taskId) {
        Task storage t = tasks[_taskId];

        if (t.assignedTo != msg.sender)         revert NotAssignedToYou(_taskId);
        if (t.status == Status.Completed)        revert TaskAlreadyCompleted(_taskId);

        // Interns may only move to InProgress or UnderReview
        if (_newStatus != Status.InProgress && _newStatus != Status.UnderReview)
            revert InvalidStatus();

        Status old  = t.status;
        t.status    = _newStatus;
        t.updatedAt = block.timestamp;
        t.remarks   = _remarks;

        emit TaskStatusUpdated(_taskId, msg.sender, old, _newStatus);
        if (bytes(_remarks).length > 0) emit RemarksAdded(_taskId, _remarks);
    }

    // ─────────────────────────────────────────────
    //  View Functions
    // ─────────────────────────────────────────────

    /// @notice Full details of a single task
    function getTask(uint256 _taskId)
        external
        view
        taskExists(_taskId)
        returns (Task memory)
    {
        return tasks[_taskId];
    }

    /// @notice All task IDs assigned to an intern
    function getInternTaskIds(address _intern)
        external
        view
        returns (uint256[] memory)
    {
        return interns[_intern].taskIds;
    }

    /// @notice All tasks for an intern (full structs)
    function getInternTasks(address _intern)
        external
        view
        returns (Task[] memory)
    {
        uint256[] storage ids = interns[_intern].taskIds;
        Task[] memory result  = new Task[](ids.length);
        for (uint256 i = 0; i < ids.length; i++) {
            result[i] = tasks[ids[i]];
        }
        return result;
    }

    /// @notice All registered intern addresses
    function getInternList() external view returns (address[] memory) {
        return internList;
    }

    /// @notice Total tasks created so far
    function totalTasks() external view returns (uint256) {
        return taskCounter;
    }

    /// @notice Get status label as a string (helper for frontends)
    function statusLabel(uint256 _taskId)
        external
        view
        taskExists(_taskId)
        returns (string memory)
    {
        Status s = tasks[_taskId].status;
        if (s == Status.Pending)     return "Pending";
        if (s == Status.InProgress)  return "In Progress";
        if (s == Status.UnderReview) return "Under Review";
        if (s == Status.Completed)   return "Completed";
        return "Rejected";
    }
}
