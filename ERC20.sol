// SPDX-License-Identifier: MIT
// Intern Reward Token (IRT) — ERC-20
// Solidity ^0.8.20

pragma solidity ^0.8.20;

/**
 * @title InternRewardToken
 * @dev ERC-20 token for rewarding interns
 * Features: mintable by owner, burnable by holders,
 *           transfer restrictions, reward tiers
 */
contract InternRewardToken {

    // ── State ──────────────────────────────────
    string  public constant name     = "Intern Reward Token";
    string  public constant symbol   = "IRT";
    uint8   public constant decimals = 18;
    uint256 public maxSupply;
    uint256 public totalSupply;
    address public owner;
    bool    public paused;

    mapping(address => uint256) public balanceOf;
    mapping(address => mapping(address => uint256)) public allowance;
    mapping(address => bool)    public isIntern;
    mapping(address => uint256) public rewardTier;  // 1=Bronze 2=Silver 3=Gold

    // ── Events ─────────────────────────────────
    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(address indexed owner, address indexed spender, uint256 value);
    event InternRegistered(address indexed intern, uint256 tier);
    event RewardIssued(address indexed intern, uint256 amount, string reason);
    event Paused(bool state);

    // ── Modifiers ──────────────────────────────
    modifier onlyOwner() {
        require(msg.sender == owner, "Not owner");
        _;
    }
    modifier whenNotPaused() {
        require(!paused, "Contract paused");
        _;
    }

    // ── Constructor ────────────────────────────
    constructor(uint256 _maxSupply, uint256 _initialMint) {
        owner     = msg.sender;
        maxSupply = _maxSupply * 10 ** decimals;
        if (_initialMint > 0) {
            uint256 amt = _initialMint * 10 ** decimals;
            require(amt <= maxSupply, "Exceeds max supply");
            balanceOf[msg.sender] = amt;
            totalSupply           = amt;
            emit Transfer(address(0), msg.sender, amt);
        }
    }

    // ── ERC-20 Core ────────────────────────────
    function transfer(address to, uint256 amount)
        external whenNotPaused returns (bool)
    {
        _transfer(msg.sender, to, amount);
        return true;
    }

    function approve(address spender, uint256 amount)
        external returns (bool)
    {
        allowance[msg.sender][spender] = amount;
        emit Approval(msg.sender, spender, amount);
        return true;
    }

    function transferFrom(address from, address to, uint256 amount)
        external whenNotPaused returns (bool)
    {
        require(allowance[from][msg.sender] >= amount, "Allowance exceeded");
        allowance[from][msg.sender] -= amount;
        _transfer(from, to, amount);
        return true;
    }

    // ── Mint / Burn ────────────────────────────
    function mint(address to, uint256 amount)
        external onlyOwner whenNotPaused
    {
        require(totalSupply + amount <= maxSupply, "Max supply reached");
        balanceOf[to] += amount;
        totalSupply   += amount;
        emit Transfer(address(0), to, amount);
    }

    function burn(uint256 amount) external whenNotPaused {
        require(balanceOf[msg.sender] >= amount, "Insufficient balance");
        balanceOf[msg.sender] -= amount;
        totalSupply           -= amount;
        emit Transfer(msg.sender, address(0), amount);
    }

    // ── Intern Management ──────────────────────
    function registerIntern(address intern, uint256 tier)
        external onlyOwner
    {
        require(tier >= 1 && tier <= 3, "Tier must be 1-3");
        isIntern[intern]   = true;
        rewardTier[intern] = tier;
        emit InternRegistered(intern, tier);
    }

    function issueReward(address intern, uint256 amount, string calldata reason)
        external onlyOwner whenNotPaused
    {
        require(isIntern[intern], "Not a registered intern");
        require(totalSupply + amount <= maxSupply, "Max supply reached");
        balanceOf[intern] += amount;
        totalSupply       += amount;
        emit Transfer(address(0), intern, amount);
        emit RewardIssued(intern, amount, reason);
    }

    function batchReward(
        address[] calldata interns,
        uint256[] calldata amounts,
        string    calldata reason
    ) external onlyOwner whenNotPaused {
        require(interns.length == amounts.length, "Length mismatch");
        for (uint256 i = 0; i < interns.length; i++) {
            require(isIntern[interns[i]], "Not registered");
            require(totalSupply + amounts[i] <= maxSupply, "Max supply");
            balanceOf[interns[i]] += amounts[i];
            totalSupply           += amounts[i];
            emit Transfer(address(0), interns[i], amounts[i]);
            emit RewardIssued(interns[i], amounts[i], reason);
        }
    }

    // ── Admin ──────────────────────────────────
    function setPaused(bool _paused) external onlyOwner {
        paused = _paused;
        emit Paused(_paused);
    }

    function transferOwnership(address newOwner) external onlyOwner {
        require(newOwner != address(0), "Zero address");
        owner = newOwner;
    }

    // ── Internal ───────────────────────────────
    function _transfer(address from, address to, uint256 amount) internal {
        require(to != address(0), "Zero address");
        require(balanceOf[from] >= amount, "Insufficient balance");
        balanceOf[from] -= amount;
        balanceOf[to]   += amount;
        emit Transfer(from, to, amount);
    }
}
