// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import "./WithLimitedSupplyUpgradeable.sol";

/// @author Victor Feng and inpired by 1001.digital (https://github.com/1001-digital/erc721-extensions)
/// @title Upgradeable randomly assign tokenIDs from a given set of tokens.
abstract contract RandomlyAssignedUpgradeable is WithLimitedSupplyUpgradeable {
    // Used for random index assignment
    mapping(uint256 => uint256) private tokenMatrix;

    // The initial token ID
    uint256 private startFrom;

    /// Instanciate the contract
    /// @param _totalSupply how many tokens this collection should hold
    /// @param _startFrom the tokenID with which to start counting
    function __RandomlyAssigned_init(uint256 _totalSupply, uint256 _startFrom) internal initializer {
        __WithLimitedSupply_init(_totalSupply);
        __RandomlyAssigned_init_unchained(_totalSupply, _startFrom);
    }

    function __RandomlyAssigned_init_unchained(uint256 /* _totalSupply */, uint256 _startFrom) internal initializer {
        startFrom = _startFrom;
    }

    /// Get the next token ID
    /// @dev Randomly gets a new token ID and keeps track of the ones that are still available.
    /// @return the next token ID
    function nextToken() internal override ensureAvailability returns (uint256) {
        uint256 maxIndex = maxSupply() - tokenCount();
        uint256 random = uint256(keccak256(
            abi.encodePacked(
                msg.sender,
                block.coinbase,
                block.difficulty,
                block.gaslimit,
                block.timestamp
            )
        )) % maxIndex;

        uint256 value = 0;
        if (tokenMatrix[random] == 0) {
            // If this matrix position is empty, set the value to the generated random number.
            value = random;
        } else {
            // Otherwise, use the previously stored number from the matrix.
            value = tokenMatrix[random];
        }

        // If the last available tokenID is still unused...
        if (tokenMatrix[maxIndex - 1] == 0) {
            // ...store that ID in the current matrix position.
            tokenMatrix[random] = maxIndex - 1;
        } else {
            // ...otherwise copy over the stored number to the current matrix position.
            tokenMatrix[random] = tokenMatrix[maxIndex - 1];
        }

        // Increment counts
        super.nextToken();

        return value + startFrom;
    }

    // for why we need this reserved space, get more details from https://docs.openzeppelin.com/contracts/3.x/upgradeable#storage_gaps
    uint256[50] private __gap;
}
