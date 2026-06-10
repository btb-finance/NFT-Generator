// SPDX-License-Identifier: MIT
pragma solidity ^0.8.34;

import {TestBase} from "../helpers/TestBase.sol";
import {OposNFT} from "../../src/OposNFT.sol";

/// @notice Tests the XP voucher mint: backend signs an EIP-712 cumulative
///         allowance, user mints for free against it.
contract XPMintTest is TestBase {
    uint256 internal signerPk = 0xA11CE;
    address internal signer;

    function setUp() public override {
        super.setUp();
        signer = vm.addr(signerPk);
        vm.prank(owner);
        nft.setXPSigner(signer);
    }

    /// @dev Backend-side voucher: sign the digest the contract exposes.
    function _voucher(address user, uint256 totalAllowed, uint256 deadline)
        internal
        view
        returns (bytes memory sig)
    {
        bytes32 digest = nft.hashXPMint(user, totalAllowed, deadline);
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(signerPk, digest);
        sig = abi.encodePacked(r, s, v);
    }

    function test_X1_mint_with_voucher() public {
        // User earned 100 XP → backend grants lifetime allowance of 1.
        bytes memory sig = _voucher(actors[0], 1, block.timestamp + 1 hours);

        uint256 activeBefore = _sumActive();
        vm.prank(actors[0]);
        nft.mintWithXP(1, 1, block.timestamp + 1 hours, sig);

        assertEq(nft.balanceOf(actors[0]), 1, "free NFT minted");
        assertEq(nft.xpMinted(actors[0]), 1, "allowance consumed");
        assertEq(_sumActive(), activeBefore + 1, "distributor notified");
    }

    function test_X2_replay_cannot_exceed_allowance() public {
        uint256 deadline = block.timestamp + 1 hours;
        bytes memory sig = _voucher(actors[0], 2, deadline);

        // 200 XP → allowance 2, minted as 1 + 1.
        vm.startPrank(actors[0]);
        nft.mintWithXP(1, 2, deadline, sig);
        nft.mintWithXP(1, 2, deadline, sig); // same sig again — still within cap
        // Third replay of the same voucher must fail: cumulative cap reached.
        vm.expectRevert(OposNFT.ExceedsXPAllowance.selector);
        nft.mintWithXP(1, 2, deadline, sig);
        vm.stopPrank();

        assertEq(nft.balanceOf(actors[0]), 2, "exactly the allowed amount");
    }

    function test_X3_new_xp_raises_cumulative_allowance() public {
        uint256 deadline = block.timestamp + 1 hours;

        // Build vouchers before pranking: _voucher() makes a staticcall to
        // hashXPMint, which would otherwise consume the prank.
        bytes memory sig1 = _voucher(actors[0], 1, deadline);
        bytes memory sig3 = _voucher(actors[0], 3, deadline);

        // First voucher: allowance 1, fully used.
        vm.prank(actors[0]);
        nft.mintWithXP(1, 1, deadline, sig1);

        // User earns 200 more XP → backend signs a HIGHER total (1 + 2 = 3).
        vm.prank(actors[0]);
        nft.mintWithXP(2, 3, deadline, sig3);

        assertEq(nft.balanceOf(actors[0]), 3, "old + new allowance both minted");
        assertEq(nft.xpMinted(actors[0]), 3, "lifetime counter tracks");
    }

    function test_X4_voucher_bound_to_wallet() public {
        uint256 deadline = block.timestamp + 1 hours;
        bytes memory sig = _voucher(actors[0], 5, deadline);

        // A different wallet cannot use actor0's voucher.
        vm.prank(actors[1]);
        vm.expectRevert(OposNFT.InvalidXPSignature.selector);
        nft.mintWithXP(1, 5, deadline, sig);
    }

    function test_X5_expired_voucher_rejected() public {
        uint256 deadline = block.timestamp + 1 hours;
        bytes memory sig = _voucher(actors[0], 1, deadline);

        vm.warp(deadline + 1);
        vm.prank(actors[0]);
        vm.expectRevert(OposNFT.XPVoucherExpired.selector);
        nft.mintWithXP(1, 1, deadline, sig);
    }

    function test_X6_forged_signature_rejected() public {
        uint256 deadline = block.timestamp + 1 hours;
        // Signed by a random key, not the registered xpSigner.
        bytes32 digest = nft.hashXPMint(actors[0], 100, deadline);
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(0xBAD, digest);

        vm.prank(actors[0]);
        vm.expectRevert(OposNFT.InvalidXPSignature.selector);
        nft.mintWithXP(1, 100, deadline, abi.encodePacked(r, s, v));
    }

    function test_X7_tampered_allowance_rejected() public {
        uint256 deadline = block.timestamp + 1 hours;
        bytes memory sig = _voucher(actors[0], 1, deadline);

        // User tries to claim a bigger allowance than was signed.
        vm.prank(actors[0]);
        vm.expectRevert(OposNFT.InvalidXPSignature.selector);
        nft.mintWithXP(10, 10, deadline, sig);
    }

    function test_X8_disabled_when_signer_unset() public {
        vm.prank(owner);
        nft.setXPSigner(address(0));

        uint256 deadline = block.timestamp + 1 hours;
        bytes memory sig = _voucher(actors[0], 1, deadline);
        vm.prank(actors[0]);
        vm.expectRevert(OposNFT.XPMintDisabled.selector);
        nft.mintWithXP(1, 1, deadline, sig);
    }

    function test_X9_only_owner_sets_signer() public {
        vm.prank(actors[0]);
        vm.expectRevert();
        nft.setXPSigner(actors[0]);
    }

    function test_X10_amount_bounds() public {
        uint256 deadline = block.timestamp + 1 hours;
        bytes memory sig = _voucher(actors[0], 500, deadline);

        vm.prank(actors[0]);
        vm.expectRevert(bytes("Amount must be 1-200"));
        nft.mintWithXP(0, 500, deadline, sig);

        vm.prank(actors[0]);
        vm.expectRevert(bytes("Amount must be 1-200"));
        nft.mintWithXP(201, 500, deadline, sig);
    }
}
