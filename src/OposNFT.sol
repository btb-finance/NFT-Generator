// SPDX-License-Identifier: MIT
// Compatible with OpenZeppelin Contracts ^5.6.0
pragma solidity ^0.8.34;

import {ERC721} from "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import {ERC2981} from "@openzeppelin/contracts/token/common/ERC2981.sol";
import {IERC4906} from "@openzeppelin/contracts/interfaces/IERC4906.sol";
import {IERC165} from "@openzeppelin/contracts/utils/introspection/IERC165.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {Base64} from "@openzeppelin/contracts/utils/Base64.sol";
import {Strings} from "@openzeppelin/contracts/utils/Strings.sol";
import {ECDSA} from "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import {EIP712} from "@openzeppelin/contracts/utils/cryptography/EIP712.sol";

interface IOposRenderer {
    // `view`, not `pure`: the renderer reads its sibling palette/parts
    // contracts. Still a read-only STATICCALL from tokenURI.
    function buildArt(uint256 seed) external view returns (string memory);
}

interface IRewardDistributorView {
    function pending(uint256 tokenId) external view returns (uint256);
    function lifetimeEarned(uint256 tokenId) external view returns (uint256);
    function asleep(uint256 tokenId) external view returns (bool);
}

interface IRewardDistributorMint {
    function onMintBatch(uint256[] calldata tokenIds) external;
}

interface IRewardDistributorClaim {
    function claimFor(address user, uint256 tokenId) external;
    function claimManyFor(address user, uint256[] calldata tokenIds) external;
    function wakeFor(address user, uint256 tokenId) external;
    function wakeManyFor(address user, uint256[] calldata tokenIds) external;
    function asleep(uint256 tokenId) external view returns (bool);
    function isReapable(uint256 tokenId) external view returns (bool);
    function secondsUntilStale(uint256 tokenId) external view returns (uint256);
}

/**
 * @title OposNFT
 * @dev OPOSSUM-ecosystem NFT collection. Fully on-chain SVG art via OposRenderer,
 *      ERC-2981 royalties for marketplaces, ERC-4906 metadata-update events for
 *      live yield display, and per-token OPOS yield via the NFTRewardDistributor.
 */
contract OposNFT is ERC721, ERC2981, IERC4906, Ownable, ReentrancyGuard, EIP712 {
    using Strings for uint256;

    uint256 private _tokenIdCounter = 1; // Start from 1, not 0
    mapping(uint256 => uint256) private tokenTraits;
    IOposRenderer public renderer;

    /// @notice Distributor contract that holds OPOS rewards and tracks per-NFT yield.
    ///         Set after deployment via setDistributor.
    IRewardDistributorView public distributor;

    // Supply and pricing
    uint256 public constant MAX_SUPPLY = 88888;
    uint256 public mintPrice = 0.0002 ether; // Default price, can be updated

    // Events
    event MintPriceUpdated(uint256 newPrice);
    event NFTPurchased(address indexed buyer, uint256 amount, uint256 totalCost);
    event DistributorUpdated(address indexed oldDistributor, address indexed newDistributor);
    event RefundFailed(address indexed buyer, uint256 amount);

    constructor(address _renderer)
        ERC721("OPOSSUM NFT", "OPOSN")
        EIP712("OPOSSUM NFT", "1")
        Ownable(msg.sender)
    {
        renderer = IOposRenderer(_renderer);
        // Set 5% royalty fee to contract owner
        _setDefaultRoyalty(msg.sender, 500); // 500 basis points = 5%
    }

    function setRenderer(address _renderer) external onlyOwner {
        require(_renderer != address(0), "Renderer cannot be zero");
        renderer = IOposRenderer(_renderer);
    }

    /**
     * @dev Wire up the OPOS reward distributor. Once set, `tokenURI` will display
     *      claimable + lifetime OPOS as integer traits, and the distributor may
     *      emit ERC-4906 metadata-update events through this contract.
     */
    function setDistributor(address _distributor) external onlyOwner {
        require(_distributor != address(0), "Distributor cannot be zero");
        require(_tokenIdCounter == 1, "Cannot change distributor after minting begins");
        address old = address(distributor);
        distributor = IRewardDistributorView(_distributor);
        emit DistributorUpdated(old, _distributor);
        emit BatchMetadataUpdate(1, MAX_SUPPLY);
    }

    // ───────────── Reward facade — call these instead of the distributor ─────────────
    // Holders who only know the NFT contract can claim, wake, and read their
    // pending rewards through these functions. Each one forwards to the
    // distributor with `msg.sender` as the user, so the user is the one
    // verified as owner and the one receiving the OPOS.

    /// @notice Claim OPOS rewards for one tokenId. Owner-only.
    function claim(uint256 tokenId) external {
        _requireDistributor().claimFor(msg.sender, tokenId);
    }

    /// @notice Claim OPOS rewards for many tokenIds in one tx. Owner-only.
    function claimMany(uint256[] calldata tokenIds) external {
        _requireDistributor().claimManyFor(msg.sender, tokenIds);
    }

    /// @notice Wake a previously-reaped NFT so it earns again. Owner-only.
    function wake(uint256 tokenId) external {
        _requireDistributor().wakeFor(msg.sender, tokenId);
    }

    /// @notice Wake many previously-reaped NFTs in one tx. Owner-only.
    function wakeMany(uint256[] calldata tokenIds) external {
        _requireDistributor().wakeManyFor(msg.sender, tokenIds);
    }

    /// @notice Pending OPOS reward (in wei) for `tokenId`. 0 if asleep.
    function pendingReward(uint256 tokenId) external view returns (uint256) {
        IRewardDistributorView dist = distributor;
        if (address(dist) == address(0)) return 0;
        return dist.pending(tokenId);
    }

    /// @notice Lifetime OPOS earned (claimed + currently pending) for `tokenId`.
    function lifetimeReward(uint256 tokenId) external view returns (uint256) {
        IRewardDistributorView dist = distributor;
        if (address(dist) == address(0)) return 0;
        return dist.lifetimeEarned(tokenId);
    }

    /// @notice True if this NFT has been reaped and is currently dormant.
    function isAsleep(uint256 tokenId) external view returns (bool) {
        IRewardDistributorView dist = distributor;
        if (address(dist) == address(0)) return false;
        return dist.asleep(tokenId);
    }

    function _requireDistributor() private view returns (IRewardDistributorClaim) {
        address dist = address(distributor);
        require(dist != address(0), "Distributor not set");
        return IRewardDistributorClaim(dist);
    }

    /// @dev Distributor-only proxy so it can signal a single-token metadata refresh.
    function emitMetadataUpdate(uint256 tokenId) external {
        require(msg.sender == address(distributor), "Not distributor");
        emit MetadataUpdate(tokenId);
    }

    /// @dev Distributor-only proxy for full-collection metadata refresh.
    function emitBatchMetadataUpdate() external {
        require(msg.sender == address(distributor), "Not distributor");
        emit BatchMetadataUpdate(1, MAX_SUPPLY);
    }

    /**
     * @dev Set the mint price (admin only)
     * @param _price New price in wei
     */
    function setMintPrice(uint256 _price) external onlyOwner {
        mintPrice = _price;
        emit MintPriceUpdated(_price);
    }

    /**
     * @dev Admin mint - FREE minting for owner only
     * @param amount Number of NFTs to mint (max 200 per transaction)
     */
    function adminMint(uint256 amount) external onlyOwner nonReentrant {
        require(amount > 0 && amount <= 200, "Amount must be 1-200");
        // The last id minted will be `_tokenIdCounter + amount - 1`; that must be ≤ MAX_SUPPLY.
        require(_tokenIdCounter + amount - 1 <= MAX_SUPPLY, "Exceeds max supply");

        uint256[] memory ids = new uint256[](amount);
        for (uint256 i = 0; i < amount; i++) {
            uint256 tokenId = _tokenIdCounter++;
            uint256 traits = _generateTraits(tokenId);
            tokenTraits[tokenId] = traits;
            ids[i] = tokenId;
            _safeMint(msg.sender, tokenId);
        }
        _notifyDistributor(ids);
        emit BatchMetadataUpdate(ids[0], ids[ids.length - 1]);
    }

    /**
     * @dev Gift one NFT to each address in `recipients`. Owner-only.
     *      Use case: airdrops, giveaways, whitelist rewards.
     *      Mints are still random — each recipient gets a fresh random NFT.
     * @param recipients Up to 500 addresses; each receives exactly one NFT.
     */
    function giftNFT(address[] calldata recipients) external onlyOwner nonReentrant {
        uint256 len = recipients.length;
        require(len > 0 && len <= 500, "Recipients must be 1-500");
        // Last minted id must be ≤ MAX_SUPPLY.
        require(_tokenIdCounter + len - 1 <= MAX_SUPPLY, "Exceeds max supply");

        uint256[] memory ids = new uint256[](len);
        for (uint256 i = 0; i < len; i++) {
            address to = recipients[i];
            require(to != address(0), "Zero recipient");
            uint256 tokenId = _tokenIdCounter++;
            uint256 traits = _generateTraits(tokenId);
            tokenTraits[tokenId] = traits;
            ids[i] = tokenId;
            // Use _mint (no onERC721Received callback) so a single recipient
            // contract that doesn't implement IERC721Receiver doesn't grief
            // the entire airdrop. Owner is responsible for vetting recipients.
            _mint(to, tokenId);
        }
        _notifyDistributor(ids);
        emit BatchMetadataUpdate(ids[0], ids[ids.length - 1]);
    }

    /**
     * @dev Public buy function - Users buy NFTs with ETH
     * @param amount Number of NFTs to buy (max 500 per transaction)
     */
    function buy(uint256 amount) external payable nonReentrant {
        require(amount > 0 && amount <= 500, "Amount must be 1-500");
        // Last minted id must be ≤ MAX_SUPPLY.
        require(_tokenIdCounter + amount - 1 <= MAX_SUPPLY, "Exceeds max supply");

        uint256 totalCost = mintPrice * amount;
        require(msg.value >= totalCost, "Insufficient ETH sent");

        uint256[] memory ids = new uint256[](amount);
        for (uint256 i = 0; i < amount; i++) {
            uint256 tokenId = _tokenIdCounter++;
            uint256 traits = _generateTraits(tokenId);
            tokenTraits[tokenId] = traits;
            ids[i] = tokenId;
            _safeMint(msg.sender, tokenId);
        }
        _notifyDistributor(ids);
        emit BatchMetadataUpdate(ids[0], ids[ids.length - 1]);

        emit NFTPurchased(msg.sender, amount, totalCost);

        // Refund excess ETH. We do not revert on failure — a reverting receive()
        // on the buyer's side must not undo the entire mint. The buyer can recover
        // excess ETH by other means; their NFTs are already minted.
        if (msg.value > totalCost) {
            (bool ok, ) = payable(msg.sender).call{value: msg.value - totalCost}("");
            if (!ok) emit RefundFailed(msg.sender, msg.value - totalCost);
        }
    }

    // ───────────── XP mint — free mints earned in the BTB app ─────────────
    // Users earn XP off-chain; the backend converts spendable XP into an
    // EIP-712 voucher signed by `xpSigner`: "this wallet may mint up to
    // `totalAllowed` NFTs, lifetime". The allowance is CUMULATIVE, so
    // replaying an old voucher can never mint more than the backend approved
    // — when a user earns more XP, the backend simply signs a higher total.

    /// @notice Backend key that signs XP-mint vouchers. address(0) = disabled.
    address public xpSigner;

    /// @notice Lifetime NFTs minted via XP vouchers, per wallet.
    mapping(address => uint256) public xpMinted;

    bytes32 private constant XP_MINT_TYPEHASH =
        keccak256("XPMint(address user,uint256 totalAllowed,uint256 deadline)");

    event XPSignerUpdated(address indexed oldSigner, address indexed newSigner);
    event XPMinted(address indexed user, uint256 amount, uint256 totalAllowed);

    error XPMintDisabled();
    error XPVoucherExpired();
    error InvalidXPSignature();
    error ExceedsXPAllowance();

    /// @notice Set (or rotate) the backend voucher signer. Zero disables XP
    ///         minting — e.g., immediately after a backend key leak.
    function setXPSigner(address newSigner) external onlyOwner {
        address old = xpSigner;
        xpSigner = newSigner;
        emit XPSignerUpdated(old, newSigner);
    }

    /// @notice EIP-712 digest the backend must sign for an XP voucher. Exposed
    ///         so the backend/frontend can build signatures without
    ///         re-implementing the domain separator.
    function hashXPMint(address user, uint256 totalAllowed, uint256 deadline)
        public
        view
        returns (bytes32)
    {
        return _hashTypedDataV4(
            keccak256(abi.encode(XP_MINT_TYPEHASH, user, totalAllowed, deadline))
        );
    }

    /**
     * @notice Free mint against an XP voucher signed by the backend.
     * @param amount       NFTs to mint now (1-200 per tx).
     * @param totalAllowed Lifetime cap the voucher grants this wallet.
     * @param deadline     Voucher expiry timestamp.
     * @param signature    xpSigner's EIP-712 signature over (caller, totalAllowed, deadline).
     */
    function mintWithXP(
        uint256 amount,
        uint256 totalAllowed,
        uint256 deadline,
        bytes calldata signature
    ) external nonReentrant {
        if (xpSigner == address(0)) revert XPMintDisabled();
        if (block.timestamp > deadline) revert XPVoucherExpired();
        require(amount > 0 && amount <= 200, "Amount must be 1-200");
        // Last minted id must be ≤ MAX_SUPPLY.
        require(_tokenIdCounter + amount - 1 <= MAX_SUPPLY, "Exceeds max supply");

        bytes32 digest = hashXPMint(msg.sender, totalAllowed, deadline);
        if (ECDSA.recover(digest, signature) != xpSigner) revert InvalidXPSignature();

        uint256 used = xpMinted[msg.sender];
        if (used + amount > totalAllowed) revert ExceedsXPAllowance();
        xpMinted[msg.sender] = used + amount;

        uint256[] memory ids = new uint256[](amount);
        for (uint256 i = 0; i < amount; i++) {
            uint256 tokenId = _tokenIdCounter++;
            uint256 traits = _generateTraits(tokenId);
            tokenTraits[tokenId] = traits;
            ids[i] = tokenId;
            _safeMint(msg.sender, tokenId);
        }
        _notifyDistributor(ids);
        emit BatchMetadataUpdate(ids[0], ids[ids.length - 1]);
        emit XPMinted(msg.sender, amount, totalAllowed);
    }

    /**
     * @dev Tells the distributor about freshly-minted tokenIds so it can
     *      checkpoint per-tier reward indices. Reverts if the distributor is
     *      unset: setDistributor is locked once minting begins, so allowing a
     *      mint without it would permanently disable the yield system.
     */
    function _notifyDistributor(uint256[] memory ids) private {
        IRewardDistributorView dist = distributor;
        require(address(dist) != address(0), "Distributor not set");
        IRewardDistributorMint(address(dist)).onMintBatch(ids);
    }

    /**
     * @dev Public tier index for a tokenId: 0=Mythic, 1=Legendary, 2=Epic,
     *      3=Rare, 4=Common. The distributor reads this to route rewards.
     */
    function tierIndexOf(uint256 tokenId) external view returns (uint8) {
        _requireOwned(tokenId); // reverts ERC721NonexistentToken on bad id
        return _getRarityIndex(tokenTraits[tokenId]);
    }

    /**
     * @dev Withdraw collected ETH (admin only)
     */
    function withdraw() external onlyOwner {
        uint256 balance = address(this).balance;
        require(balance > 0, "No funds to withdraw");
        // Use call() so a Safe/multisig owner can receive ETH (transfer's 2300
        // gas stipend is too tight for non-trivial receive() handlers).
        (bool ok, ) = payable(owner()).call{value: balance}("");
        require(ok, "Withdraw failed");
    }

    // ───────────── Guaranteed-unique trait generation ─────────────
    //
    // The art reads exactly six fields out of a token's seed:
    //   body 30 · expression 10 · pattern 10 · accessory 15 · eye 20 · background 7
    // = 6,300,000 distinct opossums. Drawing those at random from a hash gave
    // ~617 duplicate pictures across 88,888 tokens — that is the birthday
    // problem, not a bug, and no amount of extra hashing fixes it.
    //
    // So the seed is no longer drawn at random. Each tokenId is mapped through
    // a PERMUTATION of [0, 6,300,000) — a bijection, so two different tokenIds
    // can never land on the same combination. The resulting combination is then
    // encoded back into a seed that the existing extraction logic decodes to
    // exactly those six traits, which is why nothing downstream had to change.
    //
    // Duplicates are now impossible by construction rather than unlikely.

    uint256 private constant TRAIT_COMBINATIONS = 6_300_000;

    /// @dev Feistel domain: the smallest power of two above TRAIT_COMBINATIONS,
    ///      split into two 12-bit halves.
    uint256 private constant FEISTEL_DOMAIN = 1 << 24;
    uint256 private constant HALF_MASK = 0xFFF;

    /// @dev Fixed domain separator. Changing it reshuffles which tokenId gets
    ///      which opossum, so it must never change after launch.
    bytes32 private constant TRAIT_SALT = keccak256("OPOSSUM.traits.v1");

    error TraitPermutationFailed();

    /**
     * @notice The trait seed for `tokenId`. Pure and public so a frontend can
     *         render a token without touching chain state.
     */
    function traitSeedOf(uint256 tokenId) public pure returns (uint256) {
        uint256 combination = _permute(tokenId);

        // Split the combination index into the six trait values. This is a
        // mixed-radix decomposition, so it is one-to-one.
        uint256 background = combination % 7;
        combination /= 7;
        uint256 eye = combination % 20;
        combination /= 20;
        uint256 accessory = combination % 15;
        combination /= 15;
        uint256 pattern = combination % 10;
        combination /= 10;
        uint256 expression = combination % 10;
        combination /= 10;
        uint256 body = combination % 30;

        return _encodeSeed(body, expression, pattern, accessory, eye, background);
    }

    /**
     * @dev Bijection on [0, TRAIT_COMBINATIONS). A 4-round Feistel network
     *      permutes [0, 2^24); cycle-walking (re-applying it until the value
     *      lands back inside the real range) narrows that to a permutation of
     *      exactly our domain. Each step is a bijection, so the composition is.
     *
     *      Roughly 2.7 walks are needed on average (2^24 / 6.3M). The bound of
     *      256 makes failure a ~1e-52 event; reverting rather than falling back
     *      keeps the uniqueness guarantee absolute.
     */
    function _permute(uint256 tokenId) private pure returns (uint256) {
        uint256 v = tokenId;
        for (uint256 i = 0; i < 256; ++i) {
            uint256 l = v >> 12;
            uint256 r = v & HALF_MASK;
            for (uint256 round = 0; round < 4; ++round) {
                uint256 f = uint256(keccak256(abi.encodePacked(r, round, TRAIT_SALT))) & HALF_MASK;
                (l, r) = (r, l ^ f);
            }
            v = ((l << 12) | r) % FEISTEL_DOMAIN;
            if (v < TRAIT_COMBINATIONS) return v;
        }
        revert TraitPermutationFailed();
    }

    /**
     * @dev Builds a seed that decodes to exactly the six given traits.
     *
     *      The extractors read overlapping bit ranges (`seed % 30`,
     *      `(seed >> 8) % 10`, ...), and because the moduli are not powers of
     *      two, every byte leaks upward into the fields below it. So the bytes
     *      are solved from the top down, each one chosen to cancel the leakage
     *      from the bytes already fixed above it. A solution always exists
     *      because a byte ranges over 256 values and every modulus is <= 30.
     */
    function _encodeSeed(
        uint256 body,
        uint256 expression,
        uint256 pattern,
        uint256 accessory,
        uint256 eye,
        uint256 background
    ) private pure returns (uint256) {
        uint256 acc = background;                       // byte 5 -> background
        acc = (acc << 8) | _solve(eye, acc, 20);        // byte 4 -> eye
        acc = (acc << 8) | _solve(accessory, acc, 15);  // byte 3 -> accessory
        acc = (acc << 8) | _solve(pattern, acc, 10);    // byte 2 -> pattern
        acc = (acc << 8) | _solve(expression, acc, 10); // byte 1 -> expression
        acc = (acc << 8) | _solve(body, acc, 30);       // byte 0 -> body
        return acc;
    }

    /// @dev The byte value b < m such that (b + higher * 256) % m == target.
    function _solve(uint256 target, uint256 higher, uint256 m) private pure returns (uint256) {
        return (target + m - ((higher * 256) % m)) % m;
    }

    function _generateTraits(uint256 tokenId) private pure returns (uint256) {
        return traitSeedOf(tokenId);
    }

    /**
     * @dev Build the on-chain JSON metadata: SVG image + traits + live OPOS yield.
     */
    function tokenURI(uint256 tokenId) public view override returns (string memory) {
        _requireOwned(tokenId); // reverts ERC721NonexistentToken on bad id

        string memory svg = renderer.buildArt(tokenTraits[tokenId]);
        string memory rarity = _getRarityTier(tokenTraits[tokenId]);
        string memory json = string(abi.encodePacked(
            '{"name":"OPOSSUM ', rarity, ' #', tokenId.toString(), '",',
            '"description":"88,888 fully on-chain OPOSSUM NFTs. Every holder earns a 1/88,888 share of every OPOS transfer tax in real time, claimable on demand.",',
            '"attributes":[',
            _getAttributes(tokenId, tokenTraits[tokenId]),
            ',',
            _getYieldAttributes(tokenId),
            '],',
            '"image":"data:image/svg+xml;base64,', Base64.encode(bytes(svg)), '"}'
        ));

        return string(abi.encodePacked("data:application/json;base64,", Base64.encode(bytes(json))));
    }

    /**
     * @dev Builds the two OPOS yield traits as numeric (decimal-stripped) values.
     *      Returns "0" for both if no distributor is wired up yet, so the
     *      attribute shape stays stable across the contract's lifetime.
     */
    function _getYieldAttributes(uint256 tokenId) private view returns (string memory) {
        uint256 claimableWhole;
        uint256 lifetimeWhole;
        string memory status = "Active";
        IRewardDistributorView dist = distributor;
        if (address(dist) != address(0)) {
            claimableWhole = dist.pending(tokenId) / 1e18;
            lifetimeWhole = dist.lifetimeEarned(tokenId) / 1e18;
            if (dist.asleep(tokenId)) status = "Asleep";
        }
        return string(abi.encodePacked(
            '{"trait_type":"Status","value":"', status, '"},',
            '{"trait_type":"Claimable OPOS","value":"', _formatAmount(claimableWhole), '"},',
            '{"trait_type":"Lifetime OPOS","value":"', _formatAmount(lifetimeWhole), '"}'
        ));
    }

    /**
     * @dev Format a whole-token amount with K/M/B suffix to one decimal place.
     *      Examples: 0 → "0", 950 → "950", 1_500 → "1.5K",
     *                1_100_000 → "1.1M", 2_500_000_000 → "2.5B".
     *      Trims a trailing ".0" so "1.0M" displays as "1M".
     */
    function _formatAmount(uint256 n) private pure returns (string memory) {
        if (n >= 1_000_000_000) return string(abi.encodePacked(_decimalPart(n, 1_000_000_000), "B"));
        if (n >= 1_000_000)     return string(abi.encodePacked(_decimalPart(n, 1_000_000),     "M"));
        if (n >= 1_000)         return string(abi.encodePacked(_decimalPart(n, 1_000),         "K"));
        return n.toString();
    }

    function _decimalPart(uint256 n, uint256 unit) private pure returns (string memory) {
        uint256 integerPart = n / unit;
        uint256 oneDecimal = (n % unit) * 10 / unit;
        if (oneDecimal == 0) return integerPart.toString();
        return string(abi.encodePacked(integerPart.toString(), ".", oneDecimal.toString()));
    }

    function _getAttributes(uint256 tokenId, uint256 seed) private pure returns (string memory) {
        return string(abi.encodePacked(
            '{"trait_type":"Rarity","value":"', _getRarityTier(seed), '"},',
            '{"trait_type":"Generation","value":"', _getGeneration(tokenId), '"},',
            '{"trait_type":"Body","value":"', _getBodyName(seed), '"},',
            '{"trait_type":"Eyes","value":"', _getEyeName(seed), '"},',
            '{"trait_type":"Expression","value":"', _getExpressionName(seed), '"},',
            '{"trait_type":"Pattern","value":"', _getPatternName(seed), '"},',
            '{"trait_type":"Accessory","value":"', _getAccessoryName(seed), '"},',
            '{"trait_type":"Background","value":"', _getBackgroundName(seed), '"}'
        ));
    }

    /**
     * @dev Generation is a permanent, per-token badge fixed by mint order
     *      (the token's own id), NOT by current collection supply — so it
     *      never changes after mint and differs across early/late tokens.
     * Genesis: 1-17,777 (first 17,777 NFTs)
     * Alpha: 17,778-35,555 (next 17,777 NFTs)
     * Beta: 35,556-53,332 (next 17,777 NFTs)
     * Gamma: 53,333-71,110 (next 17,777 NFTs)
     * Delta: 71,111-88,888 (last 17,778 NFTs)
     */
    function _getGeneration(uint256 tokenId) private pure returns (string memory) {
        if (tokenId <= 17777) return "Genesis";
        if (tokenId <= 35555) return "Alpha";
        if (tokenId <= 53332) return "Beta";
        if (tokenId <= 71110) return "Gamma";
        return "Delta";
    }

    /**
     * @dev Calculate rarity tier based on trait combinations
     * Out of 88,888 total supply:
     * Mythic: ~1% (~889 NFTs) - Golden Crown/Wizard Hat + Rainbow/Chrome/Rose Gold body
     * Legendary: ~4% (~3,556 NFTs) - Golden Crown, Wizard Hat, or rare body colors
     * Epic: ~10% (~8,889 NFTs) - Multiple rare traits
     * Rare: ~20% (~17,778 NFTs) - At least one rare trait
     * Common: ~65% (~57,777 NFTs) - Standard traits
     */
    function _getRarityTier(uint256 seed) private pure returns (string memory) {
        uint8 idx = _getRarityIndex(seed);
        if (idx == 0) return "Mythic";
        if (idx == 1) return "Legendary";
        if (idx == 2) return "Epic";
        if (idx == 3) return "Rare";
        return "Common";
    }

    /**
     * @dev Returns the tier index from a trait seed: 0=Mythic, 1=Legendary,
     *      2=Epic, 3=Rare, 4=Common. Mirrors the score logic in `_getRarityTier`.
     */
    function _getRarityIndex(uint256 seed) private pure returns (uint8) {
        // All casts are safe because we mod by small values
        // forge-lint: disable-next-line(unsafe-typecast)
        uint8 bodyIndex = uint8(seed % 30);
        // forge-lint: disable-next-line(unsafe-typecast)
        uint8 accessoryIndex = uint8((seed >> 24) % 15);
        // forge-lint: disable-next-line(unsafe-typecast)
        uint8 eyeIndex = uint8((seed >> 32) % 20);
        // forge-lint: disable-next-line(unsafe-typecast)
        uint8 patternIndex = uint8((seed >> 16) % 10);

        uint8 rarityScore = 0;

        // Ultra rare bodies (Rainbow, Chrome, Rose Gold, Diamond, Galaxy)
        if (bodyIndex == 10 || bodyIndex == 8 || bodyIndex == 19 || bodyIndex >= 27) {
            rarityScore += 3;
        }
        // Rare bodies (Golden, Burgundy, Navy, Emerald, Cosmic, Neon)
        else if (bodyIndex == 6 || bodyIndex == 16 || bodyIndex == 17 || bodyIndex == 18 || bodyIndex >= 24) {
            rarityScore += 2;
        }

        // Legendary accessories (Golden Crown, Wizard Hat, Halo)
        if (accessoryIndex == 8 || accessoryIndex == 9 || accessoryIndex >= 13) {
            rarityScore += 3;
        }
        // Rare accessories (Crown, Top Hat, Astronaut Helmet, Monocle, Cape)
        else if (accessoryIndex == 1 || accessoryIndex == 2 || accessoryIndex == 6 || accessoryIndex == 11 || accessoryIndex == 12) {
            rarityScore += 2;
        }

        // Rare eyes (Gold, Silver, Indigo, Rainbow, Laser)
        if (eyeIndex == 2 || eyeIndex == 11 || eyeIndex == 13 || eyeIndex >= 17) {
            rarityScore += 1;
        }

        // Rare patterns (Calico, Tiger Stripes, Galaxy, Flames)
        if (patternIndex == 7 || patternIndex == 5 || patternIndex >= 8) {
            rarityScore += 1;
        }

        // Determine tier index based on score
        if (rarityScore >= 6) return 0;  // Mythic     (~1%  = ~889 NFTs)
        if (rarityScore >= 4) return 1;  // Legendary  (~4%  = ~3,556 NFTs)
        if (rarityScore >= 3) return 2;  // Epic       (~10% = ~8,889 NFTs)
        if (rarityScore >= 1) return 3;  // Rare       (~20% = ~17,778 NFTs)
        return 4;                         // Common     (~65% = ~57,776 NFTs)
    }

    function _getBodyName(uint256 seed) private pure returns (string memory) {
        // Casting to uint8 is safe because we mod by 30, max value is 29
        // forge-lint: disable-next-line(unsafe-typecast)
        uint8 i = uint8(seed % 30);
        if (i == 0) return "Orange";
        if (i == 1) return "Black";
        if (i == 2) return "White";
        if (i == 3) return "Gray";
        if (i == 4) return "Siamese";
        if (i == 5) return "Blue";
        if (i == 6) return "Golden";
        if (i == 7) return "Pink";
        if (i == 8) return "Chrome";
        if (i == 9) return "Brown";
        if (i == 10) return "Rainbow";
        if (i == 11) return "Lavender";
        if (i == 12) return "Mint";
        if (i == 13) return "Coral";
        if (i == 14) return "Teal";
        if (i == 15) return "Peach";
        if (i == 16) return "Burgundy";
        if (i == 17) return "Navy";
        if (i == 18) return "Emerald";
        if (i == 19) return "Rose Gold";
        if (i == 20) return "Crimson";
        if (i == 21) return "Turquoise";
        if (i == 22) return "Violet";
        if (i == 23) return "Olive";
        if (i == 24) return "Cosmic Purple";
        if (i == 25) return "Neon Green";
        if (i == 26) return "Sunset Orange";
        if (i == 27) return "Diamond";
        if (i == 28) return "Galaxy";
        return "Holographic";
    }

    function _getEyeName(uint256 seed) private pure returns (string memory) {
        // forge-lint: disable-next-line(unsafe-typecast)
        uint8 i = uint8((seed >> 32) % 20);
        if (i == 0) return "Green";
        if (i == 1) return "Blue";
        if (i == 2) return "Gold";
        if (i == 3) return "Pink";
        if (i == 4) return "Brown";
        if (i == 5) return "Cyan";
        if (i == 6) return "Red";
        if (i == 7) return "Purple";
        if (i == 8) return "Amber";
        if (i == 9) return "Violet";
        if (i == 10) return "Turquoise";
        if (i == 11) return "Silver";
        if (i == 12) return "Lime";
        if (i == 13) return "Indigo";
        if (i == 14) return "Orange";
        if (i == 15) return "Sapphire";
        if (i == 16) return "Emerald";
        if (i == 17) return "Rainbow";
        if (i == 18) return "Laser Red";
        return "Cosmic Blue";
    }

    function _getExpressionName(uint256 seed) private pure returns (string memory) {
        uint8 i = uint8((seed >> 8) % 10);
        if (i == 0) return "Happy";
        if (i == 1) return "Sleepy";
        if (i == 2) return "Winking";
        if (i == 3) return "Surprised";
        if (i == 4) return "Grumpy";
        if (i == 5) return "Loving";
        if (i == 6) return "Excited";
        if (i == 7) return "Shy";
        if (i == 8) return "Curious";
        return "Normal";
    }

    function _getPatternName(uint256 seed) private pure returns (string memory) {
        // forge-lint: disable-next-line(unsafe-typecast)
        uint8 i = uint8((seed >> 16) % 10);
        if (i == 0) return "None";
        if (i == 1) return "Striped";
        if (i == 2) return "Spotted";
        if (i == 3) return "Tuxedo";
        if (i == 4) return "Patches";
        if (i == 5) return "Tiger Stripes";
        if (i == 6) return "Gradient";
        if (i == 7) return "Calico";
        if (i == 8) return "Galaxy Swirl";
        return "Flames";
    }

    function _getAccessoryName(uint256 seed) private pure returns (string memory) {
        // forge-lint: disable-next-line(unsafe-typecast)
        uint8 i = uint8((seed >> 24) % 15);
        if (i == 0) return "None";
        if (i == 1) return "Crown";
        if (i == 2) return "Top Hat";
        if (i == 3) return "Bow Tie";
        if (i == 4) return "Sunglasses";
        if (i == 5) return "Bandana";
        if (i == 6) return "Astronaut Helmet";
        if (i == 7) return "Pirate Eye Patch";
        if (i == 8) return "Golden Crown";
        if (i == 9) return "Wizard Hat";
        if (i == 10) return "Flower Crown";
        if (i == 11) return "Monocle";
        if (i == 12) return "Cape";
        if (i == 13) return "Halo";
        return "Headphones";
    }

    function _getBackgroundName(uint256 seed) private pure returns (string memory) {
        uint8 i = uint8((seed >> 40) % 7);
        if (i == 0) return "Sky Blue";
        if (i == 1) return "Pink Dream";
        if (i == 2) return "Forest Green";
        if (i == 3) return "Night Sky";
        if (i == 4) return "Purple Nebula";
        if (i == 5) return "Sunset Orange";
        return "Hot Pink";
    }

    function totalSupply() external view returns (uint256) {
        // _tokenIdCounter starts at 1 and is incremented AFTER assigning a tokenId,
        // so it always equals (last minted id + 1). Subtract 1 for actual count.
        return _tokenIdCounter - 1;
    }

    /**
     * @dev Update royalty info (owner only)
     * @param receiver Address to receive royalties
     * @param feeNumerator Fee in basis points (500 = 5%)
     */
    function setDefaultRoyalty(address receiver, uint96 feeNumerator) external onlyOwner {
        require(feeNumerator <= 500, "Royalty cannot exceed 5%");
        _setDefaultRoyalty(receiver, feeNumerator);
    }

    /**
     * @dev Override supportsInterface to include ERC2981
     */
    function supportsInterface(bytes4 interfaceId)
        public
        view
        override(ERC721, ERC2981, IERC165)
        returns (bool)
    {
        // 0x49064906 = ERC-4906 (MetadataUpdate / BatchMetadataUpdate).
        return interfaceId == bytes4(0x49064906) || super.supportsInterface(interfaceId);
    }
}
