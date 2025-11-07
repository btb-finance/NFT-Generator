# Pixel Cats NFT Generator

A TypeScript-based NFT generator that creates unique pixel art cats with customizable traits and rarity levels. Built with Bun for blazing-fast performance.

**🔗 Now with Fully On-Chain Support!** Deploy your NFTs 100% on the blockchain with no external dependencies.

## Features

- **Procedural Generation**: Automatically generates unique pixel art cats
- **Rarity System**: Weighted trait distribution with rarity scores
- **Multiple Traits**: 6 trait categories (background, body color, eyes, accessories, expressions, patterns)
- **Batch Generation**: Generate thousands of NFTs in seconds
- **Metadata Generation**: Automatic JSON metadata creation for each NFT
- **Multiple Formats**: Export as SVG or PNG
- **Rarity Reports**: Automatic rarity analysis and ranking
- **No Duplicates**: Ensures each generated cat is unique

## Trait Categories

- **Backgrounds**: 10 variations (Sky Blue, Sunset Orange, Galaxy Black, etc.)
- **Body Colors**: 11 variations (Orange Tabby, Black, White, Rainbow Holographic, etc.)
- **Eye Colors**: 9 variations (Green, Blue, Heterochromia, Galaxy, etc.)
- **Accessories**: 12 variations (Crown, Top Hat, Sunglasses, Astronaut Helmet, etc.)
- **Expressions**: 10 variations (Happy, Sleepy, Grumpy, Alien, etc.)
- **Patterns**: 10 variations (Solid, Striped, Spotted, Cosmic Swirl, etc.)

## Installation

```bash
# Install Bun (if not already installed)
curl -fsSL https://bun.sh/install | bash

# Install dependencies
bun install
```

## Usage

### Generate a Single Cat

```bash
bun run dev
```

This will create:
- `pixel-cat.svg` - SVG version
- `pixel-cat.png` - PNG version (480x480px)
- `pixel-cat-metadata.json` - Metadata file

### Generate a Collection

```bash
# Generate 100 cats as PNG (default size 480x480)
bun run generate 100

# Generate 1000 cats as PNG with custom size
bun run generate 1000 png 1000

# Generate as SVG (scalable)
bun run generate 50 svg
```

Output structure:
```
output/
├── images/
│   ├── 1.png
│   ├── 2.png
│   └── ...
├── metadata/
│   ├── 1.json
│   ├── 2.json
│   └── ...
├── collection.json
└── rarity_report.json
```

## Rarity System

Each trait has a rarity score (0-100):
- Lower scores = More common
- Higher scores = More rare

Total rarity is calculated by summing all trait rarities:
- **Common**: 0-100
- **Uncommon**: 101-200
- **Rare**: 201-300
- **Epic**: 301-400
- **Legendary**: 401+

## Example Metadata

```json
{
  "name": "Pixel Cat #1",
  "description": "A unique pixel art cat from the Pixel Cats NFT collection.",
  "image": "ipfs://YOUR_CID_HERE/1.png",
  "edition": 1,
  "attributes": [
    { "trait_type": "Background", "value": "Galaxy Black" },
    { "trait_type": "Body Color", "value": "Rainbow Holographic" },
    { "trait_type": "Eye Color", "value": "Diamond White" },
    { "trait_type": "Accessory", "value": "Astronaut Helmet" },
    { "trait_type": "Expression", "value": "Alien" },
    { "trait_type": "Pattern", "value": "Cosmic Swirl" }
  ]
}
```

## Customization

### Adding New Traits

Edit `src/traits.ts` to add new options:

```typescript
export const ACCESSORIES: Trait[] = [
  { name: 'Your New Accessory', rarity: 85 },
  // ... existing traits
];
```

### Adjusting Pixel Art

Modify drawing functions in `src/pixelArt.ts`:

```typescript
export function drawAccessory(canvas: PixelCanvas, accessory: string) {
  // Add your custom drawing logic
}
```

### Changing Canvas Size

Edit `src/pixelArt.ts`:

```typescript
const canvas = new PixelCanvas(32, 32, 20); // width, height, pixel size
```

## Performance

- Generates 100+ NFTs per second (depending on hardware)
- Memory efficient with streaming outputs
- Optimized pixel drawing algorithms
- Bun's native performance benefits

## File Structure

```
pixel-cats-nft/
├── src/
│   ├── types.ts          # TypeScript interfaces
│   ├── traits.ts         # Trait definitions and rarities
│   ├── pixelArt.ts       # Pixel drawing functions
│   ├── generator.ts      # Core NFT generation logic
│   ├── generate.ts       # Batch generation script
│   └── index.ts          # Single cat generator
├── output/               # Generated NFTs (created on run)
├── package.json
├── tsconfig.json
└── README.md
```

## License

MIT

## Tips for NFT Projects

1. **IPFS Upload**: Upload all images to IPFS and update metadata with correct CIDs
2. **Metadata Standards**: Current metadata follows OpenSea/ERC721 standards
3. **Smart Contract**: Deploy ERC721 contract and use generated metadata
4. **Rarity Tools**: Use `rarity_report.json` to identify top rare items
5. **Preview**: Generate small batches first to test trait combinations

## Troubleshooting

**Issue**: "Unable to generate unique combination"
- **Solution**: Reduce collection size or add more trait variations

**Issue**: Sharp installation fails
- **Solution**: Make sure you have required system dependencies
  ```bash
  # macOS
  brew install vips

  # Ubuntu/Debian
  sudo apt-get install libvips
  ```

## Future Enhancements

- [ ] Add animation support
- [ ] Web-based preview generator
- [ ] Trait conflict rules
- [ ] Custom color palettes
- [ ] Layer-based composition system
- [ ] IPFS auto-upload integration
- [ ] Smart contract deployment scripts
