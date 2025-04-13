// We require the Hardhat Runtime Environment explicitly here. This is optional
// but useful for running the script in a standalone fashion through `node <script>`.
//
// You can also run a script with `npx hardhat run <script>`. If you do that, Hardhat
// will compile your contracts, add the Hardhat Runtime Environment's members to the
// global scope, and execute the script.
const hre = require("hardhat");
const fs = require("fs");

/**
 * Generates random addresses for the airdrop demo
 * @param {number} count - Number of addresses to generate
 * @returns {Array} - Array of addresses
 */
function generateRandomAddresses(count) {
  console.log(`Generating ${count} random addresses for airdrop...`);
  const addresses = [];
  for (let i = 0; i < count; i++) {
    const wallet = hre.ethers.Wallet.createRandom();
    addresses.push(wallet.address);
  }
  return addresses;
}

/**
 * Main deployment function
 */
async function main() {
  // Get network info
  const network = hre.network.name;
  console.log(`Deploying to network: ${network}`);
  
  // Get the deployer account
  const [deployer] = await hre.ethers.getSigners();
  console.log(`Deploying with account: ${deployer.address}`);
  
  // Check deployer balance
  const balance = await deployer.getBalance();
  console.log(`Account balance: ${hre.ethers.utils.formatEther(balance)} ETH`);
  
  // Deploy contract
  console.log("Deploying Pixel Avatars NFT...");
  const NFT = await hre.ethers.getContractFactory("BTBFinanceNFT");
  const nft = await NFT.deploy(deployer.address);
  await nft.deployed();
  
  console.log(`Contract deployed to: ${nft.address}`);
  
  // Save deployment info
  const deployData = {
    network: network,
    contractAddress: nft.address,
    ownerAddress: deployer.address,
    deploymentTime: new Date().toISOString()
  };
  
  fs.writeFileSync(
    'deployment-info.json',
    JSON.stringify(deployData, null, 2)
  );
  console.log("Deployment info saved to deployment-info.json");
  
  // Generate 300 random addresses for airdrop
  const airdropCount = 300;
  const recipients = generateRandomAddresses(airdropCount);
  
  fs.writeFileSync(
    'airdrop-recipients.json',
    JSON.stringify(recipients, null, 2)
  );
  console.log(`${airdropCount} airdrop addresses saved to airdrop-recipients.json`);
  
  // Process airdrop in larger batches (50 addresses per batch)
  const batchSize = 50;
  const batches = [];
  
  for (let i = 0; i < recipients.length; i += batchSize) {
    batches.push(recipients.slice(i, i + batchSize));
  }
  
  console.log(`Airdropping to ${recipients.length} addresses in ${batches.length} batches of ${batchSize}...`);
  
  for (let i = 0; i < batches.length; i++) {
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
  
  // Verify total minted
  const totalMinted = await nft.totalMinted();
  console.log(`\nTotal NFTs minted: ${totalMinted.toString()}`);
  
  // Print verification instructions
  const explorerUrl = network === "base-sepolia" 
    ? `https://sepolia.basescan.org/address/${nft.address}`
    : network === "base-mainnet"
      ? `https://basescan.org/address/${nft.address}`
      : `https://${network}.etherscan.io/address/${nft.address}`;
  
  console.log(`\nDeployment and airdrop completed!`);
  console.log(`Contract Address: ${nft.address}`);
  console.log(`View on Explorer: ${explorerUrl}`);
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
}); 