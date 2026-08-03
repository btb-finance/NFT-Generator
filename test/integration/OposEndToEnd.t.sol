// SPDX-License-Identifier: MIT
pragma solidity ^0.8.34;

import {Test} from "forge-std/Test.sol";
import {OposRenderer} from "../../src/OposRenderer.sol";
import {DeployRenderer} from "../helpers/DeployRenderer.sol";
import {OposNFT} from "../../src/OposNFT.sol";
import {NFTRewardDistributor} from "../../src/NFTRewardDistributor.sol";
import {OPOSSUM} from "./OPOSSUM.sol";
import {MockBTB} from "../mocks/MockBTB.sol";

/// @notice End-to-end test with the REAL OPOSSUM token (1% transfer tax) wired
///         exactly like production: the distributor IS the OPOS treasury.
///
///         Verifies the full economic loop:
///           BTB deposit → OPOS mint (untaxed)
///           → user-to-user OPOS transfer ("trade") taxes 1% straight into
///             the distributor
///           → NFT holders claim and receive EXACTLY the displayed pending
///             (treasury outflows are tax-exempt)
///           → reapers are paid untaxed too
///           → OPOS → BTB redemption stays exact.
contract OposEndToEndTest is Test {
    OposRenderer internal renderer;
    OposNFT internal nft;
    NFTRewardDistributor internal distributor;
    OPOSSUM internal opos;
    MockBTB internal btb;

    address internal owner = makeAddr("owner");
    address internal alice = makeAddr("alice");   // OPOS trader
    address internal bob = makeAddr("bob");       // OPOS trader
    address internal holder = makeAddr("holder"); // NFT holder
    address internal reaper = makeAddr("reaper");

    function setUp() public {
        vm.startPrank(owner);
        btb = new MockBTB();
        // Temporary treasury = owner; re-pointed to the distributor below,
        // mirroring the production deploy order.
        opos = new OPOSSUM(address(btb), owner, owner);
        renderer = DeployRenderer.deploy();
        nft = new OposNFT(address(renderer));
        distributor = new NFTRewardDistributor(address(opos), address(nft));
        nft.setDistributor(address(distributor));
        opos.setTreasury(address(distributor));
        vm.stopPrank();

        // Alice converts 100 BTB → 100M OPOS (untaxed mint).
        btb.mintTo(alice, 100e18);
        vm.startPrank(alice);
        btb.approve(address(opos), 100e18);
        opos.mint(100e18);
        vm.stopPrank();

        // Holder buys one NFT.
        uint256 price = nft.mintPrice();
        vm.deal(holder, 1 ether);
        vm.prank(holder);
        nft.buy{value: price}(1);
    }

    // ───────────── trade tax lands directly in the distributor ─────────────

    function test_E1_trade_tax_flows_directly_into_distributor() public {
        uint256 tradeAmount = 1_000_000e18;
        vm.prank(alice);
        opos.transfer(bob, tradeAmount);

        // Bob receives 99%, distributor (as treasury) receives 1%, value conserved.
        assertEq(opos.balanceOf(bob), tradeAmount * 99 / 100, "bob gets 99%");
        assertEq(opos.balanceOf(address(distributor)), tradeAmount / 100, "distributor gets the 1% tax");
    }

    // ───────────── claims pay exactly the displayed pending ─────────────

    function test_E2_claim_pays_exactly_displayed_pending() public {
        // Two trades push tax into the distributor.
        vm.prank(alice);
        opos.transfer(bob, 2_000_000e18);
        vm.prank(bob);
        opos.transfer(alice, 500_000e18);

        uint256 tokenId = 1;
        uint256 displayed = nft.pendingReward(tokenId);
        assertGt(displayed, 0, "tax accrued to the holder's tier");

        vm.prank(holder);
        nft.claim(tokenId);

        // Treasury outflows are tax-exempt: received == displayed, to the wei.
        assertEq(opos.balanceOf(holder), displayed, "claim untaxed, matches display exactly");
        // Internal accounting matches the real token balance.
        assertEq(distributor.lastBalance(), opos.balanceOf(address(distributor)), "lastBalance consistent");
    }

    // ───────────── reap payouts are untaxed too ─────────────

    function test_E3_reap_pays_reaper_untaxed() public {
        vm.prank(alice);
        opos.transfer(bob, 1_000_000e18);

        vm.warp(block.timestamp + 100 days);
        uint256 tokenId = 1;
        uint256 displayed = distributor.pendingReward(tokenId);
        assertGt(displayed, 0, "stale NFT has pending to take");

        vm.prank(reaper);
        distributor.reap(tokenId);

        assertEq(opos.balanceOf(reaper), displayed, "reaper paid exactly pending, untaxed");
        assertTrue(distributor.asleep(tokenId), "NFT asleep after reap");
        assertEq(distributor.lastBalance(), opos.balanceOf(address(distributor)), "lastBalance consistent");
    }

    // ───────────── claimed OPOS redeems back to BTB exactly ─────────────

    function test_E4_mint_burn_roundtrip_exact() public {
        // Alice burns 50M OPOS (= 50 BTB) and gets exactly 50 BTB back.
        uint256 btbBefore = btb.balanceOf(alice);
        vm.prank(alice);
        opos.burn(50_000_000e18);
        assertEq(btb.balanceOf(alice) - btbBefore, 50e18, "exact 1:1,000,000 redemption");
    }

    // ───────────── misconfigured treasury: degraded but not broken ─────────────

    /// @dev If the distributor is NOT the treasury, claims are taxed 1% on the
    ///      way out (holders receive less than displayed) — but the
    ///      distributor's own accounting must survive, since its balance still
    ///      drops by exactly what it debits.
    function test_E5_non_treasury_distributor_taxed_but_solvent() public {
        address feeWallet = makeAddr("feeWallet");
        vm.startPrank(owner);
        OposNFT nft2 = new OposNFT(address(renderer));
        NFTRewardDistributor dist2 = new NFTRewardDistributor(address(opos), address(nft2));
        nft2.setDistributor(address(dist2));
        opos.setTreasury(feeWallet); // distributor deliberately NOT exempt
        vm.stopPrank();

        uint256 price = nft2.mintPrice();
        vm.deal(holder, 1 ether);
        vm.prank(holder);
        nft2.buy{value: price}(1);

        // Rewards arrive via a taxed transfer (sender pays, dist2 nets 99%).
        vm.prank(alice);
        opos.transfer(address(dist2), 1_000_000e18);

        uint256 displayed = nft2.pendingReward(1);
        assertGt(displayed, 0, "rewards accrued");

        uint256 before = opos.balanceOf(holder);
        vm.prank(holder);
        nft2.claim(1);
        uint256 received = opos.balanceOf(holder) - before;

        // Holder is shorted exactly the 1% tax...
        assertEq(received, displayed - displayed / 100, "claim taxed 1%");
        // ...but the distributor's books still match reality, so later claims
        // and reaps cannot be bricked by drift.
        assertEq(dist2.lastBalance(), opos.balanceOf(address(dist2)), "accounting survives taxation");
    }
}
