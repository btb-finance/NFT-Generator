// SPDX-License-Identifier: MIT
pragma solidity ^0.8.34;

import {TestBase} from "../helpers/TestBase.sol";
import {OposNFT} from "../../src/OposNFT.sol";

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

    /// @dev Verifies the corrected MAX_SUPPLY boundary: the LAST minted id must
    ///      be reachable. Pre-fix, the check `_tokenIdCounter + amount <= MAX`
    ///      meant only 88,887 ids were reachable. Now id 88,888 IS mintable.
    ///      Uses vm.store to skip the counter near the cap.
    function test_N2_max_supply_boundary_reachable_and_capped() public {
        // _tokenIdCounter is the FIRST private storage var on OposNFT — but
        // OposNFT inherits from ERC721, ERC2981, Ownable, ReentrancyGuard,
        // each with their own slots. Find the slot empirically: bump and read.
        uint256 max = nft.MAX_SUPPLY(); // 88,888

        // Strategy: warp counter to MAX-1 by minting 1 NFT and using vm.store
        // to set the counter directly. We need to know the slot.
        uint256 counterSlot = _findCounterSlot();

        // Set counter so the next mint produces id == MAX.
        vm.store(address(nft), bytes32(counterSlot), bytes32(max));
        // Pre-fix, this would have reverted with "Exceeds max supply" because
        // (max + 1) > max. Post-fix, it succeeds because (max + 1 - 1) <= max.
        vm.prank(owner);
        nft.adminMint(1);

        // Last id minted IS the cap value — the fix lets MAX_SUPPLY be reached.
        assertEq(nft.totalSupply(), max, "MAX-th NFT successfully minted");

        // Counter is now MAX+1. Any further mint reverts.
        vm.prank(owner);
        vm.expectRevert(bytes("Exceeds max supply"));
        nft.adminMint(1);
    }

    /// @dev Walks the first ~15 storage slots looking for one that holds the
    ///      tokenId counter we just observed. Brittle but adequate for one test.
    function _findCounterSlot() internal view returns (uint256) {
        for (uint256 s = 0; s < 30; s++) {
            bytes32 v = vm.load(address(nft), bytes32(s));
            if (uint256(v) == 1) {
                return s; // initial _tokenIdCounter = 1
            }
        }
        revert("counter slot not found");
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

    // ─────────────────────────── N6 — royalty (ERC2981) ───────────────────────────

    function test_N6_default_royalty_5_percent() public {
        uint256[] memory ids = _adminMintAs(1);
        (address receiver, uint256 royaltyAmount) = nft.royaltyInfo(ids[0], 1 ether);
        assertEq(receiver, owner, "royalty goes to owner by default");
        assertEq(royaltyAmount, 0.05 ether, "5% royalty");
    }

    function test_N6_royalty_owner_can_update() public {
        uint256[] memory ids = _adminMintAs(1);
        address newReceiver = actors[2];
        uint96 newBps = 250; // 2.5%

        vm.prank(owner);
        nft.setDefaultRoyalty(newReceiver, newBps);

        (address receiver, uint256 royaltyAmount) = nft.royaltyInfo(ids[0], 1 ether);
        assertEq(receiver, newReceiver, "new receiver");
        assertEq(royaltyAmount, 0.025 ether, "2.5% royalty");

        // Anything above the 5% cap is rejected.
        vm.prank(owner);
        vm.expectRevert(bytes("Royalty cannot exceed 5%"));
        nft.setDefaultRoyalty(newReceiver, 501);
    }

    // ─────────────────────────── A9 — mint requires distributor ───────────────────

    /// @dev setDistributor is locked once minting begins, so a mint without a
    ///      distributor would permanently disable the yield system. Every mint
    ///      path must therefore revert until the distributor is wired.
    function test_A9_mint_reverts_without_distributor() public {
        // Fresh NFT with no distributor wired.
        vm.prank(owner);
        OposNFT freshNft = new OposNFT(address(renderer));

        vm.prank(owner);
        vm.expectRevert(bytes("Distributor not set"));
        freshNft.adminMint(5);

        uint256 price = freshNft.mintPrice();
        vm.deal(actors[0], 1 ether);
        vm.prank(actors[0]);
        vm.expectRevert(bytes("Distributor not set"));
        freshNft.buy{value: price}(1);

        address[] memory recipients = new address[](1);
        recipients[0] = actors[1];
        vm.prank(owner);
        vm.expectRevert(bytes("Distributor not set"));
        freshNft.giftNFT(recipients);

        // After wiring, minting works and the distributor is notified.
        // (The shared fixture's nft/distributor pair demonstrates this.)
        uint256 activeBefore = _sumActive();
        vm.prank(owner);
        nft.adminMint(3);
        assertEq(_sumActive(), activeBefore + 3, "wired mints notify distributor");
    }

    // ─────────────────────────── A13 — zero mint price ────────────────────────────

    function test_A13_buy_at_zero_price() public {
        vm.prank(owner);
        nft.setMintPrice(0);

        uint256 startSupply = nft.totalSupply();
        // Send 0 ETH; should succeed.
        vm.prank(actors[0]);
        nft.buy{value: 0}(3);
        assertEq(nft.totalSupply(), startSupply + 3, "free mint works");
        assertEq(nft.balanceOf(actors[0]), 3, "actor got 3");
    }

    // ─────────────────────────── A16 — receiver behavior ─────────────────────────

    /// @dev `giftNFT` uses `_mint` (no callback), so a non-receiving contract
    ///      in the recipients list does NOT grief the batch. The contract just
    ///      receives the NFT — owner is responsible for vetting recipients.
    function test_A16_giftNFT_to_non_receiver_contract_succeeds() public {
        RejectingReceiver bad = new RejectingReceiver();
        address[] memory recipients = new address[](2);
        recipients[0] = bad == bad ? address(bad) : actors[0];
        recipients[0] = address(bad);
        recipients[1] = actors[0];

        uint256 startSupply = nft.totalSupply();
        vm.prank(owner);
        nft.giftNFT(recipients);
        assertEq(nft.totalSupply(), startSupply + 2, "both NFTs minted");
        assertEq(nft.balanceOf(address(bad)), 1, "bad receiver got NFT");
        assertEq(nft.balanceOf(actors[0]), 1, "actor got NFT");
    }

    /// @dev `buy` still uses `_safeMint`, so a non-receiving contract calling
    ///      `buy` reverts — protects buyers from getting stuck NFTs.
    function test_A16_buy_to_non_receiver_contract_reverts() public {
        RejectingReceiver bad = new RejectingReceiver();
        uint256 cost = nft.mintPrice();
        vm.deal(address(bad), cost);
        vm.prank(address(bad));
        vm.expectRevert(); // _safeMint reverts when receiver rejects
        nft.buy{value: cost}(1);
    }
}

/// @notice Helper contract for A16: a contract that does NOT implement
///         IERC721Receiver. `_safeMint` reverts; `_mint` does not.
contract RejectingReceiver {
    // Intentionally no onERC721Received.
}
