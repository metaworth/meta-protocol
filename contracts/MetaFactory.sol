// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;


import "@openzeppelin/contracts/proxy/Clones.sol";

import "./MetaImplementation.sol";

contract MetaFactory {

    address public immutable proxyImplementation;

    event NFTCreated(address indexed _owner, address indexed _metaAddress);

    constructor() {
        proxyImplementation = address(new MetaImplementation());
    }

    function createNFT(
        uint256 _startPrice,
        uint256 _maxSupply,
        uint256 _nReserved,
        uint256 _maxTokensPerMint,
        string memory _uri,
        string memory _name,
        string memory _symbol
    ) external {
        address clone = Clones.clone(proxyImplementation);

        MetaImplementation(clone).initialize(
            _startPrice,
            _maxSupply,
            _nReserved,
            _maxTokensPerMint,
            _uri,
            _name,
            _symbol
        );

        MetaImplementation(clone).transferOwnership(msg.sender);

        emit NFTCreated(msg.sender, clone);
    }

}
