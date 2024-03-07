// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

contract BountyFactory {

    enum BountyState { OPEN, CLOSED, SOLVED }

    struct Bounty {
        string id;
        address issuer;
        uint256 value;
        bool valueLocked;
        BountyState state;
        string metadata;
    }

    struct Proposition {
        address solver;
        string metadata;
    }

    mapping(string bountyId => mapping(address solver => Proposition proposition)) public propositions;
    mapping(string bountyId => Bounty bounty) public bounties;
    event BountyCreated(Bounty bounty); 
    event PropositionCreated(string bountyId, Proposition proposition);
    event BountyResolved(string bountyId, address solver);
    event BountyClosed(string bountyId);
    event BountyFunded(string bountyId, uint256 value);

    error BountyAlreadyClosed(string bountyId, BountyState state);
    error NotBountyIssuer(string bountyId);
    error NotParticipant(string bountyId, address solver);
    error BountyNotFound();
    error AlreadyParticipant(address solver);
    error BountyAlreadyExists(string bountyId);
    error BountyIssuer(string bountyId, address issuer);
    error InsufficientBalance();
    error BountyAlreadyFunded(string bountyId);
    error BountyNotFunded(string bountyId);
    error FundsMismatch(string bountyId, uint256 value);

    modifier onlyIssuer(string memory bountyId) {
        if (bounties[bountyId].issuer != msg.sender) {
            revert NotBountyIssuer(bountyId);
        }
        _;
    }

    modifier bountyParticipant(string memory bountyId, address solver) {
        if (propositions[bountyId][solver].solver != solver) {
            revert NotParticipant(bountyId, solver);
        }
        _;
    }

    modifier bountyOpen(string memory bountyId) {
        if (bounties[bountyId].state != BountyState.OPEN) {
            revert BountyAlreadyClosed(bountyId, bounties[bountyId].state);
        }
        _;
    }

    modifier bountyExists(string memory bountyId) {
        if (bounties[bountyId].issuer == address(0)) {
            revert BountyNotFound();
        }
        _;
    }

    modifier notParticipant(string memory bountyId, address solver) {
        if (propositions[bountyId][msg.sender].solver == msg.sender) {
            revert AlreadyParticipant(msg.sender);
        }
        _;
    }

    modifier bountyIdAvailable(string memory bountyId) {
        if (bounties[bountyId].issuer != address(0)) {
            revert BountyAlreadyExists(bountyId);
        }
        _;
    }

    modifier notIssuer(string memory bountyId, address solver) {
        if (bounties[bountyId].issuer == msg.sender) {
            revert BountyIssuer(bountyId, msg.sender);
        }
        _;
    }

    modifier notFunded(string memory bountyId) {
        if (!bounties[bountyId].valueLocked) {
            revert BountyNotFunded(bountyId);
        }
        _;
    }

    function createBounty(
        string memory id,
        uint256 value, 
        string memory metadata
    ) 
        public 
        bountyIdAvailable(id)
    {
        Bounty memory bounty = Bounty(id, msg.sender, value, false, BountyState.OPEN, metadata);
        bounties[id] = bounty;
        emit BountyCreated(bounty);
    }

    function createBountyWithLockedValue(
        string memory id, 
        uint256 value,
        string memory metadata
    ) 
        public 
        payable 
        bountyIdAvailable(id)
    {
        if (msg.value != value) {
            revert InsufficientBalance();
        }
        Bounty memory bounty = Bounty(id, msg.sender, value, true, BountyState.OPEN, metadata);
        bounties[id] = bounty;
        emit BountyCreated(bounty);
    }

    function fundBounty(string memory bountyId) public onlyIssuer(bountyId) payable {
        if (bounties[bountyId].valueLocked == true) {
            revert BountyAlreadyFunded(bountyId);
        }
        if (bounties[bountyId].value != msg.value) {
            revert FundsMismatch(bountyId, bounties[bountyId].value);
        }
        bounties[bountyId].valueLocked = true;
        emit BountyFunded(bountyId, msg.value);
    }

    function addProposal(
        string memory bountyId, 
        string memory metadata
    ) 
        public 
        bountyExists(bountyId)
        bountyOpen(bountyId)
        notParticipant(bountyId, msg.sender) 
        notIssuer(bountyId, msg.sender)
    {
        Proposition memory proposition = Proposition(msg.sender, metadata);
        propositions[bountyId][msg.sender] = proposition;
        emit PropositionCreated(bountyId, proposition);
    }

    function markResolved(
        string memory bountyId, 
        address solver
    ) 
        public 
        bountyExists(bountyId)
        bountyOpen(bountyId)
        onlyIssuer(bountyId) 
        bountyParticipant(bountyId, solver) 
        notFunded(bountyId)
    {
        bounties[bountyId].state = BountyState.SOLVED;
        Proposition memory proposition = propositions[bountyId][solver];
        emit BountyResolved(bountyId, proposition.solver);
        payable(solver).transfer(bounties[bountyId].value);
    }

    function closeBounty(
        string memory bountyId
    ) 
        public 
        bountyExists(bountyId) 
        bountyOpen(bountyId) 
        onlyIssuer(bountyId) 
    {
        bounties[bountyId].state = BountyState.CLOSED;
        emit BountyClosed(bountyId);
        if (bounties[bountyId].valueLocked) {
            payable(msg.sender).transfer(bounties[bountyId].value);
        }
    }
}