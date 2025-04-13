import fs from 'fs';
import path from 'path';
import { fileURLToPath } from 'url';

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);

const metadataDir = path.join(__dirname, 'pixel_output/metadata');
const outputDir = path.join(__dirname, 'fixed_metadata');

// Create output directory
if (!fs.existsSync(outputDir)) {
    fs.mkdirSync(outputDir, { recursive: true });
}

console.log("Fixing metadata image references...");

// Read all metadata files
const files = fs.readdirSync(metadataDir);
let processed = 0;

for (const file of files) {
    if (!file.endsWith('.json')) continue;
    
    const filePath = path.join(metadataDir, file);
    const metadata = JSON.parse(fs.readFileSync(filePath, 'utf8'));
    
    // Update image path to point to the images directory
    const tokenId = path.basename(file, '.json');
    metadata.image = `../images/${tokenId}.png`;
    
    // Write updated metadata
    fs.writeFileSync(
        path.join(outputDir, file),
        JSON.stringify(metadata, null, 2)
    );
    
    processed++;
    if (processed % 1000 === 0 || processed === files.length) {
        console.log(`Processed ${processed}/${files.length} files`);
    }
}

console.log("\nMetadata fix complete. Updated files are in the 'fixed_metadata' directory.");
console.log("\nTo upload the corrected metadata:");
console.log("1. npx @web3-storage/w3cli upload ./fixed_metadata");
console.log("2. Use the new CID to update your NFT contract baseURI"); 