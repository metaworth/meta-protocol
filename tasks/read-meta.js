require('@nomiclabs/hardhat-ethers')

const contractAddress = process.env.META_IMPL_CONTRACT_ADDRESS

const abi = [
  'function getPrice() public view returns (uint256)',
]

// npx hardhat --network mumbai readMeta
task('readMeta', 'Fetch data from meta implementation contract')
  .setAction(async () => {
    const signer = await ethers.getSigner()
    console.log('signer:', signer.address)

    console.log('meta implementation contract address:', contractAddress)
    const metaImplContract = new ethers.Contract(contractAddress, abi, signer)

    const price = await metaImplContract.getPrice()
    console.log('The price in Wei:', price.toString())
    console.log('The price in ether is:', ethers.utils.formatEther(price).toString())
  })

module.exports = {}
