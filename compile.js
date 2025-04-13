const fs = require('fs');
const solc = require('solc');

function compile() {
  // Read the Solidity contract source
  const source = fs.readFileSync('nft.sol', 'utf8');
  
  // Prepare input for solc compiler
  const input = {
    language: 'Solidity',
    sources: {
      'nft.sol': {
        content: source
      }
    },
    settings: {
      outputSelection: {
        '*': {
          '*': ['abi', 'evm.bytecode']
        }
      },
      optimizer: {
        enabled: true,
        runs: 200
      }
    }
  };
  
  console.log('Compiling contract...');
  
  // Compile the contract
  const output = JSON.parse(solc.compile(JSON.stringify(input)));
  
  // Check for errors
  if (output.errors) {
    output.errors.forEach(error => {
      console.error(error.formattedMessage);
    });
    
    // Only throw if there are actual errors, not warnings
    if (output.errors.some(error => error.severity === 'error')) {
      throw new Error('Compilation failed');
    }
  }
  
  // Get contract artifacts
  const contractName = 'BTBFinanceNFT'; // This must match the contract name in the source
  const contract = output.contracts['nft.sol'][contractName];
  
  if (!contract) {
    throw new Error(`Contract ${contractName} not found in compilation output`);
  }
  
  // Extract ABI and bytecode
  const artifact = {
    abi: contract.abi,
    bytecode: contract.evm.bytecode.object
  };
  
  // Write artifacts to file
  fs.writeFileSync(
    'contract-artifact.json',
    JSON.stringify(artifact, null, 2)
  );
  
  console.log('Compilation successful!');
  console.log('ABI and bytecode saved to contract-artifact.json');
  
  // Update the deploy.js script to use these artifacts
  let deployScript = fs.readFileSync('deploy.js', 'utf8');
  deployScript = deployScript.replace(
    /const contractJson = \{[\s\S]*?bytecode: "0x..."\s*\};/,
    `const contractJson = ${JSON.stringify(artifact, null, 2)};`
  );
  fs.writeFileSync('deploy.js', deployScript);
  
  console.log('deploy.js updated with the compiled artifacts');
  
  return artifact;
}

try {
  compile();
} catch (error) {
  console.error('Compilation error:', error.message);
  process.exit(1);
} 