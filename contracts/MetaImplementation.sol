// SPDX-License-Identifier: MIT
pragma solidity ^0.8.7;

import "@openzeppelin/contracts-upgradeable/token/ERC721/ERC721Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC721/extensions/ERC721EnumerableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";


// This is an upgradeable implementation.
// The constructor is replaced with initializer.
// This way, saving a buntch of the deployment costs, about 350k gas instead of 4.5M.
contract MetaImplementation is ERC721Upgradeable, ERC721EnumerableUpgradeable, OwnableUpgradeable {

    uint256 internal _price; // = 0.03 ether;
    uint256 internal _reserved; // = 200;

    uint256 public MAX_SUPPLY; // = 10000;
    uint256 public MAX_TOKENS_PER_WALLET; // = 2
    uint256 public startingIndex;

    bool private _saleStarted;

    string public baseURI;

    function initialize(
        uint256 _startPrice,
        uint256 _maxSupply,
        uint256 _nReserved,
        uint256 _maxTokensPerWallet,
        string memory _uri,
        string memory _name,
        string memory _symbol
    ) public initializer {
        __ERC721_init(_name, _symbol);
        __ERC721Enumerable_init();
        __Ownable_init();

        _price = _startPrice;
        _reserved = _nReserved;
        MAX_SUPPLY = _maxSupply;
        MAX_TOKENS_PER_WALLET = _maxTokensPerWallet;
        baseURI = _uri;
    }

    // This constructor ensures that this contract can only be used as a master copy
    // Marking constructor as initializer makes sure that real initializer cannot be called
    // Thus, as the owner of the contract is 0x0, no one can do anything with the contract
    // on the other hand, it's impossible to call this function in proxy,
    // so the real initializer is the only initializer
    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() initializer {}

    modifier whenSaleStarted() {
        require(_saleStarted, "Sale not started");
        _;
    }

    function setBaseURI(string calldata uri) external onlyOwner {
        baseURI = uri;
    }

    function mint() external payable whenSaleStarted {
        uint256 supply = totalSupply();
        require(supply <= MAX_SUPPLY - _reserved, "Not enough Tokens left.");
        require(tx.origin == msg.sender, "CANNOT MINT THROUGH A CUSTOM CONTRACT");
        
        if (msg.sender != owner()) {
            require(msg.value >= _price, "Inconsistent amount sent!");
            require(balanceOf(msg.sender) <= MAX_TOKENS_PER_WALLET, "Exceeded the max tokens per wallet!");
        }

        _safeMint(msg.sender, supply + 1);
    }

    function kickoffSaleCampaign() external onlyOwner {
        _saleStarted = true;

        if (_saleStarted && startingIndex == 0) {
            setStartingIndex();
        }
    }
    
    function stopSaleCampaign() external onlyOwner {
        _saleStarted = false;   
    }

    function saleStarted() public view returns(bool) {
        return _saleStarted;
    }

    function setPrice(uint256 _newPrice) external onlyOwner {
        _price = _newPrice;
    }

    function getPrice() public view returns (uint256){
        return _price;
    }

    function getReservedLeft() public view returns (uint256) {
        return _reserved;
    }

    // Helper to list all the NFTs of a wallet
    function walletOfOwner(address _owner) external view returns(uint256[] memory) {
        uint256 tokenCount = balanceOf(_owner);

        uint256[] memory tokensId = new uint256[](tokenCount);
        for(uint256 i; i < tokenCount; i++) {
            tokensId[i] = tokenOfOwnerByIndex(_owner, i);
        }
        return tokensId;
    }

    function claimReserved(uint256 _number, address _receiver) external onlyOwner {
        require(_number <= _reserved, "That would exceed the max reserved.");

        uint256 _tokenId = totalSupply();
        for (uint256 i; i < _number; i++) {
            _safeMint(_receiver, _tokenId + i);
        }

        _reserved = _reserved - _number;
    }

    // NOTICE: This function is not meant to be called by the user.
    // Contrary to AvatarNFT, where it is public
    function setStartingIndex() internal onlyOwner {
        require(startingIndex == 0, "Starting index is already set");

        // BlockHash only works for the most 256 recent blocks.
        uint256 _block_shift = uint(keccak256(abi.encodePacked(block.difficulty, block.timestamp)));
        _block_shift =  1 + (_block_shift % 255);

        // This shouldn't happen, but just in case the blockchain gets a reboot?
        if (block.number < _block_shift) {
            _block_shift = 1;
        }

        uint256 _block_ref = block.number - _block_shift;
        startingIndex = uint(blockhash(_block_ref)) % MAX_SUPPLY;

        // Prevent default sequence
        if (startingIndex == 0) {
            startingIndex = 1;
        }
    }

    // withdraw remaining balance to the specified _beneficiary if it's not zero address,
    // otherwise, send the balance to the contract owner
    function withdraw(address _beneficiary) public onlyOwner {
        uint256 _balance = address(this).balance;
        require(_balance > 0, "#withdraw: no available balance");
        
        if (_beneficiary != address(0)) {
            require(payable(_beneficiary).send(_balance));
        } else {
            require(payable(msg.sender).send(_balance));
        }
    }
    
    function tokenURI(uint256 tokenId) public view virtual override returns (string memory) {
        require(
          _exists(tokenId),
          "ERC721Metadata: URI query for nonexistant token"
        );
    
        string memory currentBaseURI = _baseURI();
        return bytes(currentBaseURI).length > 0
            ? string(abi.encodePacked(currentBaseURI, tokenId, ".json"))
            : "";
    }

    function supportsInterface(bytes4 interfaceId)
        public
        view
        override(ERC721Upgradeable, ERC721EnumerableUpgradeable)
        returns (bool)
    {
        return super.supportsInterface(interfaceId);
    }
    
    function _baseURI() internal view override returns (string memory) {
        return baseURI;
    }
    
    function _beforeTokenTransfer(address from, address to, uint256 tokenId)
        internal
        override(ERC721Upgradeable, ERC721EnumerableUpgradeable)
    {
        super._beforeTokenTransfer(from, to, tokenId);
    }
}
