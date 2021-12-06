const { ethers, upgrades } = require('hardhat');

async function main() {
  const signer = await ethers.getSigner();
  const address = await signer.getAddress();
  console.log('signer address:', address);

  try {
    const MetaImplementationUpgradeable = await ethers.getContractFactory('MetaImplementationUpgradeable');
    console.log('Upgrading MetaImplementationUpgradeable...');
    const metaImpl = await upgrades.upgradeProxy(MetaImplementationUpgradeable, ['1','10','1','1','','Metaworth.io','META']);
    console.log('MetaImplementation upgrade hash:', metaImpl)
    await metaImpl.deployed();
    console.log('MetaImplementation upgraded');
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
