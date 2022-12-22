// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "openzeppelin-contracts/proxy/Clones.sol";
import "./WhiteWhale.sol";

contract WhiteWhaleFactory {
    address whiteWhale;

    event GameDeployed(address game);

    constructor(address _whiteWhale) {
        whiteWhale = _whiteWhale;
    }

    function deploy(string memory name, string memory symbol)
        external
        returns (address)
    {
        address clone = Clones.clone(whiteWhale);

        WhiteWhale(clone).initialize(name, symbol, msg.sender);

        emit GameDeployed(clone);

        return clone;
    }
}
