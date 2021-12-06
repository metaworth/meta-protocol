// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;


import "@openzeppelin/contracts/proxy/Clones.sol";

import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/ClonesUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/security/PausableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";

import "./MetaImplementationUpgradeable.sol";


/// @dev The meta factory contract that creates the meta contract based on corresponding parameters
contract MetaFactory is Initializable, OwnableUpgradeable, PausableUpgradeable, ReentrancyGuardUpgradeable, UUPSUpgradeable {

    address public metaMaster;

    event MetaDeployed(address indexed _owner, address indexed _metaAddress);

    function initialize() public initializer {
        __Ownable_init();
        metaMaster = address(new MetaImplementationUpgradeable());
    }

    function predictMetaAddress(bytes32 salt) external view returns (address) {
        require(metaMaster != address(0), "master must be set");

        return ClonesUpgradeable.predictDeterministicAddress(metaMaster, salt);
    }

    // "0x6e616d6100000000000000000000000000000000000000000000000000000000","1","10","1","1","ipfs://","Test OK","TO"
    function createNFT(
        bytes32 salt,
        uint256 _startPrice,
        uint256 _maxSupply,
        uint256 _nReserved,
        uint256 _maxTokensPerMint,
        MetaImplementationUpgradeable.SaleStatus _saleStatus,
        string memory _uri,
        string memory _name,
        string memory _symbol
    ) external whenNotPaused returns (address) {
        MetaImplementationUpgradeable meta = MetaImplementationUpgradeable(ClonesUpgradeable.cloneDeterministic(metaMaster, salt));

        meta.initialize(
            _startPrice,
            _maxSupply,
            _nReserved,
            _maxTokensPerMint,
            _saleStatus,
            _uri,
            _name,
            _symbol
        );

        meta.transferOwnership(_msgSender());

        emit MetaDeployed(_msgSender(), address(meta));
        return address(address(meta));
    }

    function newMetaMaster(address _metaMaster) external whenNotPaused onlyOwner {
        metaMaster = _metaMaster;
    }

    function pause() external onlyOwner {
        _pause();
    }

    function unpause() external onlyOwner {
        _unpause();
    }

    function _authorizeUpgrade(address newImplementation) internal override onlyOwner {}
}
