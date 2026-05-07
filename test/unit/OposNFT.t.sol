// SPDX-License-Identifier: MIT
pragma solidity ^0.8.34;

import {TestBase} from "../helpers/TestBase.sol";

/// @notice Unit tests for OposNFT (mint paths, access control, gifts).
contract OposNFTTest is TestBase {

    // ─────────────────────────── N1 — token ID monotonicity ───────────────────────

    function test_N1_token_ids_monotonic_and_in_range() public {
        uint256[] memory ids = _adminMintAs(10);
        for (uint256 i = 0; i < ids.length; ++i) {
            assertEq(ids[i], i + 1, "ids should be sequential starting at 1");
            assertTrue(ids[i] >= 1 && ids[i] <= nft.MAX_SUPPLY(), "id in range");
        }
        assertEq(nft.totalSupply(), 10, "totalSupply matches");
    }

    // ─────────────────────────── N2 — MAX_SUPPLY enforcement ──────────────────────

    function test_N2_buy_reverts_past_max_supply() public {
        // Mint near the cap by doing many adminMints (faster than buying).
        uint256 max = nft.MAX_SUPPLY();
        // Mint up to max-1.
        uint256 chunkSize = 200;
        uint256 left = max - 1;
        while (left >= chunkSize) {
            _adminMintAs(chunkSize);
            left -= chunkSize;
        }
        if (left > 0) _adminMintAs(left);

        // 1 slot remaining. Try to buy 2 — must revert.
        uint256 cost = nft.mintPrice() * 2;
        vm.deal(actors[0], cost);
        vm.prank(actors[0]);
        vm.expectRevert(bytes("Exceeds max supply"));
        nft.buy{value: cost}(2);

        // Buying exactly 1 succeeds.
        vm.deal(actors[0], cost / 2);
        vm.prank(actors[0]);
        nft.buy{value: cost / 2}(1);

        assertEq(nft.totalSupply(), max, "supply at cap");

        // Any further mint reverts.
        vm.deal(actors[0], cost / 2);
        vm.prank(actors[0]);
        vm.expectRevert(bytes("Exceeds max supply"));
        nft.buy{value: cost / 2}(1);
    }

    // ─────────────────────────── N3 — payment correctness ─────────────────────────

    function test_N3_buy_refunds_overpayment() public {
        uint256 amount = 3;
        uint256 cost = nft.mintPrice() * amount;
        uint256 overpay = 0.01 ether;
        vm.deal(actors[0], cost + overpay);

        uint256 before = actors[0].balance;
        vm.prank(actors[0]);
        nft.buy{value: cost + overpay}(amount);

        // Overpay refunded. Net spend = cost only.
        assertEq(before - actors[0].balance, cost, "exact spend");
    }

    function test_N3_buy_reverts_underpayment() public {
        uint256 amount = 3;
        uint256 cost = nft.mintPrice() * amount;
        vm.deal(actors[0], cost - 1);
        vm.prank(actors[0]);
        vm.expectRevert(bytes("Insufficient ETH sent"));
        nft.buy{value: cost - 1}(amount);
    }

    // ─────────────────────────── N4 — distributor notification ────────────────────

    function test_N4_mint_increments_active_in_tier() public {
        uint256[] memory ids = _adminMintAs(20);
        // Sum of activeInTier should equal minted count.
        uint256 totalActive = _sumActive();
        assertEq(totalActive, 20, "activeInTier total = minted");

        // Each NFT's tier matches what's incremented.
        // Verify by re-counting: sum tiers should match the per-NFT tierIndexOf().
        uint256[5] memory tally;
        for (uint256 i = 0; i < ids.length; ++i) {
            tally[nft.tierIndexOf(ids[i])]++;
        }
        for (uint8 t = 0; t < 5; ++t) {
            assertEq(distributor.activeInTier(t), tally[t], "per-tier count matches");
        }
    }

    // ─────────────────────────── N5 — owner-only access ───────────────────────────

    function testFuzz_N5_adminMint_only_owner(address caller) public {
        vm.assume(caller != owner);
        vm.assume(caller != address(0));
        vm.deal(caller, 1 ether);
        vm.prank(caller);
        vm.expectRevert();
        nft.adminMint(1);
    }

    function testFuzz_N5_giftNFT_only_owner(address caller) public {
        vm.assume(caller != owner);
        vm.assume(caller != address(0));
        address[] memory recipients = new address[](1);
        recipients[0] = actors[0];
        vm.prank(caller);
        vm.expectRevert();
        nft.giftNFT(recipients);
    }

    function testFuzz_N5_setMintPrice_only_owner(address caller) public {
        vm.assume(caller != owner);
        vm.prank(caller);
        vm.expectRevert();
        nft.setMintPrice(1 ether);
    }

    function testFuzz_N5_withdraw_only_owner(address caller) public {
        vm.assume(caller != owner);
        vm.prank(caller);
        vm.expectRevert();
        nft.withdraw();
    }

    // ─────────────────────────── N7 — withdraw correctness ────────────────────────

    function test_N7_withdraw_sends_full_balance() public {
        // Buy generates ETH for the contract.
        uint256[] memory ids = _buyAs(actors[0], 5);
        ids; // silence unused

        uint256 contractBalance = address(nft).balance;
        assertGt(contractBalance, 0, "should have ETH");

        uint256 ownerBefore = owner.balance;
        vm.prank(owner);
        nft.withdraw();

        assertEq(address(nft).balance, 0, "contract drained");
        assertEq(owner.balance, ownerBefore + contractBalance, "owner received all");
    }

    function test_N7_withdraw_reverts_if_zero() public {
        vm.prank(owner);
        vm.expectRevert(bytes("No funds to withdraw"));
        nft.withdraw();
    }

    // ─────────────────────────── N8 — tierIndexOf in range ────────────────────────

    function test_N8_tierIndexOf_in_range() public {
        uint256[] memory ids = _adminMintAs(50);
        for (uint256 i = 0; i < ids.length; ++i) {
            uint8 tier = nft.tierIndexOf(ids[i]);
            assertTrue(tier <= 4, "tier in [0,4]");
        }
    }

    function test_N8_tierIndexOf_reverts_for_unknown() public {
        vm.expectRevert();
        nft.tierIndexOf(999_999);
    }

    // ─────────────────────────── N9 — tokenURI shape ──────────────────────────────

    function test_N9_tokenURI_starts_with_base64_json() public {
        uint256[] memory ids = _adminMintAs(1);
        string memory uri = nft.tokenURI(ids[0]);
        bytes memory uriBytes = bytes(uri);

        // Verify prefix.
        bytes memory prefix = bytes("data:application/json;base64,");
        assertGt(uriBytes.length, prefix.length, "uri longer than prefix");
        for (uint256 i = 0; i < prefix.length; ++i) {
            assertEq(uriBytes[i], prefix[i], "prefix char mismatch");
        }
    }

    // ─────────────────────────── N10 — giftNFT input validation ───────────────────

    function test_N10_giftNFT_one_per_recipient() public {
        address[] memory recipients = new address[](3);
        recipients[0] = actors[0];
        recipients[1] = actors[1];
        recipients[2] = actors[2];

        uint256 startSupply = nft.totalSupply();
        vm.prank(owner);
        nft.giftNFT(recipients);

        assertEq(nft.totalSupply(), startSupply + 3, "supply +3");
        assertEq(nft.balanceOf(actors[0]), 1, "actor0 has 1");
        assertEq(nft.balanceOf(actors[1]), 1, "actor1 has 1");
        assertEq(nft.balanceOf(actors[2]), 1, "actor2 has 1");
    }

    function test_N10_giftNFT_reverts_zero_recipient() public {
        address[] memory recipients = new address[](2);
        recipients[0] = actors[0];
        recipients[1] = address(0);
        vm.prank(owner);
        vm.expectRevert(bytes("Zero recipient"));
        nft.giftNFT(recipients);
    }

    function test_N10_giftNFT_reverts_empty() public {
        address[] memory recipients = new address[](0);
        vm.prank(owner);
        vm.expectRevert(bytes("Recipients must be 1-500"));
        nft.giftNFT(recipients);
    }

    function test_N10_giftNFT_reverts_over_limit() public {
        address[] memory recipients = new address[](501);
        for (uint256 i = 0; i < 501; ++i) recipients[i] = actors[0];
        vm.prank(owner);
        vm.expectRevert(bytes("Recipients must be 1-500"));
        nft.giftNFT(recipients);
    }
}
