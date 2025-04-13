require('dotenv').config();
const { ethers } = require('ethers');
const fs = require('fs');

// Compile the contract first (this script assumes the contract is already compiled)
const contractJson = {
  abi: [
    // ABI will be auto-filled by the script that compiles the contract
    "function airdropNFTs(address[] calldata recipients) public",
    "function owner() view returns (address)",
    "function name() view returns (string)",
    "function symbol() view returns (string)",
    "function totalMinted() view returns (uint256)"
  ],
  bytecode: "0x..." // This will be filled by the compilation process
};

// Network configuration for Base Sepolia
const networkConfig = {
  name: "Base Sepolia",
  chainId: 84532,
  url: "https://sepolia.base.org"
};

// Generate 50 random addresses for the airdrop
function generateRandomAddresses(count) {
  const addresses = [];
  for (let i = 0; i < count; i++) {
    const wallet = ethers.Wallet.createRandom();
    addresses.push(wallet.address);
  }
  return addresses;
}

async function main() {
  console.log(`Deploying to ${networkConfig.name}...`);
  
  // Connect to the network
  const provider = new ethers.providers.JsonRpcProvider(networkConfig.url);
  
  // Load the private key from the .env file
  const privateKey = process.env.PRIVATE_KEY;
  if (!privateKey) {
    throw new Error("Private key not found in .env file");
  }
  
  // Create a wallet instance
  const wallet = new ethers.Wallet(privateKey, provider);
  console.log(`Using wallet address: ${wallet.address}`);
  
  // Check wallet balance
  const balance = await wallet.getBalance();
  console.log(`Wallet balance: ${ethers.utils.formatEther(balance)} ETH`);
  
  if (balance.eq(0)) {
    throw new Error("Wallet has no ETH. Please fund it before deploying.");
  }
  
  // Create a contract factory
  const factory = new ethers.ContractFactory(
    contractJson.abi,
    contractJson.bytecode,
    wallet
  );
  
  // Deploy the contract
  console.log("Deploying NFT contract...");
  const contract = await factory.deploy(wallet.address);
  await contract.deployed();
  console.log(`Contract deployed to: ${contract.address}`);
  
  // Save the contract address and ABI to a file
  const deployData = {
    network: networkConfig.name,
    contractAddress: contract.address,
    ownerAddress: wallet.address,
    deploymentTime: new Date().toISOString()
  };
  fs.writeFileSync('deployment-info.json', JSON.stringify(deployData, null, 2));
  console.log("Deployment info saved to deployment-info.json");
  
  // Generate 50 random addresses for the airdrop
  console.log("Generating 50 random addresses for airdrop...");
  const recipients = generateRandomAddresses(50);
  
  // Save the list of airdrop recipients to a file
  fs.writeFileSync('airdrop-recipients.json', JSON.stringify(recipients, null, 2));
  console.log("Airdrop recipients saved to airdrop-recipients.json");
  
  // Airdrop NFTs to the generated addresses
  console.log("Airdropping NFTs to 50 addresses...");
  const airdropTx = await contract.airdropNFTs(recipients);
  const receipt = await airdropTx.wait();
  console.log(`Airdrop successful! Transaction hash: ${receipt.transactionHash}`);
  console.log(`Gas used: ${receipt.gasUsed.toString()}`);
  
  // Verify airdrop success
  const totalMinted = await contract.totalMinted();
  console.log(`Total minted NFTs: ${totalMinted.toString()}`);
  
  console.log("\nDeployment and airdrop completed successfully!");
  console.log(`Contract Address: ${contract.address}`);
  console.log(`View on Explorer: https://sepolia.basescan.org/address/${contract.address}`);
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  }); 