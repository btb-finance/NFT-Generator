// SPDX-License-Identifier: MIT
pragma solidity ^0.8.34;

import {Test} from "forge-std/Test.sol";
import {OposNFT} from "../../../src/OposNFT.sol";
import {NFTRewardDistributor} from "../../../src/NFTRewardDistributor.sol";
import {MockOPOS} from "../../mocks/MockOPOS.sol";

/// @notice Bounded-randomness handler used by the invariant suite.
///         Exposes call shapes the invariant runner picks at random; each call
///         soaks up arbitrary uint256 inputs and bounds them to safe ranges.
///         try/catch is used liberally so a single revert doesn't block the run.
contract Handler is Test {
    OposNFT public nft;
    NFTRewardDistributor public dist;
    MockOPOS public opos;
    address public owner;
    address[5] public actors;

    /// @notice Total OPOS the distributor has ever received (ghost variable).
    ///         Used by the conservation invariant.
    uint256 public ghost_totalFeesReceived;

    /// @notice Highest tokenId successfully minted so far.
    uint256 public ghost_maxId;

    /// @notice Number of calls per handler function (debugging/coverage).
    mapping(bytes32 => uint256) public callCounts;

    constructor(
        OposNFT _nft,
        NFTRewardDistributor _dist,
        MockOPOS _opos,
        address _owner,
        address[5] memory _actors
    ) {
        nft = _nft;
        dist = _dist;
        opos = _opos;
        owner = _owner;
        actors = _actors;
    }

    // ─────────────────────────── handler actions ──────────────────────────

    function adminMint(uint256 amount) external {
        amount = bound(amount, 1, 50);
        if (nft.totalSupply() + amount > nft.MAX_SUPPLY()) return;
        callCounts[bytes32("adminMint")]++;
        vm.prank(owner);
        try nft.adminMint(amount) {
            ghost_maxId = nft.totalSupply();
        } catch {}
    }

    function buy(uint256 actorIdx, uint256 amount) external {
        actorIdx = bound(actorIdx, 0, actors.length - 1);
        amount = bound(amount, 1, 30);
        if (nft.totalSupply() + amount > nft.MAX_SUPPLY()) return;
        callCounts[bytes32("buy")]++;
        address buyer = actors[actorIdx];
        uint256 cost = nft.mintPrice() * amount;
        vm.deal(buyer, cost);
        vm.prank(buyer);
        try nft.buy{value: cost}(amount) {
            ghost_maxId = nft.totalSupply();
        } catch {}
    }

    function gift(uint256 numRecipients) external {
        numRecipients = bound(numRecipients, 1, 10);
        if (nft.totalSupply() + numRecipients > nft.MAX_SUPPLY()) return;
        callCounts[bytes32("gift")]++;
        address[] memory recipients = new address[](numRecipients);
        for (uint256 i = 0; i < numRecipients; ++i) {
            recipients[i] = actors[i % actors.length];
        }
        vm.prank(owner);
        try nft.giftNFT(recipients) {
            ghost_maxId = nft.totalSupply();
        } catch {}
    }

    function feeArrives(uint256 amount) external {
        amount = bound(amount, 1, 1000 ether);
        callCounts[bytes32("feeArrives")]++;
        opos.mintTo(address(dist), amount);
        ghost_totalFeesReceived += amount;
    }

    function syncDist() external {
        callCounts[bytes32("syncDist")]++;
        dist.sync();
    }

    function claim(uint256 actorIdx, uint256 idSeed) external {
        actorIdx = bound(actorIdx, 0, actors.length - 1);
        if (ghost_maxId == 0) return;
        uint256 id = bound(idSeed, 1, ghost_maxId);
        if (nft.ownerOf(id) != actors[actorIdx]) return;
        if (dist.asleep(id)) return;
        callCounts[bytes32("claim")]++;
        vm.prank(actors[actorIdx]);
        try dist.claim(id) {} catch {}
    }

    function reap(uint256 actorIdx, uint256 idSeed) external {
        actorIdx = bound(actorIdx, 0, actors.length - 1);
        if (ghost_maxId == 0) return;
        uint256 id = bound(idSeed, 1, ghost_maxId);
        if (dist.asleep(id)) return;
        if (block.timestamp < dist.lastActivityAt(id) + dist.SLEEP_THRESHOLD()) return;
        callCounts[bytes32("reap")]++;
        vm.prank(actors[actorIdx]);
        try dist.reap(id) {} catch {}
    }

    function wake(uint256 actorIdx, uint256 idSeed) external {
        actorIdx = bound(actorIdx, 0, actors.length - 1);
        if (ghost_maxId == 0) return;
        uint256 id = bound(idSeed, 1, ghost_maxId);
        if (!dist.asleep(id)) return;
        if (nft.ownerOf(id) != actors[actorIdx]) return;
        callCounts[bytes32("wake")]++;
        vm.prank(actors[actorIdx]);
        try dist.wake(id) {} catch {}
    }

    function transferNFT(uint256 fromIdx, uint256 toIdx, uint256 idSeed) external {
        fromIdx = bound(fromIdx, 0, actors.length - 1);
        toIdx = bound(toIdx, 0, actors.length - 1);
        if (fromIdx == toIdx) return;
        if (ghost_maxId == 0) return;
        uint256 id = bound(idSeed, 1, ghost_maxId);
        if (nft.ownerOf(id) != actors[fromIdx]) return;
        callCounts[bytes32("transferNFT")]++;
        vm.prank(actors[fromIdx]);
        try nft.transferFrom(actors[fromIdx], actors[toIdx], id) {} catch {}
    }

    function warpTime(uint256 secs) external {
        secs = bound(secs, 1 hours, 200 days);
        callCounts[bytes32("warpTime")]++;
        vm.warp(block.timestamp + secs);
    }
}
