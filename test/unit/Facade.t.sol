// SPDX-License-Identifier: MIT
pragma solidity ^0.8.34;

import {TestBase} from "../helpers/TestBase.sol";
import {OposNFT} from "../../src/OposNFT.sol";
import {NFTRewardDistributor} from "../../src/NFTRewardDistributor.sol";

/// @notice Tests the NFT-side facade: users who only know the NFT contract
///         address can still claim/wake/read rewards. The NFT proxies through
///         to the distributor.
contract FacadeTest is TestBase {

    function test_facade_claim_pays_caller() public {
        uint256[] memory ids = _buyAs(actors[0], 1);
        _arriveFee(1000 ether);

        uint256 before = opos.balanceOf(actors[0]);
        // User calls NFT contract — not the distributor.
        vm.prank(actors[0]);
        nft.claim(ids[0]);
        uint256 paid = opos.balanceOf(actors[0]) - before;

        assertEq(paid, 200 ether, "facade claim pays 20%");
        assertEq(distributor.lifetimeClaimed(ids[0]), 200 ether, "lifetime updated");
    }

    function test_facade_claim_reverts_if_not_owner() public {
        uint256[] memory ids = _buyAs(actors[0], 1);
        _arriveFee(1000 ether);

        vm.prank(actors[1]);
        vm.expectRevert(NFTRewardDistributor.NotNFTOwner.selector);
        nft.claim(ids[0]);
    }

    function test_facade_claimMany_pays_caller() public {
        uint256[] memory ids = _buyAs(actors[0], 5);
        _arriveFee(1000 ether);

        uint256 before = opos.balanceOf(actors[0]);
        vm.prank(actors[0]);
        nft.claimMany(ids);
        uint256 paid = opos.balanceOf(actors[0]) - before;

        // 5 NFTs distributed across tiers — each NFT in tier T gets (20%/activeInTier[T]).
        // Total paid = sum of per-tier shares for tiers that have ≥ 1 NFT here.
        // We just verify it's > 0 and matches the expected total via lifetime sum.
        uint256 lifetimeSum;
        for (uint256 i = 0; i < ids.length; ++i) lifetimeSum += distributor.lifetimeClaimed(ids[i]);
        assertEq(paid, lifetimeSum, "paid == lifetime delta");
        assertGt(paid, 0, "non-zero payout");
    }

    function test_facade_wake_revives_nft() public {
        uint256[] memory ids = _buyAs(actors[0], 1);
        vm.warp(block.timestamp + 100 days);
        vm.prank(actors[1]);
        distributor.reap(ids[0]); // reap directly

        // Owner uses NFT facade to wake.
        vm.prank(actors[0]);
        nft.wake(ids[0]);
        assertFalse(distributor.asleep(ids[0]), "should be awake");
    }

    /// @dev Marketplace scenario: a buyer scoops up a batch of reaped
    ///      (sleeping) NFTs and revives them all in a single transaction.
    function test_facade_wakeMany_revives_batch_after_purchase() public {
        uint256[] memory ids = _buyAs(actors[0], 5);
        _arriveFee(1000 ether);

        // All five go stale and get reaped.
        vm.warp(block.timestamp + 100 days);
        for (uint256 i = 0; i < ids.length; ++i) {
            vm.prank(actors[1]);
            distributor.reap(ids[i]);
            assertTrue(distributor.asleep(ids[i]), "reaped");
        }
        assertEq(_sumActive(), 0, "all dormant");

        // "OpenSea sale": original owner transfers all five to the buyer.
        for (uint256 i = 0; i < ids.length; ++i) {
            vm.prank(actors[0]);
            nft.transferFrom(actors[0], actors[2], ids[i]);
        }

        // Buyer revives the whole batch with ONE call through the NFT facade.
        vm.prank(actors[2]);
        nft.wakeMany(ids);

        for (uint256 i = 0; i < ids.length; ++i) {
            assertFalse(distributor.asleep(ids[i]), "awake after batch wake");
            assertEq(distributor.pendingReward(ids[i]), 0, "earns from now, nothing retroactive");
        }
        assertEq(_sumActive(), 5, "all back in the divisor");

        // New rewards now accrue to the buyer's revived NFTs.
        _arriveFee(1000 ether);
        uint256 totalPending;
        for (uint256 i = 0; i < ids.length; ++i) totalPending += distributor.pendingReward(ids[i]);
        assertGt(totalPending, 0, "revived NFTs earn again");
    }

    function test_facade_wakeMany_guards() public {
        uint256[] memory ids = _buyAs(actors[0], 2);
        vm.warp(block.timestamp + 100 days);
        vm.prank(actors[1]);
        distributor.reap(ids[0]);
        vm.prank(actors[1]);
        distributor.reap(ids[1]);

        // Non-owner cannot batch-wake someone else's NFTs.
        vm.prank(actors[3]);
        vm.expectRevert(NFTRewardDistributor.NotNFTOwner.selector);
        nft.wakeMany(ids);

        // Empty batch rejected.
        uint256[] memory empty = new uint256[](0);
        vm.prank(actors[0]);
        vm.expectRevert(NFTRewardDistributor.EmptyBatch.selector);
        nft.wakeMany(empty);

        // Over the cap rejected.
        uint256[] memory tooMany = new uint256[](101);
        vm.prank(actors[0]);
        vm.expectRevert(NFTRewardDistributor.BatchTooLarge.selector);
        nft.wakeMany(tooMany);

        // Waking an awake token in the batch reverts the whole batch.
        vm.prank(actors[0]);
        nft.wake(ids[0]);
        vm.prank(actors[0]);
        vm.expectRevert(NFTRewardDistributor.NotAsleep.selector);
        nft.wakeMany(ids);
    }

    function test_facade_views_reflect_state() public {
        uint256[] memory ids = _buyAs(actors[0], 1);
        _arriveFee(1000 ether);

        // Pending reflects projection.
        assertEq(nft.pendingReward(ids[0]), 200 ether, "pending facade");
        assertEq(nft.lifetimeReward(ids[0]), 200 ether, "lifetime = pending pre-claim");
        assertFalse(nft.isAsleep(ids[0]), "not asleep");

        // After claim, pending = 0, lifetime same.
        vm.prank(actors[0]);
        nft.claim(ids[0]);
        assertEq(nft.pendingReward(ids[0]), 0, "pending zeroed");
        assertEq(nft.lifetimeReward(ids[0]), 200 ether, "lifetime tracks claimed");
    }

    function test_facade_reverts_when_distributor_unset() public {
        // Distributor can't be unwired once set, so use a fresh NFT that never
        // had one. No tokens can be minted in this state — facade mutations
        // revert and views return safe defaults.
        vm.prank(owner);
        OposNFT freshNft = new OposNFT(address(renderer));

        vm.prank(actors[0]);
        vm.expectRevert(bytes("Distributor not set"));
        freshNft.claim(1);

        vm.prank(actors[0]);
        vm.expectRevert(bytes("Distributor not set"));
        freshNft.wake(1);

        // Views return safe defaults rather than revert.
        assertEq(freshNft.pendingReward(1), 0, "view returns 0");
        assertFalse(freshNft.isAsleep(1), "view returns false");
    }

    function test_facade_claimFor_only_callable_by_NFT() public {
        // External user trying to call distributor.claimFor directly is rejected.
        vm.prank(actors[0]);
        vm.expectRevert(NFTRewardDistributor.NotNFT.selector);
        distributor.claimFor(actors[0], 1);

        vm.prank(actors[0]);
        vm.expectRevert(NFTRewardDistributor.NotNFT.selector);
        distributor.wakeFor(actors[0], 1);
    }
}
