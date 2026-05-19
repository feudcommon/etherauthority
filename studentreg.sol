// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

/**
 * @title StudentRegistration
 * @dev A contract to manage student registration, courses, and enrollment
 */
contract StudentRegistration {

    // ─────────────────────────────────────────────
    //  Structs
    // ─────────────────────────────────────────────

    struct Student {
        uint256 id;
        string  name;
        string  email;
        uint256 age;
        bool    isRegistered;
        uint256 registeredAt;
        uint256[] enrolledCourses;
    }

    struct Course {
        uint256 id;
        string  name;
        string  description;
        uint256 maxCapacity;
        uint256 enrolledCount;
        bool    isActive;
        uint256 fee;         // in wei
    }

    // ─────────────────────────────────────────────
    //  State Variables
    // ─────────────────────────────────────────────

    address public owner;
    uint256 private studentCounter;
    uint256 private courseCounter;

    mapping(address => Student)          public students;
    mapping(uint256 => address)          public studentIdToAddress;
    mapping(uint256 => Course)           public courses;
    // studentId => courseId => enrolled
    mapping(uint256 => mapping(uint256 => bool)) public enrollments;

    uint256[] public allCourseIds;

    event StudentRegistered(address indexed studentAddress, uint256 studentId, string name);
    event StudentUpdated(address indexed studentAddress, string name);
    event StudentDeregistered(address indexed studentAddress, uint256 studentId);
    event CourseAdded(uint256 indexed courseId, string name, uint256 fee);
    event CourseUpdated(uint256 indexed courseId, string name);
    event CourseDeactivated(uint256 indexed courseId);
    event StudentEnrolled(uint256 indexed studentId, uint256 indexed courseId);
    event StudentUnenrolled(uint256 indexed studentId, uint256 indexed courseId);
    event FundsWithdrawn(address indexed owner, uint256 amount);

    modifier onlyOwner() {
        require(msg.sender == owner, "StudentRegistration: caller is not owner");
        _;
    }

    modifier onlyRegistered() {
        require(students[msg.sender].isRegistered, "StudentRegistration: student not registered");
        _;
    }

    modifier courseExists(uint256 _courseId) {
        require(_courseId > 0 && _courseId <= courseCounter, "StudentRegistration: course does not exist");
        _;
    }

    modifier courseActive(uint256 _courseId) {
        require(courses[_courseId].isActive, "StudentRegistration: course is not active");
        _;
    }

    constructor() {
        owner = msg.sender;
    }
    /**
     * @notice Register a new student
     * @param _name  Full name of the student
     * @param _email Email address of the student
     * @param _age   Age of the student
     */
    function registerStudent(
        string calldata _name,
        string calldata _email,
        uint256 _age
    ) external {
        require(!students[msg.sender].isRegistered, "StudentRegistration: already registered");
        require(bytes(_name).length > 0,  "StudentRegistration: name cannot be empty");
        require(bytes(_email).length > 0, "StudentRegistration: email cannot be empty");
        require(_age >= 16 && _age <= 100, "StudentRegistration: invalid age (16-100)");

        studentCounter++;
        uint256 newId = studentCounter;

        uint256[] memory empty;
        students[msg.sender] = Student({
            id:              newId,
            name:            _name,
            email:           _email,
            age:             _age,
            isRegistered:    true,
            registeredAt:    block.timestamp,
            enrolledCourses: empty
        });

        studentIdToAddress[newId] = msg.sender;

        emit StudentRegistered(msg.sender, newId, _name);
    }

    /**
     * @notice Update student profile (own only)
     */
    function updateStudent(
        string calldata _name,
        string calldata _email,
        uint256 _age
    ) external onlyRegistered {
        require(bytes(_name).length > 0,  "StudentRegistration: name cannot be empty");
        require(bytes(_email).length > 0, "StudentRegistration: email cannot be empty");
        require(_age >= 16 && _age <= 100, "StudentRegistration: invalid age (16-100)");

        Student storage s = students[msg.sender];
        s.name  = _name;
        s.email = _email;
        s.age   = _age;

        emit StudentUpdated(msg.sender, _name);
    }

    /**
     * @notice Deregister (remove) own student account
     *         Student must not be enrolled in any active course
     */
    function deregisterStudent() external onlyRegistered {
        Student storage s = students[msg.sender];
        require(s.enrolledCourses.length == 0, "StudentRegistration: unenroll from all courses first");

        uint256 sid = s.id;
        delete studentIdToAddress[sid];
        delete students[msg.sender];

        emit StudentDeregistered(msg.sender, sid);
    }

    // ─────────────────────────────────────────────
    //  Course Management (Owner)
    // ─────────────────────────────────────────────

    /**
     * @notice Add a new course (owner only)
     */
    function addCourse(
        string calldata _name,
        string calldata _description,
        uint256 _maxCapacity,
        uint256 _feeInWei
    ) external onlyOwner {
        require(bytes(_name).length > 0, "StudentRegistration: course name empty");
        require(_maxCapacity > 0,        "StudentRegistration: capacity must be > 0");

        courseCounter++;
        uint256 cid = courseCounter;

        courses[cid] = Course({
            id:            cid,
            name:          _name,
            description:   _description,
            maxCapacity:   _maxCapacity,
            enrolledCount: 0,
            isActive:      true,
            fee:           _feeInWei
        });

        allCourseIds.push(cid);

        emit CourseAdded(cid, _name, _feeInWei);
    }

    /**
     * @notice Update an existing course (owner only)
     */
    function updateCourse(
        uint256 _courseId,
        string calldata _name,
        string calldata _description,
        uint256 _maxCapacity,
        uint256 _feeInWei
    ) external onlyOwner courseExists(_courseId) {
        Course storage c = courses[_courseId];
        require(_maxCapacity >= c.enrolledCount, "StudentRegistration: capacity below current enrollment");

        c.name        = _name;
        c.description = _description;
        c.maxCapacity = _maxCapacity;
        c.fee         = _feeInWei;

        emit CourseUpdated(_courseId, _name);
    }

    /**
     * @notice Deactivate a course (owner only)
     */
    function deactivateCourse(uint256 _courseId)
        external
        onlyOwner
        courseExists(_courseId)
    {
        courses[_courseId].isActive = false;
        emit CourseDeactivated(_courseId);
    }

    // ─────────────────────────────────────────────
    //  Enrollment Functions
    // ─────────────────────────────────────────────

    /**
     * @notice Enroll the calling student into a course
     *         Requires sending the exact course fee
     */
    function enrollInCourse(uint256 _courseId)
        external
        payable
        onlyRegistered
        courseExists(_courseId)
        courseActive(_courseId)
    {
        Student storage s = students[msg.sender];
        Course  storage c = courses[_courseId];

        require(!enrollments[s.id][_courseId],     "StudentRegistration: already enrolled");
        require(c.enrolledCount < c.maxCapacity,   "StudentRegistration: course is full");
        require(msg.value == c.fee,                "StudentRegistration: incorrect fee sent");

        enrollments[s.id][_courseId] = true;
        s.enrolledCourses.push(_courseId);
        c.enrolledCount++;

        emit StudentEnrolled(s.id, _courseId);
    }

    /**
     * @notice Unenroll from a course (no refund policy in this basic version)
     */
    function unenrollFromCourse(uint256 _courseId)
        external
        onlyRegistered
        courseExists(_courseId)
    {
        Student storage s = students[msg.sender];
        require(enrollments[s.id][_courseId], "StudentRegistration: not enrolled in this course");

        enrollments[s.id][_courseId] = false;
        courses[_courseId].enrolledCount--;

        // Remove courseId from enrolledCourses array
        uint256[] storage ec = s.enrolledCourses;
        for (uint256 i = 0; i < ec.length; i++) {
            if (ec[i] == _courseId) {
                ec[i] = ec[ec.length - 1];
                ec.pop();
                break;
            }
        }

        emit StudentUnenrolled(s.id, _courseId);
    }

    // ─────────────────────────────────────────────
    //  View / Query Functions
    // ─────────────────────────────────────────────

    /// @notice Get the student profile for any address
    function getStudent(address _addr)
        external
        view
        returns (
            uint256 id,
            string memory name,
            string memory email,
            uint256 age,
            bool isRegistered,
            uint256 registeredAt,
            uint256[] memory enrolledCourses
        )
    {
        Student storage s = students[_addr];
        return (s.id, s.name, s.email, s.age, s.isRegistered, s.registeredAt, s.enrolledCourses);
    }

    /// @notice Get the details of a course
    function getCourse(uint256 _courseId)
        external
        view
        courseExists(_courseId)
        returns (
            uint256 id,
            string memory name,
            string memory description,
            uint256 maxCapacity,
            uint256 enrolledCount,
            bool isActive,
            uint256 fee
        )
    {
        Course storage c = courses[_courseId];
        return (c.id, c.name, c.description, c.maxCapacity, c.enrolledCount, c.isActive, c.fee);
    }

    /// @notice Returns all course IDs ever created
    function getAllCourseIds() external view returns (uint256[] memory) {
        return allCourseIds;
    }

    /// @notice Check if a student (by address) is enrolled in a course
    function isEnrolled(address _studentAddr, uint256 _courseId)
        external
        view
        returns (bool)
    {
        uint256 sid = students[_studentAddr].id;
        return enrollments[sid][_courseId];
    }

    /// @notice Total number of registered students (ever)
    function totalStudents() external view returns (uint256) {
        return studentCounter;
    }

    /// @notice Total number of courses created
    function totalCourses() external view returns (uint256) {
        return courseCounter;
    }

    // ─────────────────────────────────────────────
    //  Financial
    // ─────────────────────────────────────────────

    /// @notice Withdraw all collected fees (owner only)
    function withdrawFunds() external onlyOwner {
        uint256 bal = address(this).balance;
        require(bal > 0, "StudentRegistration: nothing to withdraw");
        (bool ok, ) = owner.call{value: bal}("");
        require(ok, "StudentRegistration: transfer failed");
        emit FundsWithdrawn(owner, bal);
    }

    /// @notice Transfer ownership
    function transferOwnership(address _newOwner) external onlyOwner {
        require(_newOwner != address(0), "StudentRegistration: zero address");
        owner = _newOwner;
    }

    /// @notice Contract balance
    function contractBalance() external view returns (uint256) {
        return address(this).balance;
    }

    // Reject plain ETH sends that aren't enrollments
    receive() external payable {
        revert("StudentRegistration: use enrollInCourse()");
    }
}
