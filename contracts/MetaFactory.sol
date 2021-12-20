// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;


import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/ClonesUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/security/PausableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/ERC1967/ERC1967UpgradeUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";

import "hardhat/console.sol";

import "./MetaImplementationUpgradeable.sol";


/// @dev The meta factory contract that creates the meta contract based on corresponding parameters
contract MetaFactory is Initializable, OwnableUpgradeable, PausableUpgradeable, UUPSUpgradeable {

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

    function createNFT(
        bytes32 salt,
        uint256 _startPrice,
        uint256 _maxSupply,
        uint256 _nReserved,
        uint256 _maxTokensPerMint,
        string memory _uri,
        string memory _name,
        string memory _symbol
    ) external whenNotPaused returns (address) {
        MetaImplementationUpgradeable meta = MetaImplementationUpgradeable(ClonesUpgradeable.cloneDeterministic(metaMaster, salt));
        console.log("meta impl address: %s", address(meta));
        
        meta.initialize(
            _startPrice,
            _maxSupply,
            _nReserved,
            _maxTokensPerMint,
            _uri,
            _name,
            _symbol
        );

        console.log("initialized");

        meta.transferOwnership(_msgSender());

        emit MetaDeployed(_msgSender(), address(meta));
        return address(meta);
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

    function _authorizeUpgrade(address) internal override onlyOwner {}
}
