import { NFTGenerator } from './generator';
import { OnChainEncoder } from './onchain';
import { writeFile, mkdir } from 'fs/promises';
import { join } from 'path';

/**
 * Generate on-chain compatible NFT data
 */
async function generateOnChainData() {
  console.log('🔗 Generating On-Chain Pixel Cats Data...\n');

  const generator = new NFTGenerator();
  const encoder = new OnChainEncoder();

  // Generate sample cats
  const count = 10;
  const outputDir = './onchain-output';

  await mkdir(outputDir, { recursive: true });

  console.log('Generated Cats:\n');

  const onChainData = [];

  for (let i = 1; i <= count; i++) {
    const traits = generator.generateTraits();

    // Encode traits as uint256
    const encodedTraits = encoder.encodeTraitsToUint(traits);

    // Generate data URI
    const dataURI = encoder.generateDataURI(traits);

    // Generate on-chain metadata
    const metadataBase64 = encoder.generateOnChainMetadata(traits, i);

    const catData = {
      edition: i,
      traits,
      encodedTraits,
      dataURILength: dataURI.length,
      metadataBase64Length: metadataBase64.length,
      fullMetadataURI: `data:application/json;base64,${metadataBase64}`
    };

    onChainData.push(catData);

    console.log(`Cat #${i}:`);
    console.log(`  Traits: ${JSON.stringify(traits)}`);
    console.log(`  Encoded: ${encodedTraits}`);
    console.log(`  Data URI Size: ${(dataURI.length / 1024).toFixed(2)} KB`);
    console.log(`  Metadata Size: ${(metadataBase64.length / 1024).toFixed(2)} KB`);
    console.log('');

    // Save individual files
    await writeFile(
      join(outputDir, `${i}.json`),
      JSON.stringify({
        traits,
        encodedTraits,
        fullMetadata: `data:application/json;base64,${metadataBase64}`
      }, null, 2)
    );

    // Save the full data URI metadata for testing
    await writeFile(
      join(outputDir, `${i}.html`),
      `<!DOCTYPE html>
<html>
<head><title>Pixel Cat #${i}</title></head>
<body style="margin:0;padding:20px;background:#1a1a1a;color:white;font-family:monospace;">
  <h1>Pixel Cat #${i}</h1>
  <img src="${dataURI}" style="width:480px;height:480px;image-rendering:pixelated;background:white;"/>
  <h2>On-Chain Metadata</h2>
  <pre>${JSON.stringify(traits, null, 2)}</pre>
  <h2>Encoded Traits (uint256)</h2>
  <p>${encodedTraits}</p>
  <h2>Data URI Length</h2>
  <p>${dataURI.length} bytes (${(dataURI.length / 1024).toFixed(2)} KB)</p>
  <h2>Full Metadata URI</h2>
  <textarea style="width:100%;height:200px;font-family:monospace;">${`data:application/json;base64,${metadataBase64}`}</textarea>
</body>
</html>`
    );
  }

  // Generate deployment data
  const deploymentData = {
    totalGenerated: count,
    averageDataURISize: onChainData.reduce((sum, d) => sum + d.dataURILength, 0) / count,
    averageMetadataSize: onChainData.reduce((sum, d) => sum + d.metadataBase64Length, 0) / count,
    encodedTraits: onChainData.map(d => d.encodedTraits),
    solidity_trait_mapping: encoder.generateSolidityTraitMapping()
  };

  await writeFile(
    join(outputDir, 'deployment-data.json'),
    JSON.stringify(deploymentData, null, 2)
  );

  // Generate Solidity helper
  await writeFile(
    join(outputDir, 'SolidityTraitArrays.sol'),
    `// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/**
 * @title PixelCatsTraits
 * @dev Trait arrays for on-chain Pixel Cats
 * Copy these into your main contract
 */
contract PixelCatsTraits {
${encoder.generateSolidityTraitMapping()}
}
`
  );

  console.log('✅ On-Chain Data Generated!\n');
  console.log(`📁 Output: ${outputDir}`);
  console.log(`📊 Average Data URI Size: ${(deploymentData.averageDataURISize / 1024).toFixed(2)} KB`);
  console.log(`📊 Average Metadata Size: ${(deploymentData.averageMetadataSize / 1024).toFixed(2)} KB`);
  console.log('\n💡 Tips for On-Chain Deployment:');
  console.log('   1. Data URIs are stored as base64 - no external dependencies!');
  console.log('   2. Each NFT stores only a uint256 (32 bytes) for traits');
  console.log('   3. SVG generation happens in tokenURI() function');
  console.log('   4. No IPFS, no servers - 100% on-chain forever!');
  console.log('\n🚀 Next Steps:');
  console.log('   1. Review generated HTML files to see on-chain rendering');
  console.log('   2. Deploy PixelCatsOnChain.sol contract');
  console.log('   3. Mint and verify tokenURI returns full data URI');
  console.log('   4. List on OpenSea - they will render it automatically!');
}

generateOnChainData().catch(console.error);
