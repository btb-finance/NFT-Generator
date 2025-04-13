# Pixel Avatars NFT Collection

This project allows you to generate and deploy a collection of 10,000 unique pixel art NFT avatars with BTB Finance branding on the Base network.

## Overview

This repository contains:
1. A pixel avatar generator script that creates 10,000 unique NFTs with metadata
2. Tools to upload your collection to IPFS
3. Smart contracts and deployment scripts for the Base network

## Getting Started

### Prerequisites

- Node.js (v16+)
- NPM or Yarn
- An Ethereum wallet with Base Sepolia ETH for testing, or Base Mainnet ETH for production
- A Storacha Network account for IPFS uploads

### Installation

1. Clone this repository:
```bash
git clone https://github.com/your-username/pixel-avatars-nft
cd pixel-avatars-nft
```

2. Install dependencies:
```bash
npm install
```

3. Create a `.env` file in the root directory with your private key:
```
PRIVATE_KEY=your_private_key_here
```
⚠️ **NEVER** share your private key or commit the `.env` file to GitHub!

## Generating Your NFT Collection

### Step 1: Customize Your Avatars (Optional)

Edit the `generate_pixel_avatars.js` file to customize your avatar collection:

- **Colors**: Modify the `pastelColor()` function to change the color palette
- **Traits**: Edit the arrays for various traits (eyes, headwear, etc.)
- **Rarity**: Adjust the `rarityTiers` array to change the distribution
- **Metadata**: Update the collection name and descriptions

Example customization:
```javascript
// Change background colors
function pastelColor() {
  // For a blue-themed collection:
  const hue = 180 + Math.floor(Math.random() * 60); // 180-240 = blue range
  return `hsl(${hue}, 70%, 85%)`;
}

// Change rarity distribution
const rarityTiers = [
  { name: 'Mythic', quantity: 50 },      // Rarer mythics (50 instead of 100)
  { name: 'Divine', quantity: 200 },     // Fewer divine
  // ... other tiers
];
```

### Step 2: Generate Your Collection

Run the generator script:
```bash
node generate_pixel_avatars.js
```

This will create:
- `pixel_output/images`: 10,000 PNG avatar images
- `pixel_output/metadata`: 10,000 JSON metadata files

The script automatically:
- Assigns rarity tiers to avatars
- Calculates rarity scores and ranking
- Creates rich metadata with traits, BTB Finance branding, and lore

## Uploading to IPFS

### Step 1: Install Storacha CLI

```bash
npm install -g @storacha/cli
```

### Step 2: Set Up Your Storacha Account

1. Create an account at [Storacha Network](https://console.storacha.network) if you don't have one
2. Log in to the CLI:
```bash
storacha login --email your@email.com
```
3. Create a new space in the Storacha console or use an existing one

### Step 3: Upload Your Collection

```bash
storacha upload pixel_output/images --metadata pixel_output/metadata --space your-space-id
```

Save the IPFS CID that's returned after the upload is complete. You'll need this for your smart contract.

### Step 4: Update Contract Base URI

Edit the `nft.sol` contract constructor to use your IPFS URI:

```solidity
_baseTokenURI = "ipfs://YOUR_CID_HERE/";
```

Or you can set it after deployment using the `setBaseURI` function.

## Deploying Your Smart Contract

### Step 1: Compile the Contract

```bash
npm run compile
```

### Step 2: Configure Your Deployment

The default network is Base Sepolia testnet. For mainnet deployment, edit `hardhat.config.js` and change the default network.

### Step 3: Deploy Your Contract

```bash
npm run deploy
```

This will:
- Deploy the BTBFinanceNFT contract to the chosen network
- Generate 50 random addresses (for demonstration purposes)
- Airdrop one NFT to each of these addresses
- Save deployment information to `deployment-info.json`

### Step 4: Verify Your Deployment

Check the contract on:
- Base Sepolia: https://sepolia.basescan.org/address/YOUR_CONTRACT_ADDRESS
- Base Mainnet: https://basescan.org/address/YOUR_CONTRACT_ADDRESS

## Setting Up Sales (Post-Deployment)

After deployment, you need to:

1. Deploy or use an existing BTB token contract
2. Connect it to your NFT contract:
```bash
npx hardhat run scripts/set-payment-token.js --network base-sepolia
```

## Customization Reference

### Avatar Traits

The generator creates avatars with these traits:
- Background color and pattern
- Body color and shape
- Eye color and style
- Hair color and style
- Headwear (cap, crown, helmet, etc.)
- Face accessories
- Rarity tier (Mythic, Divine, Celestial, etc.)
- Character class (Warrior, Mage, Rogue, etc.)

### Metadata Structure

Each NFT includes rich metadata:
- Basic info (name, description, image)
- Attributes (visual traits)
- BTB Finance branding
- Character lore and story arcs
- Special traits based on character class
- Compatible items
- Rarity information

## Support

For issues or questions, please open a GitHub issue or contact the BTB Finance team.

## Security Notes

- Never share your private key or .env file
- For real airdrops, replace the random address generation with your actual distribution list
- Consider using a hardware wallet for production deployments 