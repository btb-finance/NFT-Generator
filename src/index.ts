import { NFTGenerator } from './generator';
import sharp from 'sharp';
import { writeFile } from 'fs/promises';

async function generateSingleCat() {
  console.log('🐱 Generating a single Pixel Cat NFT...\n');

  const generator = new NFTGenerator();

  // Generate traits
  const traits = generator.generateTraits();
  console.log('Traits:', traits);

  // Calculate rarity
  const rarityScore = generator.calculateRarityScore(traits);
  console.log(`Rarity Score: ${rarityScore}`);

  // Generate image
  const svg = generator.generateImage(traits);

  // Save SVG
  await writeFile('pixel-cat.svg', svg);
  console.log('✅ Saved: pixel-cat.svg');

  // Convert to PNG
  const pngBuffer = await sharp(Buffer.from(svg))
    .resize(480, 480, { kernel: 'nearest' })
    .png()
    .toBuffer();

  await writeFile('pixel-cat.png', pngBuffer);
  console.log('✅ Saved: pixel-cat.png');

  // Generate metadata
  const metadata = generator.generateMetadata(traits, 1);
  await writeFile('pixel-cat-metadata.json', JSON.stringify(metadata, null, 2));
  console.log('✅ Saved: pixel-cat-metadata.json');

  console.log('\n🎉 Done! Your Pixel Cat has been generated.');
}

generateSingleCat().catch(console.error);
