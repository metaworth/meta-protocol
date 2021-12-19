const { ethers, waffle, upgrades } = require('hardhat')
const { expect } = require('chai')

const arrayOfLength = length => Array.from({length}, (_, i) => i + 1)
const MAX_SUPPLY = '20'
const NUM_RESERVED = '1'
const MAX_TKN_PER_WALLET = '1'
const URI = ''
const NAME = 'Meta Test'
const SYMBOL = 'MT'
const PRICE = '0.03'


describe('MetaNFTs', function () {
  before(async function () {
    this.signers = await ethers.getSigners()
    this.signer = this.signers[0]
    this.bob = this.signers[1]
    this.carol = this.signers[2]
    this.MetaMaster = await ethers.getContractFactory('MetaImplementationUpgradeable')
    const MetaFactory = await ethers.getContractFactory('MetaFactory')
    this.metaFactory = await upgrades.deployProxy(MetaFactory)
    await this.metaFactory.deployed()
  })

  beforeEach(async function () {
    this.metaImplAddr = ''

    const bytes32 = ethers.utils.formatBytes32String('meta' + new Date().getTime())
    const predictedAddr = await this.metaFactory.predictMetaAddress(bytes32)
    const tx = await this.metaFactory.createNFT(
      bytes32,
      ethers.utils.parseEther(PRICE),
      MAX_SUPPLY,
      NUM_RESERVED,
      MAX_TKN_PER_WALLET,
      0,
      URI,
      NAME,
      SYMBOL
    )
    let receipt = await tx.wait()
    if (receipt.events) {
      const deployedAddr = receipt.events
      .filter(x => { return x.event == 'MetaDeployed' })
      .map(v => v.args['_metaAddress'])
      this.metaImplAddr = deployedAddr && deployedAddr[0]
    }
    
    expect(this.metaImplAddr).equals(predictedAddr)

    this.metaImplementation = await this.MetaMaster.attach(predictedAddr)
  })

  it('Should attach the correct meta implementation contract', async function () {
    expect(await this.metaFactory.owner()).equal(this.signer.address)
    expect(this.metaImplAddr).to.be.not.null
    expect(await this.metaImplementation.symbol()).to.equal(SYMBOL);
    expect(this.metaImplementation.address).equal(this.metaImplAddr)
    expect(await this.metaImplementation.owner()).equal(this.signer.address)
    
    const price = await this.metaImplementation.getPrice()
    expect(ethers.utils.formatEther(price).toString()).equal(PRICE)
  })

  it('Meta implementation should set the specified max supply', async function () {
    expect(this.metaImplAddr).to.be.not.null
    expect(await this.metaImplementation.maxSupply()).to.equal(20)
  })

  it('Should be failing to mint if the sale is not in started status', async function () {
    expect(this.metaImplementation.connect(this.signer).mint('ipfs://carols.com/6.json')).to.be.revertedWith('Sale not started')
  })

  it('Should mint all tokens except the reserved in random order with signer\'s wallet without paying', async function () {
    const availableSupply = await this.metaImplementation.availableTokenCount()
    const resevedLeft = await this.metaImplementation.getReservedBalance()

    // get the available NFTs to be minting
    const size = Number(availableSupply) - Number(resevedLeft)
    const incrementingTokenIds = arrayOfLength(size)
    const tokenIDs = []
    let sold = 0

    let saleStatus = await this.metaImplementation.getSaleStatus()
    expect(saleStatus).equal(0)

    const saleStartTx = await this.metaImplementation.setSaleStatus('1')
    await saleStartTx.wait()

    saleStatus = await this.metaImplementation.getSaleStatus()
    expect(saleStatus).equal(1)

    while (sold < size) {
      const transaction = await this.metaImplementation.connect(this.signer).mint('ipfs://carols.com/7.json')
      const receipt = await transaction.wait()
      const tokenID = receipt.events.find(e => e.event === 'Transfer').args.tokenId
      tokenIDs.push(parseInt(tokenID.toString()))
      sold++
    }
    console.log('token IDs:', tokenIDs)
    expect(tokenIDs).to.not.eql(incrementingTokenIds)
  })

  it('Should be succeeded to mint if using a non-owner wallet with paying 0.03 ether', async function () {
    const saleStartTx = await this.metaImplementation.setSaleStatus('1')
    await saleStartTx.wait()

    const transaction = await this.metaImplementation.connect(this.bob).mint('ipfs://carols.com/8.json', { value: ethers.utils.parseEther('0.03') })
    const receipt = await transaction.wait()
    const tokenID = receipt.events.find(e => e.event === 'Transfer').args.tokenId

    expect(tokenID).to.not.undefined
    expect(tokenID).to.not.null

    const balanceOfEther = await this.metaImplementation.provider.getBalance(this.metaImplementation.address)
    expect(balanceOfEther.toString()).equal(ethers.utils.parseEther('0.03').toString())

    const tokenURI = await this.metaImplementation.tokenURI(tokenID)
    expect(tokenURI.toString()).equal('ipfs://carols.com/8.json')
  })

  it('Should be able to withdraw remaining balance to Carols wallet by using owner\'s wallet', async function () {
    const provider = waffle.provider

    let balanceOfCarolWalletBeforeWithdraw = await provider.getBalance(this.carol.address)

    const saleStartTx = await this.metaImplementation.setSaleStatus('1')
    await saleStartTx.wait()

    const transaction = await this.metaImplementation.connect(this.bob).mint('ipfs://carols.com/1.json', { value: ethers.utils.parseEther('0.03') })
    await transaction.wait()

    const balanceOfEther = await this.metaImplementation.provider.getBalance(this.metaImplementation.address)
    expect(balanceOfEther.toString()).equal(ethers.utils.parseEther('0.03').toString())

    const withdrawTx = await this.metaImplementation.withdraw(this.carol.address)
    await withdrawTx.wait()

    balanceOfCarolWallet = await provider.getBalance(this.carol.address)
    expect(balanceOfCarolWallet.sub(ethers.utils.parseEther('0.03'))).equal(balanceOfCarolWalletBeforeWithdraw)
  })

  it('Should be failing to claim the reserved if the sender is not owner', async function () {
    await expect(this.metaImplementation.connect(this.carol.address).claimReserved(1, this.carol.address))
      .to.be.revertedWith('Ownable: caller is not the owner')
  })

  it('Should be failing to claim the reserved if the claim number greater than reserved', async function () {
    await expect(this.metaImplementation.claimReserved(Number(NUM_RESERVED) + 1, this.carol.address))
      .to.be.revertedWith('MetaImplementation#claimReserved: reached the max reserved')
  })

  it('Should be able to claim the reserved by the owner', async function () {
    let tokenIdsForBob = await this.metaImplementation.walletOfOwner(this.bob.address)
    expect(tokenIdsForBob.length).equal(0)

    const claimReservedTx = await this.metaImplementation.claimReserved(1, this.bob.address)
    await claimReservedTx.wait()

    tokenIdsForBob = await this.metaImplementation.walletOfOwner(this.bob.address)
    expect(tokenIdsForBob.length).equal(1)

    const resevedLeft = await this.metaImplementation.getReservedBalance()
    expect(resevedLeft).to.be.equal(Number(NUM_RESERVED) - 1)
  })

  it('Should batch mint without errors', async function () {
    const saleStartTx = await this.metaImplementation.setSaleStatus('1')
    await saleStartTx.wait()

    const tokenURIs = ['ipfs://uri1', 'ipfs://uri2', 'ipfs://uri3', 'ipfs://uri4', 'ipfs://uri5']
    const batchMintTx = await this.metaImplementation.batchMint(tokenURIs)
    const receipt = await batchMintTx.wait()

    const tokenIDs = receipt.events.find(e => e.event === 'BatchMintCompleted').args._tokenIds
    for (let i = 0; i < tokenURIs.length; i++) {
      const uri = await this.metaImplementation.tokenURI(tokenIDs[i])
      expect(tokenURIs[i]).to.be.equal(uri)
    }

    expect(tokenIDs.length).to.equal(tokenURIs.length)
  })

  it('Should be failing to withdraw when the contracts balance is zero', async function () {
    const balanceOfEther = await this.metaImplementation.provider.getBalance(this.metaImplementation.address)
    expect(balanceOfEther.toString()).equal(ethers.utils.parseEther('0').toString())

    await expect(this.metaImplementation.withdraw(this.carol.address))
      .to.be.revertedWith('MetaImplementation#withdraw: no available balance')
  })

  it('Should not be able to mint if the contract is paused', async function () {
    const saleStartTx = await this.metaImplementation.setSaleStatus('1')
    await saleStartTx.wait()

    const pauseTx = await this.metaImplementation.pause()
    await pauseTx.wait()

    await expect(this.metaImplementation.mint('ipfs://carols.com/2.json')).to.be.revertedWith('Pausable: paused')
  })

  it('Should be failed to mint becaused of the max NFTs per wallet constraints', async function () {
    const saleStartTx = await this.metaImplementation.setSaleStatus('1')
    await saleStartTx.wait()

    let tokenIdsForBob = await this.metaImplementation.walletOfOwner(this.bob.address)
    expect(tokenIdsForBob.length).equal(0)

    const mintTx = await this.metaImplementation.connect(this.bob).mint('ipfs://carols.com/3.json', { value: ethers.utils.parseEther('0.03') })
    await mintTx.wait()

    tokenIdsForBob = await this.metaImplementation.walletOfOwner(this.bob.address)
    expect(tokenIdsForBob.length).equal(1)

    await expect(this.metaImplementation.connect(this.bob).mint('ipfs://carols.com/4.json', { value: ethers.utils.parseEther('0.03') }))
      .to.be.revertedWith('MetaImplementation#mint: exceeded the max tokens per wallet')
  })

  it('Should fail to mint if using a non-owner wallet without paying 0.03 ether', async function () {
    const saleStartTx = await this.metaImplementation.setSaleStatus('1')
    await saleStartTx.wait()

    expect(this.metaImplementation.connect(this.bob).mint('ipfs://carols.com/5.json')).to.be.revertedWith('MetaImplementation#mint: inconsistent amount sent')
  })

})
