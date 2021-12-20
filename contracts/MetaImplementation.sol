// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Burnable.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/utils/Strings.sol";
import "./extensions/RandomlyAssigned.sol";

import "hardhat/console.sol";


/// @dev this is the non-upgradeable implementation
contract MetaImplementation is
    ERC721,
    ERC721Enumerable,
    ERC721URIStorage,
    ERC721Burnable,
    Ownable,
    Pausable,
    RandomlyAssigned
  {
    enum SaleStatus { PENDING, STARTED, PAUSED, ENDED }

    uint256 public maxTokensPerWallet;
    string public baseURI;
    string public baseExtension;

    uint256 internal price;
    uint256 internal reserved;
    SaleStatus internal saleStatus;

    bool private _noContractMint;

    event MetaMintCompleted(address indexed _owner, uint256 indexed _tokenId);
    event BatchMintCompleted(address indexed _owner, uint256[] _tokenIds);

    constructor(
        uint256 _startPrice,
        uint256 _maxSupply,
        uint256 _reserved,
        uint256 _maxTokensPerWallet,
        SaleStatus _saleStatus,
        string memory _uri,
        string memory _name,
        string memory _symbol
    ) ERC721(_name, _symbol) RandomlyAssigned(_maxSupply, 1) {
        price = _startPrice;
        reserved = _reserved;
        maxTokensPerWallet = _maxTokensPerWallet;
        baseURI = _uri;
        saleStatus = _saleStatus;
    }

    /// @dev Check if the sale is started
    modifier whenSaleStarted() {
        require(saleStatus == SaleStatus.STARTED, "Sale not started yet");
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
        if (!_noContractMint) {
            require(tx.origin == _msgSender(), "MetaImplementation#mint: cannot mint NFTs through a contract");
        }
        
        // The owner of this contract do not need to pay ethers to mint
        //   and no constraints on the number of NFTs in the same wallet
        if (_msgSender() != owner()) {
            require(msg.value >= price, "MetaImplementation#mint: inconsistent amount sent");
            console.log("%s balance: %s - %s", _msgSender(), balanceOf(_msgSender()), maxTokensPerWallet);
        }

        if (maxTokensPerWallet > 0) {
            require(balanceOf(_msgSender()) < maxTokensPerWallet, "MetaImplementation#mint: exceeded the max tokens per wallet");
        }

        _safeMint(_msgSender(), _tokenId);
        _setTokenURI(_tokenId, _tokenURI);
        emit MetaMintCompleted(_msgSender(), _tokenId);
    }

    /// @dev Helper to list all the NFTs of a wallet
    /// @param _owner the wallet address to be checked for
    function walletOfOwner(address _owner) external view returns(uint256[] memory) {
        uint256 tokenCount = balanceOf(_owner);

        uint256[] memory tokenIds = new uint256[](tokenCount);
        for (uint256 i; i < tokenCount; i++) {
            tokenIds[i] = tokenOfOwnerByIndex(_owner, i);
        }
        return tokenIds;
    }

    /**
     * @dev The owner of this contract can claim a number of reserved NFTs
     * @param _number The number of NFTs are going to be minted
     * @param _receiver The wallet that will receive the minted NFTs
     */
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
    function setBaseURI(string calldata _newBaseURI) external onlyOwner {
        baseURI = _newBaseURI;
    }

    function setBaseExtension(string calldata _newBaseExtension) external onlyOwner {
        baseExtension = _newBaseExtension;
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

    function getReservedLeft() public view returns (uint256) {
        return reserved;
    }

    /// @dev Get the version of the current implementation
    function getVersion() public pure returns (string memory) {
      return "v1.0.0";
    }

    function getPrice() public view returns (uint256) {
        return price;
    }

    function getSaleStatus() public view returns(SaleStatus) {
        return saleStatus;
    }
    
    function tokenURI(uint256 tokenId)
        public
        view
        virtual
        override(ERC721, ERC721URIStorage)
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
        override(ERC721, ERC721Enumerable)
        returns (bool)
    {
        return super.supportsInterface(interfaceId);
    }

    function _burn(uint256 tokenId)
        internal
        override(ERC721, ERC721URIStorage)
    {
        super._burn(tokenId);
    }

    function _beforeTokenTransfer(address from, address to, uint256 tokenId)
        internal
        override(ERC721, ERC721Enumerable)
        whenNotPaused
    {
        super._beforeTokenTransfer(from, to, tokenId);
    }

    function _baseURI() internal view override returns (string memory) {
        return baseURI;
    }
}
