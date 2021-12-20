require('@nomiclabs/hardhat-ethers')

const contractAddress = '0x6A59CC73e334b018C9922793d96Df84B538E6fD5' || process.env.META_FACTORY_CONTRACT_ADDRESS

const abi = [
  'event MetaDeployed(address indexed _owner, address indexed _metaAddress)',
  'function predictMetaAddress(bytes32 salt) external view returns (address)',
  'function createNFT(bytes32 salt, uint256 _startPrice, uint256 _maxSupply, uint256 _nReserved, uint256 _maxTokensPerMint, string memory _uri, string memory _name, string memory _symbol) external returns (address)',
  'function getVersion() public pure returns (string memory)'
]

// npx hardhat --network mumbai newMeta
task('newMeta', 'Create a new meta contract')
  .setAction(async () => {
    const signer = await ethers.getSigner()
    const address = await signer.getAddress()
    console.log('signer address:', address)

    const metaFactoryContract = new ethers.Contract(contractAddress, abi, signer)

    const bytes32 = ethers.utils.formatBytes32String('metaworth' + new Date().getTime())
    console.log('bytes32:', bytes32)

    const predictedAddr = await metaFactoryContract.predictMetaAddress(bytes32)
    console.log('predicted addr:', predictedAddr)

    const createNFT = await metaFactoryContract.createNFT(
      bytes32,
      ethers.utils.parseEther('0'),
      '10',
      '0',
      '0',
      '',
      'Test OK',
      'TO',
    )
    console.log('createNFT tx hash:', createNFT.hash)
    const receipt = await createNFT.wait()
    if (receipt.events) {
      const deployedAddr = receipt.events
        .filter(x => { return x.event == 'MetaDeployed' })
        .map(v => v.args['_metaAddress'])
      const metaImplAddr = deployedAddr && deployedAddr[0]
      console.log('meta implementation deployed to:', metaImplAddr)
    }
  })

module.exports = {}
