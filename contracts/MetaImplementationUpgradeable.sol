// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import "@openzeppelin/contracts-upgradeable/token/ERC721/ERC721Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC721/extensions/ERC721EnumerableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC721/extensions/ERC721BurnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC721/extensions/ERC721URIStorageUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/security/PausableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/CountersUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/StringsUpgradeable.sol";

import "./extensions/RandomlyAssignedUpgradeable.sol";

import "hardhat/console.sol";

/// @title This is an upgradeable implementation.
/// The constructor is replaced with initializer.
/// In this way, we're saving a lot of the deployment costs.
contract MetaImplementationUpgradeable is
    Initializable,
    ERC721Upgradeable,
    ERC721EnumerableUpgradeable,
    ERC721URIStorageUpgradeable,
    ERC721BurnableUpgradeable,
    OwnableUpgradeable,
    PausableUpgradeable,
    RandomlyAssignedUpgradeable,
    UUPSUpgradeable
  {
    enum SaleStatus { PENDING, STARTED, PAUSED, ENDED }

    uint256 public maxTokensPerWallet;
    string public baseURI;
    string public baseExtension;

    uint256 internal price;
    uint256 internal reserved;

    bool private _noContractMint;
    SaleStatus internal saleStatus;

    event MetaMintCompleted(address indexed _owner, uint256 indexed _tokenId);
    event BatchMintCompleted(address indexed _owner, uint256[] _tokenIds);

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
        __Ownable_init();
        __RandomlyAssigned_init(_maxSupply, 1);

        price = _startPrice;
        reserved = _nReserved;
        maxTokensPerWallet = _maxTokensPerWallet;
        baseURI = _uri;
        saleStatus = SaleStatus.STARTED;
    }

    /// @dev This constructor ensures that this contract can only be used as a master copy
    /// Marking constructor as initializer makes sure that real initializer cannot be called
    /// Thus, as the owner of the contract is 0x0, no one can do anything with the contract
    /// on the other hand, it's impossible to call this function in proxy,
    /// so the real initializer is the only initializer
    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() initializer {}

    /// @dev Check if the sale is started
    modifier whenSaleStarted() {
        require(saleStatus == SaleStatus.STARTED, "Sale not started");
        _;
    }

    function batchMint(string[] calldata _tokenURIs) external whenSaleStarted onlyOwner returns (uint256[] memory) {
        uint256[] memory _tokenIds = new uint256[](_tokenURIs.length);
        require(tokenCount() + _tokenURIs.length <= maxSupply() - reserved, "MetaImplementation#batchMint: no enough NFTs left");

        for (uint i = 0; i < _tokenURIs.length; i++) {
            uint256 _tokenId = nextToken();
            _safeMint(_msgSender(), _tokenId);
            _setTokenURI(_tokenId, _tokenURIs[i]);
            _tokenIds[i] = _tokenId;
        }

        emit BatchMintCompleted(_msgSender(), _tokenIds);
        return _tokenIds;
    }

    function mint(string memory _tokenURI) external payable whenSaleStarted {
        uint256 _tokenId = nextToken();
        console.log("max supply: %s - %s || %s", maxSupply(), reserved, tokenCount());
        require(tokenCount() <= maxSupply() - reserved, "MetaImplementation#mint: no enough NFTs left");

        // Checking if the sender is from a intermediary contract
        if (_noContractMint) {
            require(tx.origin == _msgSender(), "MetaImplementation#mint: cannot mint NFTs through a contract");
        }
        
        // The owner of this contract do not need to pay ethers to mint
        //   and no constraints on the number of NFTs in the same wallet
        if (_msgSender() != owner()) {
            require(msg.value >= price, "MetaImplementation#mint: inconsistent amount sent");
            console.log("%s balance: %s - %s", _msgSender(), balanceOf(_msgSender()), maxTokensPerWallet);

            if (maxTokensPerWallet > 0) {
                require(balanceOf(_msgSender()) < maxTokensPerWallet, "MetaImplementation#mint: exceeded the max tokens per wallet");
            }
        }

        _safeMint(_msgSender(), _tokenId);
        _setTokenURI(_tokenId, _tokenURI);
        emit MetaMintCompleted(_msgSender(), _tokenId);
    }

    /// @dev Helper to list all the NFTs of a wallet
    /// @param _owner the wallet address to be checked for
    function walletOfOwner(address _owner) external view returns(uint256[] memory) {
        uint256 tokenCount = balanceOf(_owner);

        uint256[] memory tokensId = new uint256[](tokenCount);
        for(uint256 i; i < tokenCount; i++) {
            tokensId[i] = tokenOfOwnerByIndex(_owner, i);
        }
        return tokensId;
    }

    function claimReserved(uint256 _number, address _receiver)
        external
        ensureAvailabilityFor(_number)
        onlyOwner
    {
        require(_number > 0 && _number <= reserved, "MetaImplementation#claimReserved: reached the max reserved");

        for (uint256 i; i < _number; i++) {
            _safeMint(_receiver, nextToken());
        }

        reserved -= _number;
    }

    /// @dev Withdraw remaining balance to the specified _beneficiary if it's not zero address,
    ///   otherwise, send the balance to the contract owner
    function withdraw(address _beneficiary) public onlyOwner {
        uint256 _balance = address(this).balance;
        require(_balance > 0, "MetaImplementation#withdraw: no available balance");
        
        if (_beneficiary != address(0)) {
            require(payable(_beneficiary).send(_balance));
        } else {
            require(payable(_msgSender()).send(_balance));
        }
    }

    /// @dev Set the base URI
    /// TODO this might be removed in the future if the base URI cannot be updated
    ///   onced it setup when the contract was initialized
    function setBaseURI(string calldata uri) external onlyOwner {
        baseURI = uri;
    }

    function setBaseExtension(string calldata _baseExtension) external onlyOwner {
        baseExtension = _baseExtension;
    }

    function setReserved(uint256 _reserved) external onlyOwner {
        reserved = _reserved;
    }

    /// @dev Update the sale status
    /// @param _status the new status 
    function setSaleStatus(SaleStatus _status) external onlyOwner {
        saleStatus = _status;
    }

    function disableContractMinting() external onlyOwner {
        _noContractMint = false;
    }

    function enableContractMinting() external onlyOwner {
        _noContractMint = true;
    }

    function setPrice(uint256 _newPrice) external onlyOwner {
        price = _newPrice;
    }

    function pause() public whenNotPaused onlyOwner {
        _pause();
    }

    function unpause() public whenPaused onlyOwner {
        _unpause();
    }

    function getPrice() public view returns (uint256) {
        return price;
    }

    function getSaleStatus() public view returns(SaleStatus) {
        return saleStatus;
    }

    function getReservedBalance() public view returns (uint256) {
        return reserved;
    }

    /// @dev Get the version of the current implementation
    function getVersion() public pure returns (string memory) {
      return "v1.0.0";
    }
    
    function tokenURI(uint256 tokenId)
        public
        view
        virtual
        override(ERC721Upgradeable, ERC721URIStorageUpgradeable)
        returns (string memory)
    {
        string memory _tokenURI = super.tokenURI(tokenId);

        return bytes(baseExtension).length > 0
            ? string(abi.encodePacked(_tokenURI, baseExtension))
            : _tokenURI;
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
        whenNotPaused
    {
        super._beforeTokenTransfer(from, to, tokenId);
    }

    function _burn(uint256 tokenId)
        internal
        override(ERC721Upgradeable, ERC721URIStorageUpgradeable)
    {
        super._burn(tokenId);
    }

    function _authorizeUpgrade(address) internal override onlyOwner {}
}
