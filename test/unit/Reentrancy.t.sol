// SPDX-License-Identifier: MIT
pragma solidity ^0.8.34;

import {Test} from "forge-std/Test.sol";
import {OposRenderer} from "../../src/OposRenderer.sol";
import {DeployRenderer} from "../helpers/DeployRenderer.sol";
import {OposNFT} from "../../src/OposNFT.sol";
import {NFTRewardDistributor} from "../../src/NFTRewardDistributor.sol";
import {ReentrantToken} from "../mocks/ReentrantToken.sol";

/// @notice D4 — reentrancy guard holds against a malicious ERC20.
///         Custom setup uses a `ReentrantToken` whose `_update` re-enters the
///         distributor's claim/reap during the transfer. Both must be blocked
///         by `nonReentrant`.
contract ReentrancyTest is Test {
    OposRenderer renderer;
    OposNFT nft;
    NFTRewardDistributor dist;
    ReentrantToken evil;

    address owner = makeAddr("owner");
    address alice = makeAddr("alice");

    function setUp() public {
        vm.startPrank(owner);
        renderer = DeployRenderer.deploy();
        nft = new OposNFT(address(renderer));
        evil = new ReentrantToken();
        dist = new NFTRewardDistributor(address(evil), address(nft), 0, [uint256(0), 0, 0, 0, 0]);
        nft.setDistributor(address(dist));
        // Mint 1 NFT to alice via gift so we don't need ETH plumbing.
        address[] memory recipients = new address[](1);
        recipients[0] = alice;
        nft.giftNFT(recipients);
        vm.stopPrank();
    }

    // ─────────────────────── D4a — claim cannot re-enter claim ───────────────────

    function test_D4_claim_cannot_reenter_claim() public {
        // Land fees so there's something to pay out.
        evil.mintTo(address(dist), 1000 ether);

        // Arm the malicious token: on the next `transfer`, attempt claim() of id 1.
        evil.setAttack(address(dist), 1, true, ReentrantToken.Mode.Claim);

        // Alice claims — distributor will call `evil.transfer(alice, owed)`,
        // which tries to re-enter `claim(1)`. The guard must trip the inner call.
        vm.prank(alice);
        dist.claim(1);

        // The outer claim succeeded; the inner re-entry was blocked.
        // We assert by checking that `lastRevertData` is non-empty (something
        // reverted on re-entry, which is exactly what we want).
        assertGt(evil.lastRevertData().length, 0, "re-entry did not revert");
        // And that re-entry is no longer armed (it disabled itself on first attempt).
        assertFalse(evil.attackEnabled(), "attack disarmed");
    }

    // ─────────────────────── D4b — reap cannot re-enter reap ─────────────────────

    function test_D4_reap_cannot_reenter_reap() public {
        evil.mintTo(address(dist), 1000 ether);

        // Make the NFT stale.
        vm.warp(block.timestamp + 100 days);

        // Arm: on transfer, attempt reap(1).
        evil.setAttack(address(dist), 1, true, ReentrantToken.Mode.Reap);

        // Anyone reaps. Distributor transfers to reaper; evil tries to re-reap.
        // Outer reap succeeds; inner must revert (NFT is now asleep, guard also active).
        address reaper = makeAddr("reaper");
        vm.prank(reaper);
        dist.reap(1);

        assertGt(evil.lastRevertData().length, 0, "re-entry did not revert");
        assertTrue(dist.asleep(1), "NFT should be asleep after outer reap");
    }
}
