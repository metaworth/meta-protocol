const { ethers, upgrades } = require('hardhat');

async function main() {
  const signer = await ethers.getSigner();
  const address = await signer.getAddress();
  console.log('signer address:', address);

  try {
    const ERC721Base = await ethers.getContractFactory('ERC721Base');
    console.log('Deploying upgradeable ERC721Base...');
    const cardContract = await upgrades.deployProxy(ERC721Base, ['Metaworth Card', 'MC'], { kind: 'uups', unsafeAllow: ['delegatecall'] });
    console.log('ERC721Base deployment hash:', cardContract.deployTransaction.hash)
    await cardContract.deployed();
    console.log('ERC721Base deployed to:', cardContract.address);
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
