// SPDX-License-Identifier : MIT
pragma solidity ^0.8.19;

contract votingsystem{

    error notOwner();
    error notRegistered(address voter);
    error alreadyVoted(address voter);
    error VotingOpen();
    error VotingClosed();
    error AlreadyRegistered(address voter);
    error InvalidProposal(uint256 id);
    error EmptyName();
    error NoProposal();
    
    struct proposal{
        uint256 id;
        string name;
        uint256 voteCount;
    }
    struct voter{
        uint256 id;
        bool isRegistered;
        bool hasVoted;
    }
    address public owner;
    uint256 public totalVotes;
    bool public votingOpen;
    mapping(address => voter) voters;
    proposal[] public proposals;

    event proposalAdded(uint256 indexed id,string name);
    event VotingRegistered(address indexed voter);
    event VotingStarted();
    event VotingEnded();
    event Voted(address indexed voter, uint256 indexed proposalid);

    modifier onlyOwner(){
        if(msg.sender != owner) revert notOwner();
        _;
    }

    modifier whenOpen(){
        if (!votingOpen) revert VotingClosed();
        _;
    }

    modifier whenClosed(){
        if(votingOpen) revert VotingOpen();
        _;
    }
    
    constructor(){
        owner=msg.sender;
    }

    function addProposal(string calldata _name)
    external
    onlyOwner
    whenClosed{
        if(bytes(_name).length==0) revert EmptyName();
        uint256 id=proposals.length;
        proposals.push(proposal({id : id, name : _name, voteCount : 0 }));
        emit proposalAdded(id,_name);
    }

    function registerVoter(address[] calldata _voters)
    external
    onlyOwner
    whenClosed{
        /*
        if (voters[_voter].isRegistered) revert AlreadyRegistered();
        voters[_voter].isRegistered=true;
        emit VotingRegistered(_voter);
        */
        for(uint256 i = 0;i < _voters.length;i++){
            address v = _voters[i];
            if(voters[v].isRegistered) revert AlreadyRegistered(v);
            voters[v].isRegistered=true;
            emit VotingRegistered(v);
        }
    }

    function startVoting()
    external
    onlyOwner
    whenClosed{
        if(proposals.length==0) revert NoProposal();
        votingOpen= true;
        emit VotingStarted();
    }

    function endVoting()
    external onlyOwner
    whenOpen{
        votingOpen=false;
        emit VotingEnded();
    }

    function castVote(uint256 proposalId)
    external
    whenOpen{
        voter storage v = voters[msg.sender];
        if(!v.isRegistered) revert notRegistered(msg.sender);
        if(v.hasVoted) revert alreadyVoted(msg.sender);
        if(proposalId >= proposals.length) revert InvalidProposal(proposalId);
        v.hasVoted=true;
        proposals[proposalId].voteCount++;
        totalVotes++;
        emit Voted(msg.sender,proposalId);
    }

    function getProposals()
    external 
    view returns (proposal[] memory){
        return proposals;
    }

    function getProposal(uint256 _id)
    external
    view returns (string memory name,uint256 voteCount){
        if(_id>=proposals.length) revert InvalidProposal(_id);
        proposal storage p = proposals[_id];
        return (p.name,p.voteCount);
    }
    
    function winner()
    external
    whenClosed
    view returns(uint256 winnerId,string memory winnerName,uint256 winnerCount){
        uint256 max;
        if(proposals.length==0) revert NoProposal();
        for(uint256 i=0;i<proposals.length;i++){
            if(proposals[i].voteCount>max){
                max=proposals[i].voteCount;
                winnerId=proposals[i].id;
                winnerName=proposals[i].name;
                winnerCount=proposals[i].voteCount;
            }
        }
    }
}
