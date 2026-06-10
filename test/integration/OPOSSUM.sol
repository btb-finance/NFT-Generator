// SPDX-License-Identifier: MIT
// Compatible with OpenZeppelin Contracts ^5.6.0
pragma solidity ^0.8.34;

// ─────────────────────────────────────────────────────────────────────────────
// TEST COPY of the real OPOSSUM token, vendored here so the integration suite
// exercises the distributor against the token's actual 1% transfer-tax logic
// instead of the plain MockOPOS. If the canonical token contract changes in
// its home repo, update this copy to match.
// ─────────────────────────────────────────────────────────────────────────────

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {ERC20Permit} from "@openzeppelin/contracts/token/ERC20/extensions/ERC20Permit.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

/// @custom:security-contact hello@btb.finance
contract OPOSSUM is ERC20, ERC20Permit, Ownable, ReentrancyGuard {
    using SafeERC20 for IERC20;

    /// @notice Underlying BTB token. Users mint OPOS by depositing BTB,
    ///         and burn OPOS to redeem BTB.
    IERC20 public immutable BTB_TOKEN;

    /// @notice 1 BTB mints this many OPOS (both 18-decimal). Conversion is exact at the unit level.
    uint256 public constant MINT_RATIO = 1_000_000;

    /// @notice Minimum BTB deposit per mint (1 BTB). Prevents spam and rounding dust.
    uint256 public constant MIN_BTB_DEPOSIT = 1e18;

    /// @notice Minimum OPOS burn per redemption (1,000,000 OPOS = 1 BTB worth).
    uint256 public constant MIN_OPOS_BURN = MIN_BTB_DEPOSIT * MINT_RATIO;

    /// @notice Address that receives the 1% transfer tax.
    address public treasury;

    /// @notice Tax rate in basis points (100 = 1%).
    uint256 public constant TAX_BPS = 100;
    uint256 private constant BPS_DENOMINATOR = 10_000;

    event Minted(address indexed user, uint256 btbAmount, uint256 oposAmount);
    event Burned(address indexed user, uint256 oposAmount, uint256 btbAmount);
    event TreasuryUpdated(address indexed oldTreasury, address indexed newTreasury);

    error TreasuryCannotBeZeroAddress();
    error InvalidBTBToken();
    error BelowMinimumDeposit();
    error BelowMinimumBurn();
    error AmountNotDivisibleByRatio();

    constructor(address btbToken, address treasury_, address initialOwner)
        ERC20("OPOSSUM", "OPOS")
        ERC20Permit("OPOSSUM")
        Ownable(initialOwner)
    {
        if (btbToken == address(0)) revert InvalidBTBToken();
        if (treasury_ == address(0)) revert TreasuryCannotBeZeroAddress();
        BTB_TOKEN = IERC20(btbToken);
        treasury = treasury_;
        emit TreasuryUpdated(address(0), treasury_);
    }

    /**
     * @notice Deposit BTB and mint OPOS at MINT_RATIO. Caller must approve BTB first.
     */
    function mint(uint256 btbAmount) external nonReentrant returns (uint256 oposAmount) {
        if (btbAmount < MIN_BTB_DEPOSIT) revert BelowMinimumDeposit();
        BTB_TOKEN.safeTransferFrom(msg.sender, address(this), btbAmount);
        oposAmount = btbAmount * MINT_RATIO;
        _mint(msg.sender, oposAmount);
        emit Minted(msg.sender, btbAmount, oposAmount);
    }

    /**
     * @notice Burn OPOS to redeem the underlying BTB at 1,000,000 OPOS → 1 BTB.
     * @dev oposAmount must be a multiple of MINT_RATIO; otherwise the call reverts to avoid dust.
     */
    function burn(uint256 oposAmount) external nonReentrant returns (uint256 btbAmount) {
        if (oposAmount < MIN_OPOS_BURN) revert BelowMinimumBurn();
        if (oposAmount % MINT_RATIO != 0) revert AmountNotDivisibleByRatio();
        btbAmount = oposAmount / MINT_RATIO;
        _burn(msg.sender, oposAmount);
        BTB_TOKEN.safeTransfer(msg.sender, btbAmount);
        emit Burned(msg.sender, oposAmount, btbAmount);
    }

    /**
     * @notice Update the treasury address. Only callable by the contract owner.
     * @param newTreasury The new address to receive transfer taxes. Cannot be zero.
     */
    function setTreasury(address newTreasury) external onlyOwner {
        if (newTreasury == address(0)) revert TreasuryCannotBeZeroAddress();
        address oldTreasury = treasury;
        treasury = newTreasury;
        emit TreasuryUpdated(oldTreasury, newTreasury);
    }

    /**
     * @dev Overrides the ERC20 _update hook to apply a 1% tax on every transfer.
     *
     * Exempt from tax:
     *  - Mints (from == address(0)): minting against a BTB deposit is untaxed.
     *  - Burns (to == address(0)): burning N OPOS destroys exactly N.
     *  - Treasury outflows (from == treasury): payouts from the treasury go out
     *    untaxed, and the treasury doesn't tax itself.
     */
    function _update(address from, address to, uint256 value) internal override(ERC20) {
        if (from == address(0) || to == address(0) || from == treasury) {
            super._update(from, to, value);
            return;
        }

        uint256 fee = (value * TAX_BPS) / BPS_DENOMINATOR;
        uint256 amountAfterFee = value - fee;

        if (fee > 0) {
            super._update(from, treasury, fee);
        }
        super._update(from, to, amountAfterFee);
    }
}
