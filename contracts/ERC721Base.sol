// SPDX-License-Identifier: BUSL-1.1

pragma solidity ^0.8.4;

import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC721/extensions/ERC721URIStorageUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC721/extensions/ERC721EnumerableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC721/extensions/ERC721BurnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/security/PausableUpgradeable.sol";
import "@openzeppelin/contracts/proxy/utils/UUPSUpgradeable.sol";


contract ERC721Base is
    Initializable,
    ERC721Upgradeable,
    ERC721EnumerableUpgradeable,
    ERC721URIStorageUpgradeable,
    ERC721BurnableUpgradeable,
    OwnableUpgradeable,
    PausableUpgradeable,
    UUPSUpgradeable
 {
    using Counters for Counters.Counter;

    Counters.Counter private _tokenIds;

    string public baseURI;
    string public baseExtension;

    bool private _noContractMint;

    event BatchMintCompleted(address indexed _owner, uint256[] _tokenIds);

    function initialize(string memory _name, string memory _symbol) initializer public {
        __Ownable_init();
        __ERC721_init(_name, _symbol);
        _tokenIds.increment();
        _noContractMint = true;
    }

    function batchMintWithSameURI(address[] calldata _addrs, string calldata _tokenURI) external returns (uint256[] memory) {
        require(bytes(_tokenURI).length > 0, "ERC721Base#batchMintWithSameURI: token URI is required");
        if (_noContractMint) {
            require(tx.origin == _msgSender(), "ERC721Base#batchMintWithSameURI: cannot mint NFTs through a contract");
        }

        uint256[] memory _tknIds = new uint256[](_addrs.length);

        for (uint i = 0; i < _addrs.length; i++) {
            uint256 _tokenId = _tokenIds.current();
            _safeMint(_addrs[i], _tokenId);
            _setTokenURI(_tokenId, _tokenURI);
            _tknIds[i] = _tokenId;
            _tokenIds.increment();
        }

        emit BatchMintCompleted(_msgSender(), _tknIds);
        return _tknIds;
    }

    function mint(address _to, string memory _cid) public onlyOwner whenNotPaused {
        // Checking if the sender is from a intermediary contract
        if (_noContractMint) {
            require(tx.origin == _msgSender(), "ERC721Base#mint: cannot mint NFTs through a contract");
        }

        _tokenIds.increment();

        uint256 newTokenId = _tokenIds.current();
        _safeMint(_to, newTokenId);
        _setTokenURI(newTokenId, _cid);
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

    /// @dev Set the base URI
    /// TODO this might be removed in the future if the base URI cannot be updated
    ///   onced it setup when the contract was initialized
    function setBaseURI(string calldata uri) external onlyOwner {
        baseURI = uri;
    }

    function setBaseExtension(string calldata _baseExtension) external onlyOwner {
        baseExtension = _baseExtension;
    }

    function pause() external onlyOwner {
        _pause();
    }

    function unpause() external onlyOwner {
        _unpause();
    }

    function disableContractMinting() external onlyOwner {
        _noContractMint = false;
    }

    function enableContractMinting() external onlyOwner {
        _noContractMint = true;
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

    function _authorizeUpgrade(address newImplementation) internal override onlyOwner {}
}
