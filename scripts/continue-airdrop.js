// This script continues an airdrop for an already deployed contract
const hre = require("hardhat");
const fs = require("fs");

async function main() {
  try {
    // Load deployment info
    const deploymentInfo = JSON.parse(fs.readFileSync('deployment-info.json', 'utf8'));
    const contractAddress = deploymentInfo.contractAddress;
    
    console.log(`Continuing airdrop for contract at ${contractAddress}`);
    
    // Get signer
    const [signer] = await hre.ethers.getSigners();
    console.log(`Using account: ${signer.address}`);
    
    // Load contract
    const NFT = await hre.ethers.getContractFactory("BTBFinanceNFT");
    const nft = NFT.attach(contractAddress);
    
    // Check current status
    const totalMinted = await nft.totalMinted();
    console.log(`Current total minted: ${totalMinted.toString()}`);
    
    // Load recipient addresses
    const recipients = JSON.parse(fs.readFileSync('airdrop-recipients.json', 'utf8'));
    console.log(`Found ${recipients.length} recipient addresses in file`);
    
    // Process in batches of 50
    const batchSize = 50;
    const batches = [];
    
    for (let i = 0; i < recipients.length; i += batchSize) {
      batches.push(recipients.slice(i, i + batchSize));
    }
    
    // Calculate starting point (if some already processed)
    const startBatch = Math.floor(totalMinted.toNumber() / batchSize);
    
    console.log(`Starting from batch ${startBatch + 1}/${batches.length}`);
    console.log(`Total recipients: ${recipients.length}, Batch size: ${batchSize}`);
    
    // Process remaining batches
    for (let i = startBatch; i < batches.length; i++) {
      console.log(`Processing batch ${i + 1}/${batches.length} (${batches[i].length} addresses)...`);
      
      try {
        // Estimate gas for this batch
        const gasEstimate = await nft.estimateGas.airdropNFTs(batches[i]);
        console.log(`Estimated gas: ${gasEstimate.toString()}`);
        
        // Add 20% buffer to gas estimate
        const gasLimit = gasEstimate.mul(120).div(100);
        
        const tx = await nft.airdropNFTs(batches[i], {
          gasLimit: gasLimit
        });
        
        console.log(`Transaction sent! Hash: ${tx.hash}`);
        const receipt = await tx.wait();
        console.log(`Batch ${i + 1} complete! Gas used: ${receipt.gasUsed.toString()}`);
      } catch (error) {
        console.error(`Batch ${i + 1} failed:`, error.message);
        console.log(`Trying to reduce batch size and continue...`);
        
        // If a batch fails, try to process it in smaller chunks
        const smallerBatchSize = 10;
        const smallerBatches = [];
        
        for (let j = 0; j < batches[i].length; j += smallerBatchSize) {
          smallerBatches.push(batches[i].slice(j, j + smallerBatchSize));
        }
        
        console.log(`Breaking batch ${i + 1} into ${smallerBatches.length} smaller batches of ${smallerBatchSize}...`);
        
        for (let k = 0; k < smallerBatches.length; k++) {
          try {
            console.log(`Processing smaller batch ${k + 1}/${smallerBatches.length}...`);
            const tx = await nft.airdropNFTs(smallerBatches[k]);
            await tx.wait();
            console.log(`Smaller batch ${k + 1} complete!`);
          } catch (subError) {
            console.error(`Smaller batch ${k + 1} also failed:`, subError.message);
            console.log(`Skipping these addresses. Please retry manually later.`);
          }
        }
      }
    }
    
    // Final verification
    const finalTotalMinted = await nft.totalMinted();
    console.log(`\nFinal total minted: ${finalTotalMinted.toString()}`);
    console.log(`Airdrop complete!`);
    
    // Explorer link
    const explorer = `https://sepolia.basescan.org/address/${contractAddress}`;
    console.log(`View contract on explorer: ${explorer}`);
    
  } catch (error) {
    console.error("Error:", error);
    process.exitCode = 1;
  }
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
}); 