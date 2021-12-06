const { ethers } = require('hardhat');

async function main() {
  const signer = await ethers.getSigner();
  const address = await signer.getAddress();
  console.log('signer address:', address);

  try {
    const MetaImplementation = await ethers.getContractFactory('MetaImplementation');
    console.log('Deploying MetaImplementation...');
    const metaImpl = await MetaImplementation.deploy('1','10','1','1','','Metaworth.io','META');
    console.log('MetaImplementation deployment hash:', metaImpl.deployTransaction.hash)
    await metaImpl.deployed();
    console.log('MetaImplementation deployed to:', metaImpl.address);
  } catch (e) {
    console.error('Error:', e);
  }
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
