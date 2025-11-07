# Pixel Cats - Fully On-Chain NFT Guide

## What Does "Fully On-Chain" Mean?

Your Pixel Cats NFTs will be **100% on the blockchain** - forever. This means:

- ✅ **No IPFS dependencies** - Images never disappear
- ✅ **No server hosting** - No maintenance required
- ✅ **Permanent** - As long as Ethereum exists, your NFTs exist
- ✅ **Verifiable** - Anyone can verify the art is truly on-chain
- ✅ **Gas efficient** - Smart trait encoding (32 bytes per NFT)

## How It Works

### 1. Trait Encoding
Instead of storing trait strings (expensive), we encode all 6 traits into a single `uint256`:

```
Traits packed into 48 bits:
[background][bodyColor][eyeColor][accessory][expression][pattern]
    8 bits     8 bits    8 bits     8 bits      8 bits     8 bits
```

**Example:**
- Traits: `{background: "Rainbow", bodyColor: "Black", eyeColor: "Green", ...}`
- Encoded: `0x0000000000000000000000000000000000000000000000000000000000010805`
- Storage cost: **Only 32 bytes!**

### 2. SVG Generation
The `tokenURI()` function generates the SVG on-chain:
- Decodes the uint256 to get trait indexes
- Looks up trait names from arrays
- Constructs pixel-by-pixel SVG
- Encodes as base64 data URI
- Returns complete metadata JSON

### 3. Data URIs
Instead of:
```json
"image": "ipfs://Qm..."
```

You get:
```json
"image": "data:image/svg+xml;base64,PHN2ZyB3aWR0aD0iNDgwIi..."
```

The entire image is embedded in the metadata!

## Deployment Options

### Option 1: Simplified On-Chain (Recommended for Beginners)
**Contract:** `PixelCatsOnChain.sol`

**Features:**
- Stores traits as uint256
- Generates simplified SVG on-chain
- Lower gas costs
- ~200k gas per mint

**Gas Estimate:**
- Deploy: ~3-4M gas (~$50-100 at 30 gwei)
- Mint: ~200k gas (~$6 at 30 gwei)

### Option 2: Full Pixel Art On-Chain (For Purists)
**Contract:** `PixelCatsFullOnChain.sol`

**Features:**
- Complete 24x24 pixel grid rendered on-chain
- Every pixel generated in tokenURI()
- Higher gas costs but 100% faithful to original art
- ~500k+ gas per tokenURI call

**Gas Estimate:**
- Deploy: ~5-6M gas (~$100-150 at 30 gwei)
- Mint: ~250k gas (~$7 at 30 gwei)
- tokenURI call: ~500k gas (view function, no cost)

## Step-by-Step Deployment

### Prerequisites
```bash
npm install -g hardhat
# or
npm install -g foundry
```

### Step 1: Generate On-Chain Data
```bash
bun run onchain
```

This creates:
- `onchain-output/` - Sample on-chain cats
- `deployment-data.json` - Contract deployment data
- `SolidityTraitArrays.sol` - Ready-to-copy trait arrays
- Individual HTML files to preview on-chain rendering

### Step 2: Review Generated Files
Open `onchain-output/1.html` in your browser to see how cats render on-chain.

### Step 3: Deploy Contract

#### Using Hardhat
```bash
npx hardhat run scripts/deploy.js --network mainnet
```

#### Using Foundry
```bash
forge create contracts/PixelCatsOnChain.sol:PixelCatsOnChain \
  --rpc-url $RPC_URL \
  --private-key $PRIVATE_KEY
```

#### Using Remix
1. Go to https://remix.ethereum.org
2. Copy `contracts/PixelCatsOnChain.sol`
3. Install OpenZeppelin: `@openzeppelin/contracts@5.0.0`
4. Compile
5. Deploy to your network

### Step 4: Verify Contract
```bash
npx hardhat verify --network mainnet DEPLOYED_ADDRESS
```

### Step 5: Test Minting
```solidity
// Call mint() function
await contract.mint({ value: ethers.parseEther("0.01") });

// Check tokenURI
const uri = await contract.tokenURI(0);
console.log(uri);
// data:application/json;base64,...
```

### Step 6: Verify On-Chain Rendering
Copy the tokenURI output and paste into browser address bar. You should see:
```json
{
  "name": "Pixel Cat #0",
  "description": "Fully on-chain pixel art cat",
  "image": "data:image/svg+xml;base64,...",
  "attributes": [...]
}
```

## Gas Optimization Tips

### 1. Batch Minting
```solidity
function batchMint(uint256 count) external payable {
    require(msg.value >= mintPrice * count);
    for (uint i = 0; i < count; i++) {
        // mint logic
    }
}
```
Saves gas by batching storage writes.

### 2. Packed Storage
```solidity
// ✅ Good - packed into single slot
uint128 public price;
uint64 public maxSupply;
uint64 public minted;

// ❌ Bad - uses 3 slots
uint256 public price;
uint256 public maxSupply;
uint256 public minted;
```

### 3. Immutable Arrays
Trait arrays are immutable after deployment, saving gas on reads.

## On-Chain Size Analysis

### Per NFT Storage:
- **Trait Data**: 32 bytes (uint256)
- **Token Ownership**: 32 bytes (address)
- **Total**: ~64 bytes per NFT

### For 10,000 NFT Collection:
- **Storage**: 640 KB on-chain
- **Cost**: ~$50,000 at current gas prices
- **Duration**: Forever ♾️

## Comparison: Traditional vs On-Chain

| Feature | IPFS/Centralized | Fully On-Chain |
|---------|------------------|----------------|
| Storage Cost | $0-100/year | One-time ~$50k |
| Permanence | Depends on pinning | Forever |
| Dependencies | IPFS/servers | None |
| Verifiability | Trust required | 100% verifiable |
| Gas per mint | ~100k | ~200k |
| Image size | Unlimited | Limited by gas |
| Resolution | High | Fixed (SVG scalable) |

## Testing Your On-Chain NFTs

### 1. Local Preview
```bash
bun run onchain
open onchain-output/1.html
```

### 2. Testnet Deploy
Deploy to Sepolia/Goerli first:
```bash
forge create --rpc-url $SEPOLIA_RPC ...
```

### 3. Verify Rendering
- Mint a test NFT
- Call tokenURI(0)
- Decode base64
- Verify JSON and SVG

### 4. OpenSea Test
- Import contract on OpenSea testnet
- Verify metadata displays correctly
- Check trait filters work

## Advanced: Dynamic On-Chain Art

You can make traits evolve on-chain:

```solidity
function evolve(uint256 tokenId) external {
    require(ownerOf(tokenId) == msg.sender);
    uint256 traits = tokenTraits[tokenId];

    // Change expression based on time
    if (block.timestamp % 2 == 0) {
        traits = (traits & ~0xFF00) | (4 << 8); // Happy
    }

    tokenTraits[tokenId] = traits;
}
```

## Frequently Asked Questions

**Q: Why are on-chain NFTs more expensive?**
A: You're paying for permanent blockchain storage vs. temporary centralized storage.

**Q: Can I update the art later?**
A: No! That's the point - it's immutable and permanent.

**Q: What if Ethereum changes?**
A: Your NFTs will continue to exist as long as the blockchain exists. They're part of the chain.

**Q: Can I use higher resolution?**
A: You can use SVG which scales infinitely, but more detail = more gas.

**Q: How does OpenSea display them?**
A: OpenSea automatically decodes data URIs and displays the embedded images.

**Q: Are there size limits?**
A: Block gas limit (~30M) limits how much can be generated in tokenURI(). Our cats are well within limits.

## Example Deployment Script

```typescript
import { ethers } from 'hardhat';

async function main() {
  const PixelCats = await ethers.getContractFactory('PixelCatsOnChain');
  const contract = await PixelCats.deploy();
  await contract.waitForDeployment();

  console.log('Deployed to:', await contract.getAddress());

  // Test mint
  const tx = await contract.mint({ value: ethers.parseEther('0.01') });
  await tx.wait();

  // Get tokenURI
  const uri = await contract.tokenURI(0);
  console.log('Token URI:', uri);
}

main();
```

## Resources

- **OpenZeppelin Contracts**: https://docs.openzeppelin.com/contracts/
- **Base64 Encoding**: https://base64.guru/
- **SVG Specification**: https://www.w3.org/TR/SVG2/
- **ERC721 Standard**: https://eips.ethereum.org/EIPS/eip-721

## Support

For issues with on-chain deployment:
1. Check gas estimates
2. Verify contract on Etherscan
3. Test tokenURI output in browser
4. Review OpenZeppelin docs

---

**Your Pixel Cats will live on-chain forever! 🐱⛓️**
