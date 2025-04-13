// Script to determine the maximum batch size for airdrop in a single transaction
const hre = require("hardhat");
const fs = require("fs");

/**
 * Generates random addresses for testing
 * @param {number} count - Number of addresses to generate
 * @returns {Array} - Array of addresses
 */
function generateRandomAddresses(count) {
  console.log(`Generating ${count} random addresses...`);
  const addresses = [];
  for (let i = 0; i < count; i++) {
    const wallet = hre.ethers.Wallet.createRandom();
    addresses.push(wallet.address);
  }
  return addresses;
}

/**
 * Tests a batch of a specific size to see if it works
 * @param {Contract} contract - The NFT contract
 * @param {number} batchSize - Size of batch to test
 * @returns {Object} - Result of the test {success, gasUsed, error}
 */
async function testBatchSize(contract, batchSize) {
  const addresses = generateRandomAddresses(batchSize);
  console.log(`Testing batch size: ${batchSize} addresses...`);
  
  try {
    // Try to estimate gas first
    console.log("Estimating gas...");
    const gasEstimate = await contract.estimateGas.airdropNFTs(addresses);
    console.log(`Gas estimate: ${gasEstimate.toString()}`);
    
    // If gas estimation succeeds, try the actual transaction
    // Add 20% buffer to gas estimate
    const gasLimit = gasEstimate.mul(120).div(100);
    
    console.log(`Sending transaction with gas limit: ${gasLimit.toString()}`);
    const tx = await contract.airdropNFTs(addresses, {
      gasLimit: gasLimit
    });
    
    console.log(`Transaction sent! Hash: ${tx.hash}`);
    const receipt = await tx.wait();
    
    console.log(`Transaction successful! Gas used: ${receipt.gasUsed.toString()}`);
    return {
      success: true,
      gasUsed: receipt.gasUsed.toNumber(),
      error: null
    };
  } catch (error) {
    console.error(`Failed with batch size ${batchSize}:`, error.message);
    return {
      success: false,
      gasUsed: 0,
      error: error.message
    };
  }
}

async function main() {
  try {
    // Deploy new contract for testing
    console.log("Deploying new contract for batch size testing...");
    const [deployer] = await hre.ethers.getSigners();
    console.log(`Using account: ${deployer.address}`);
    
    const NFT = await hre.ethers.getContractFactory("BTBFinanceNFT");
    const nft = await NFT.deploy(deployer.address);
    await nft.deployed();
    
    console.log(`Contract deployed to: ${nft.address}`);
    
    // Test different batch sizes
    // Start with known working size (50) and increase/decrease using binary search
    let low = 50;  // We know 50 works from previous tests
    let high = 300; // We know 300 doesn't work
    let maxSuccessful = 0;
    let results = [];
    
    console.log("\n=== TESTING DIFFERENT BATCH SIZES ===");
    
    // First test the known working size to confirm
    const initialResult = await testBatchSize(nft, low);
    if (!initialResult.success) {
      console.error(`Even the initial size ${low} failed. Network conditions may have changed.`);
      console.log("Trying smaller batch sizes...");
      high = low;
      low = 10;
    } else {
      results.push({ size: low, ...initialResult });
      maxSuccessful = low;
    }
    
    // Try mid-point to narrow down the range faster
    while (high - low > 10) {
      const mid = Math.floor((low + high) / 2);
      console.log(`\nTrying mid-point: ${mid}`);
      
      const result = await testBatchSize(nft, mid);
      results.push({ size: mid, ...result });
      
      if (result.success) {
        low = mid;
        maxSuccessful = mid;
      } else {
        high = mid;
      }
      
      console.log(`Current range: ${low} to ${high}`);
    }
    
    // Fine tune by testing each size in the remaining range
    for (let size = low + 1; size <= high; size++) {
      console.log(`\nFine tuning - testing batch size: ${size}`);
      const result = await testBatchSize(nft, size);
      results.push({ size, ...result });
      
      if (result.success) {
        maxSuccessful = size;
      } else {
        break; // Stop once we find a failure
      }
    }
    
    // Save results for analysis
    fs.writeFileSync(
      'batch-size-test-results.json',
      JSON.stringify(results, null, 2)
    );
    
    console.log("\n=== TEST COMPLETED ===");
    console.log(`Maximum successful batch size: ${maxSuccessful} addresses`);
    console.log(`Results saved to batch-size-test-results.json`);
    
    // Recommendations for mainnet
    console.log("\n=== RECOMMENDATIONS FOR MAINNET ===");
    console.log(`1. Based on testing, you can safely use batches of ${maxSuccessful} addresses on Base Sepolia.`);
    console.log(`2. For Base Mainnet, consider using a slightly smaller batch size (${Math.floor(maxSuccessful * 0.8)}) to account for network differences.`);
    console.log(`3. Monitor gas prices before deployment and adjust batch sizes accordingly.`);
    console.log(`4. For maximum safety, implement the progressive batch reduction logic we've developed.`);
    
  } catch (error) {
    console.error("Error:", error);
    process.exitCode = 1;
  }
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
}); 