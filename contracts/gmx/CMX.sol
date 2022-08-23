// SPDX-License-Identifier: MIT

pragma solidity 0.6.12;

import "../tokens/MintableBaseToken.sol";

contract CMX is MintableBaseToken {
    constructor() public MintableBaseToken("CMX", "CMX", 0) {
    }

    function id() external pure returns (string memory _name) {
        return "CMX";
    }
}
