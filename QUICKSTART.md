# Quick Start Guide

## Installation

```bash
bun install
```

## Generate Your First Pixel Cat

```bash
bun run dev
```

This creates:
- `pixel-cat.svg` - Vector image
- `pixel-cat.png` - 480x480px PNG
- `pixel-cat-metadata.json` - NFT metadata

## Generate a Full Collection

### Small Collection (10 cats)
```bash
bun run generate 10
```

### Medium Collection (100 cats)
```bash
bun run generate 100
```

### Large Collection (1000 cats)
```bash
bun run generate 1000
```

### Custom Size PNG
```bash
bun run generate 100 png 1000
```

### SVG Format (Scalable)
```bash
bun run generate 50 svg
```

## Output Structure

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
├── collection.json      # Collection overview
└── rarity_report.json   # Rarity rankings
```

## Understanding Rarity

- **Common**: 0-100 points
- **Uncommon**: 101-200 points
- **Rare**: 201-300 points
- **Epic**: 301-400 points
- **Legendary**: 401+ points

Check `rarity_report.json` after generation to find the rarest cats!

## Next Steps for NFT Launch

1. **Review Generated Collection**
   - Check `output/images/` for all cats
   - Review `rarity_report.json` for distribution

2. **Upload to IPFS**
   ```bash
   # Example with NFT.Storage or Pinata
   ipfs add -r output/images/
   ```

3. **Update Metadata**
   - Replace `ipfs://YOUR_CID_HERE` with actual IPFS CID
   - Update `image` field in all metadata files

4. **Deploy Smart Contract**
   - Use ERC721 standard
   - Point to metadata folder on IPFS

5. **List on Marketplace**
   - OpenSea, Rarible, etc.
   - They will automatically read your metadata

## Customization

### Change Pixel Size
Edit `src/pixelArt.ts`:
```typescript
const canvas = new PixelCanvas(24, 24, 30); // Larger pixels
```

### Add New Accessories
Edit `src/traits.ts`:
```typescript
export const ACCESSORIES: Trait[] = [
  { name: 'Your Custom Item', rarity: 95 },
  // ... existing items
];
```

Then add drawing code in `src/pixelArt.ts`:
```typescript
case 'Your Custom Item':
  // Draw your accessory
  canvas.setPixel(x, y, color);
  break;
```

### Adjust Rarity Weights
Edit rarity values in `src/traits.ts`:
```typescript
{ name: 'Galaxy Black', rarity: 95 } // Super rare
{ name: 'Sky Blue', rarity: 10 }     // Very common
```

## Troubleshooting

**Q: Generation is slow**
A: Bun is already optimized. For even faster generation, reduce image size or use SVG format.

**Q: I want different colors**
A: Edit color codes in `src/traits.ts` under `BACKGROUND_COLORS`, `BODY_COLOR_CODES`, etc.

**Q: Can I make larger collections?**
A: Yes! The generator can create millions of unique combinations. Just increase the count parameter.

**Q: How do I preview my cats?**
A: Open any PNG file in `output/images/` with your image viewer, or open SVG files in a browser.

## Performance Tips

- **PNG Generation**: ~100-150 cats/second
- **SVG Generation**: ~500+ cats/second
- **Memory**: ~50MB for 1000 cats
- **Storage**: ~10KB per PNG (480x480), ~2KB per SVG

## Support

For issues or questions:
1. Check this guide
2. Review README.md
3. Examine example output files
4. Modify source code in `src/` directory

Happy generating! 🐱
