const { ethers, upgrades } = require('hardhat');

async function main() {
  const signer = await ethers.getSigner();
  const address = await signer.getAddress();
  console.log('signer address:', address);

  try {
    const MetaFactory = await ethers.getContractFactory('MetaFactory');
    console.log('Deploying MetaFactory...');
    const metaFactory = await upgrades.deployProxy(MetaFactory);
    console.log('MetaFactory deployment hash:', metaFactory.hash)
    await metaFactory.deployed();
    console.log('MetaFactory deployed to:', metaFactory.address);
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
