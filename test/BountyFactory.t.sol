// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.24;

import {Test, console} from "forge-std/Test.sol";
import {BountyFactory} from "../src/BountyFactory.sol";


contract BountyFactoryTest is Test {


    BountyFactory public bountyFactory;

    function setUp() public {
        bountyFactory = new BountyFactory();
    }

    function test_CreateBounty() public {
        vm.startPrank(address(1));
        BountyFactory.Bounty memory bounty = BountyFactory.Bounty(
            "1", address(1), 1 ether, false, BountyFactory.BountyState.OPEN, "metadata"
        );
        vm.expectEmit(true, true, true, true);
        emit BountyFactory.BountyCreated(bounty);
        bountyFactory.createBounty("1", 1 ether, "metadata");
    }

    function test_CannotUseSameIdTwice() public {
        bountyFactory.createBounty("1", 100, "metadata");
        vm.expectRevert(abi.encodeWithSelector(BountyFactory.BountyAlreadyExists.selector, "1"));
        bountyFactory.createBounty("1", 100, "metadata");
    }

    function test_IssuerCannotLockValueWithBalanceLessThanValue() public {
        vm.startPrank(address(1));
        assert(address(1).balance == 0);
        vm.expectRevert(abi.encodeWithSelector(BountyFactory.InsufficientBalance.selector));
        bountyFactory.createBountyWithLockedValue{value: 0 ether}("1", 1 ether, "metadata");

        vm.deal(address(1), 10 ether);
        assert(address(1).balance == 10 ether);
        vm.expectRevert(abi.encodeWithSelector(BountyFactory.InsufficientBalance.selector));
        bountyFactory.createBountyWithLockedValue{value: 10 ether}("1", 100 ether, "metadata");

        vm.expectRevert();
        bountyFactory.createBountyWithLockedValue{value: 1000 ether}("1", 1000 ether, "metadata");
    }

    function test_IssuerCanAddFunds() public {
        vm.startPrank(address(1));
        vm.deal(address(1), 1 ether);
        bountyFactory.createBounty("1", 1 ether, "metadata");
        vm.expectEmit(true, true, true, true);
        emit BountyFactory.BountyFunded("1", 1 ether);
        bountyFactory.fundBounty{value: 1 ether}("1");
    }

    function test_IssuerCannotFundBountyTwice() public {
        vm.startPrank(address(1));
        vm.deal(address(1), 10 ether);
        bountyFactory.createBountyWithLockedValue{value: 1 ether}("1", 1 ether, "metadata");
        vm.expectRevert(abi.encodeWithSelector(BountyFactory.BountyAlreadyFunded.selector, "1"));
        bountyFactory.fundBounty("1");
    }

    function test_NotIssuerCannotFundBounty() public {
        vm.startPrank(address(1));
        bountyFactory.createBounty("1", 1 ether, "metadata");
        vm.startPrank(address(2));
        vm.deal(address(2), 1 ether);
        vm.expectRevert(abi.encodeWithSelector(BountyFactory.NotBountyIssuer.selector, "1"));
        bountyFactory.fundBounty{value: 1 ether}("1");
    }

    function test_CanAddProposal() public {
        vm.startPrank(address(1));
        bountyFactory.createBounty("1", 100, "metadata");
        vm.startPrank(address(2));
        vm.expectEmit(true, true, false, true);        
        emit BountyFactory.PropositionCreated("1", BountyFactory.Proposition(address(2), "proposal"));
        bountyFactory.addProposal("1", "proposal");
    }        

    function test_CannotAddProposalToNonExistentBounty() public {
        vm.expectRevert(abi.encodeWithSelector(BountyFactory.BountyNotFound.selector));
        bountyFactory.addProposal("1", "proposal");
    } 

    function test_CannotAddProposalToNotOpenBounty() public {
        bountyFactory.createBounty("1", 100, "metadata");
        bountyFactory.closeBounty("1");
        vm.expectRevert(
            abi.encodeWithSelector(BountyFactory.BountyAlreadyClosed.selector, "1", BountyFactory.BountyState.CLOSED)
            );
        bountyFactory.addProposal("1", "proposal");
    }

    function test_CannotProposeTwice() public {
        bountyFactory.createBounty("1", 100, "metadata");
        vm.startPrank(address(2));
        bountyFactory.addProposal("1", "proposal");
        vm.expectRevert(abi.encodeWithSelector(BountyFactory.AlreadyParticipant.selector, address(2)));
        bountyFactory.addProposal("1", "proposal");
    }

    function test_IssuerCannotAddProposal() public {
        vm.startPrank(address(1));
        bountyFactory.createBounty("1", 100, "metadata");
        vm.expectRevert(abi.encodeWithSelector(BountyFactory.BountyIssuer.selector, "1", address(1)));
        bountyFactory.addProposal("1", "proposal");
    }

    function test_markResolvedAndPayResolver() public {
        assert(address(2).balance == 0);
        vm.startPrank(address(1));
        vm.deal(address(1), 10 ether);
        BountyFactory.Bounty memory bounty = BountyFactory.Bounty(
            "1", address(1), 1 ether, true, BountyFactory.BountyState.OPEN, "metadata"
        );
        vm.expectEmit(true, true, false, true);
        emit BountyFactory.BountyCreated(bounty);
        bountyFactory.createBountyWithLockedValue{value: 1 ether}("1", 1 ether, "metadata");
        vm.startPrank(address(2));
        emit BountyFactory.PropositionCreated("1", BountyFactory.Proposition(address(2), "metadata"));
        bountyFactory.addProposal("1", "metadata");
        vm.startPrank(address(1));
        vm.expectEmit(true, true, false, true);
        emit BountyFactory.BountyResolved("1", address(2));
        bountyFactory.markResolved("1", address(2));
        assert(address(2).balance == 1 ether);
    }

    function test_CannotMarkResolvedUnfundedBounty() public {
        vm.startPrank(address(1));
        BountyFactory.Bounty memory bounty = BountyFactory.Bounty(
            "1", address(1), 1 ether, false, BountyFactory.BountyState.OPEN, "metadata"
        );
        vm.expectEmit(true, true, false, true);
        emit BountyFactory.BountyCreated(bounty);
        bountyFactory.createBounty("1", 1 ether, "metadata");
        vm.startPrank(address(2));
        emit BountyFactory.PropositionCreated("1", BountyFactory.Proposition(address(2), "metadata"));
        bountyFactory.addProposal("1", "metadata");
        vm.startPrank(address(1));
        vm.expectRevert(abi.encodeWithSelector(BountyFactory.BountyNotFunded.selector, "1"));
        bountyFactory.markResolved("1", address(2));
    }

    function test_NotIssuerCannotMarkResolved() public {
        vm.startPrank(address(1));
        bountyFactory.createBounty("1", 1 ether, "metadata");
        vm.startPrank(address(2));
        bountyFactory.addProposal("1", "proposal");
        vm.expectRevert(abi.encodeWithSelector(BountyFactory.NotBountyIssuer.selector, "1"));
        bountyFactory.markResolved("1", address(2));
    }

    function test_NotParticipantCannotBeBountyResolver() public {
        bountyFactory.createBounty("1", 100, "metadata");
        vm.expectRevert(abi.encodeWithSelector(BountyFactory.NotParticipant.selector, "1", address(2)));
        bountyFactory.markResolved("1", address(2));
    }

    function test_CannotResolveNotOpenBounty() public {
        vm.startPrank(address(1));
        bountyFactory.createBounty("1", 100, "metadata");
        vm.startPrank(address(2));
        bountyFactory.addProposal("1", "metadata");
        vm.startPrank(address(1));
        bountyFactory.closeBounty("1");
        vm.expectRevert(
            abi.encodeWithSelector(BountyFactory.BountyAlreadyClosed.selector, "1", BountyFactory.BountyState.CLOSED)
            );
        bountyFactory.markResolved("1", address(2));
    }

    function test_CanCloseBounty() public {
        bountyFactory.createBounty("1", 100, "metadata");
        vm.expectEmit(true, true, false, true);
        emit BountyFactory.BountyClosed("1");
        bountyFactory.closeBounty("1");
    }

    function test_CanCloseBountyAndGetRefund() public {
        vm.startPrank(vm.addr(1));
        vm.deal(vm.addr(1), 1 ether);
        assert(vm.addr(1).balance == 1 ether);
        bountyFactory.createBountyWithLockedValue{value: 1 ether}("1", 1 ether, "metadata");
        assert(vm.addr(1).balance == 0);
        bountyFactory.closeBounty("1");
        assert(vm.addr(1).balance == 1 ether);

    }

    function test_NotIssuerCannotCloseBounty() public {
        vm.startPrank(address(1));
        bountyFactory.createBounty("1", 100, "metadata");
        vm.startPrank(address(2));
        vm.expectRevert(abi.encodeWithSelector(BountyFactory.NotBountyIssuer.selector, "1"));
        bountyFactory.closeBounty("1");
    }

    function test_CannotCloseNotOpenBounty() public {
        bountyFactory.createBounty("1", 100, "metadata");
        bountyFactory.closeBounty("1");
        vm.expectRevert(
            abi.encodeWithSelector(BountyFactory.BountyAlreadyClosed.selector, "1", BountyFactory.BountyState.CLOSED)
            );
        bountyFactory.closeBounty("1");
    }
}


// to do: switch all address(1) to vm.addr(1)