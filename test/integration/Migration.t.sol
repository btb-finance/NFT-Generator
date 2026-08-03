// SPDX-License-Identifier: MIT
pragma solidity ^0.8.34;

import {TestBase} from "../helpers/TestBase.sol";
import {console} from "forge-std/console.sol";
import {NFTRewardDistributor} from "../../src/NFTRewardDistributor.sol";
import {OposNFT} from "../../src/OposNFT.sol";

/// @notice End-to-end migration to a replacement distributor.
///
///         The two things that make this safe:
///           * the swap is announced on-chain and cannot land for 30 days;
///           * no money moves. The old contract keeps its balance and stays
///             usable, so rewards already earned there are never stranded.
///
///         And the thing that makes it practical: the replacement inherits the
///         existing tokens instead of enrolling 88,888 of them one at a time.
contract MigrationTest is TestBase {
    uint256[] internal ids;

    /// @dev Awake tokens per tier — what a replacement must be seeded with.
    ///      Publicly computable from the NFT, so holders can check the numbers
    ///      during the timelock rather than trusting the deployer.
    function _liveTierCounts() internal view returns (uint256[5] memory counts) {
        uint256 supply = nft.totalSupply();
        for (uint256 id = 1; id <= supply; ++id) {
            if (!distributor.asleep(id)) counts[nft.tierIndexOf(id)]++;
        }
    }

    function _deploySuccessor() internal returns (NFTRewardDistributor) {
        return new NFTRewardDistributor(
            address(opos), address(nft), nft.totalSupply(), _liveTierCounts()
        );
    }

    function setUp() public override {
        super.setUp();
        ids = _buyAs(actors[0], 12);
    }

    // ─────────────── the timelock ───────────────

    function test_MG1_migration_cannot_skip_the_delay() public {
        NFTRewardDistributor next = _deploySuccessor();

        vm.prank(owner);
        nft.proposeDistributor(address(next));
        assertEq(nft.pendingDistributor(), address(next), "proposal recorded");
        assertEq(nft.migrationReadyAt(), block.timestamp + 30 days, "clock started");

        // One second early is still early.
        vm.warp(nft.migrationReadyAt() - 1);
        vm.prank(owner);
        vm.expectRevert("Migration is still timelocked");
        nft.commitDistributor();

        vm.warp(nft.migrationReadyAt());
        vm.prank(owner);
        nft.commitDistributor();
        assertEq(address(nft.distributor()), address(next), "migrated");
        assertEq(nft.pendingDistributor(), address(0), "proposal cleared");
    }

    function test_MG1_only_owner_and_cancellable() public {
        NFTRewardDistributor next = _deploySuccessor();

        vm.prank(actors[1]);
        vm.expectRevert();
        nft.proposeDistributor(address(next));

        vm.prank(owner);
        nft.proposeDistributor(address(next));
        vm.prank(owner);
        nft.cancelDistributorMigration();
        assertEq(nft.pendingDistributor(), address(0), "cancelled");

        vm.warp(block.timestamp + 60 days);
        vm.prank(owner);
        vm.expectRevert("Nothing pending");
        nft.commitDistributor();
    }

    // ─────────────── the data problem ───────────────

    function test_MG2_successor_inherits_existing_tokens() public {
        NFTRewardDistributor next = _deploySuccessor();

        // Nobody called onMintBatch on `next`, yet it already knows the tokens.
        for (uint256 i = 0; i < ids.length; ++i) {
            assertFalse(next.registered(ids[i]), "not explicitly registered");
            assertEq(next.secondsUntilStale(ids[i]), 100 days, "sleep clock starts at deployment");
        }

        // Divisors match the live collection, so splits are correct from the
        // first fee rather than after some enrolment race.
        uint256 live;
        for (uint8 t = 0; t < 5; ++t) live += next.activeInTier(t);
        assertEq(live, nft.totalSupply(), "every token counted exactly once");
    }

    function test_MG3_holders_can_claim_from_the_successor_immediately() public {
        NFTRewardDistributor next = _deploySuccessor();
        vm.prank(owner);
        nft.proposeDistributor(address(next));
        vm.warp(block.timestamp + 30 days);
        vm.prank(owner);
        nft.commitDistributor();

        // New fees arrive at the new contract.
        opos.mintTo(address(next), 1_000 ether);

        uint256 before = opos.balanceOf(actors[0]);
        vm.prank(actors[0]);
        nft.claimMany(ids); // through the NFT facade, which now points at `next`
        uint256 paid = opos.balanceOf(actors[0]) - before;

        assertGt(paid, 0, "successor pays out without any enrolment step");
        console.log("claimed from successor:", paid);
    }

    // ─────────────── the money question ───────────────

    function test_MG4_rewards_in_the_old_distributor_stay_claimable() public {
        // Earn something under the old distributor first.
        _arriveFee(1_000 ether);
        uint256 owedBefore = distributor.pendingReward(ids[0]);
        assertGt(owedBefore, 0, "accrued under the old distributor");

        NFTRewardDistributor old = distributor;
        NFTRewardDistributor next = _deploySuccessor();
        vm.prank(owner);
        nft.proposeDistributor(address(next));
        vm.warp(block.timestamp + 30 days);
        vm.prank(owner);
        nft.commitDistributor();

        // The NFT no longer points at `old`...
        assertEq(address(nft.distributor()), address(next), "pointer moved");

        // ...but `old` is still a working contract that authorises against the
        // NFT, so the holder withdraws directly from it. Nothing is stranded.
        uint256 before = opos.balanceOf(actors[0]);
        vm.prank(actors[0]);
        old.claim(ids[0]);
        assertEq(opos.balanceOf(actors[0]) - before, owedBefore, "old rewards paid in full");

        // And the owner cannot take them — there is no admin on either side.
        assertGt(opos.balanceOf(address(old)), 0, "remaining funds still held for holders");
    }

    function test_MG5_sleeping_tokens_are_not_counted_as_active() public {
        // Put one token to sleep before migrating.
        vm.warp(block.timestamp + 100 days);
        vm.prank(actors[1]);
        distributor.reap(ids[0]);
        assertTrue(distributor.asleep(ids[0]), "asleep before migration");

        NFTRewardDistributor next = _deploySuccessor();

        uint256 live;
        for (uint8 t = 0; t < 5; ++t) live += next.activeInTier(t);
        assertEq(live, nft.totalSupply() - 1, "the sleeper is excluded from the divisors");
    }
}
