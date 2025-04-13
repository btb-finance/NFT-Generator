import fs from 'fs';
import path from 'path';
import { fileURLToPath } from 'url';

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);

const metadataDir = path.join(__dirname, 'pixel_output');

console.log("Updating image paths in JSON files...");

// Read all JSON files in the pixel_output directory
const files = fs.readdirSync(metadataDir)
  .filter(file => file.endsWith('.json'));

let processed = 0;

for (const file of files) {
  const filePath = path.join(metadataDir, file);
  const metadata = JSON.parse(fs.readFileSync(filePath, 'utf8'));
  
  // Update the image path to point to the images directory
  const tokenId = path.basename(file, '.json');
  metadata.image = `images/${tokenId}.png`;
  
  // Write the updated metadata back to the file
  fs.writeFileSync(filePath, JSON.stringify(metadata, null, 2));
  
  processed++;
  if (processed % 1000 === 0 || processed === files.length) {
    console.log(`Processed ${processed}/${files.length} files`);
  }
}

console.log("\nAll image paths updated to point to the images directory.");
console.log("JSON files now use 'images/X.png' format which will work correctly when uploaded together.");
console.log("\nYou can now upload the entire pixel_output directory to IPFS with:");
console.log("npx @web3-storage/w3cli upload ./pixel_output");
console.log("\nAfter upload, set your NFT contract's baseURI to: ipfs://NEW_CID/"); 