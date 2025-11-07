import { NFTGenerator } from './generator';
import sharp from 'sharp';
import { mkdir, writeFile } from 'fs/promises';
import { join } from 'path';

interface GenerationConfig {
  count: number;
  outputDir: string;
  imageFormat: 'png' | 'svg';
  size: number;
}

async function generateCollection(config: GenerationConfig) {
  const generator = new NFTGenerator();
  const { count, outputDir, imageFormat, size } = config;

  console.log(`🎨 Starting generation of ${count} Pixel Cats...`);
  console.log(`📁 Output directory: ${outputDir}`);
  console.log(`🖼️  Format: ${imageFormat}, Size: ${size}x${size}px\n`);

  // Create output directories
  await mkdir(join(outputDir, 'images'), { recursive: true });
  await mkdir(join(outputDir, 'metadata'), { recursive: true });

  const startTime = Date.now();
  const rarityScores: Array<{ edition: number; score: number }> = [];

  for (let i = 1; i <= count; i++) {
    try {
      // Generate traits
      const traits = generator.generateTraits();
      const rarityScore = generator.calculateRarityScore(traits);
      rarityScores.push({ edition: i, score: rarityScore });

      // Generate image
      const svg = generator.generateImage(traits);

      // Save image
      if (imageFormat === 'svg') {
        await writeFile(join(outputDir, 'images', `${i}.svg`), svg);
      } else {
        // Convert SVG to PNG using sharp
        const pngBuffer = await sharp(Buffer.from(svg))
          .resize(size, size, { kernel: 'nearest' })
          .png()
          .toBuffer();
        await writeFile(join(outputDir, 'images', `${i}.png`), pngBuffer);
      }

      // Generate metadata
      const metadata = generator.generateMetadata(traits, i);
      await writeFile(
        join(outputDir, 'metadata', `${i}.json`),
        JSON.stringify(metadata, null, 2)
      );

      // Progress indicator
      if (i % 10 === 0 || i === count) {
        const elapsed = ((Date.now() - startTime) / 1000).toFixed(2);
        const rate = (i / (Date.now() - startTime) * 1000).toFixed(2);
        console.log(`✅ Generated ${i}/${count} cats (${rate} cats/sec, ${elapsed}s elapsed)`);
      }
    } catch (error) {
      console.error(`❌ Error generating cat #${i}:`, error);
    }
  }

  // Generate collection metadata
  const collectionMetadata = {
    name: 'Pixel Cats',
    description: 'A collection of unique pixel art cats',
    total_supply: count,
    generated_at: new Date().toISOString(),
    rarity_distribution: calculateRarityDistribution(rarityScores)
  };

  await writeFile(
    join(outputDir, 'collection.json'),
    JSON.stringify(collectionMetadata, null, 2)
  );

  // Generate rarity report
  const sortedByRarity = [...rarityScores].sort((a, b) => b.score - a.score);
  const rarityReport = {
    most_rare: sortedByRarity.slice(0, 10),
    least_rare: sortedByRarity.slice(-10).reverse(),
    average_rarity: rarityScores.reduce((sum, r) => sum + r.score, 0) / rarityScores.length
  };

  await writeFile(
    join(outputDir, 'rarity_report.json'),
    JSON.stringify(rarityReport, null, 2)
  );

  const totalTime = ((Date.now() - startTime) / 1000).toFixed(2);
  console.log(`\n🎉 Generation complete!`);
  console.log(`⏱️  Total time: ${totalTime}s`);
  console.log(`📊 Average rarity score: ${rarityReport.average_rarity.toFixed(2)}`);
  console.log(`🏆 Most rare: Cat #${sortedByRarity[0].edition} (score: ${sortedByRarity[0].score})`);
  console.log(`\n📁 Files saved to: ${outputDir}`);
}

function calculateRarityDistribution(rarityScores: Array<{ edition: number; score: number }>) {
  const distribution = {
    common: 0,      // 0-100
    uncommon: 0,    // 101-200
    rare: 0,        // 201-300
    epic: 0,        // 301-400
    legendary: 0    // 401+
  };

  rarityScores.forEach(({ score }) => {
    if (score <= 100) distribution.common++;
    else if (score <= 200) distribution.uncommon++;
    else if (score <= 300) distribution.rare++;
    else if (score <= 400) distribution.epic++;
    else distribution.legendary++;
  });

  return distribution;
}

// Parse command line arguments
const args = process.argv.slice(2);
const count = parseInt(args[0]) || 10;
const format = (args[1] as 'png' | 'svg') || 'png';
const size = parseInt(args[2]) || 480;

const config: GenerationConfig = {
  count,
  outputDir: './output',
  imageFormat: format,
  size
};

generateCollection(config).catch(console.error);
