// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

/**
 * @title MockERC20RevertOnTransfer
 * @notice Mock que revierte en `transfer`/`transferFrom` para tests de fallo de transferencia.
 */
contract MockERC20RevertOnTransfer is ERC20 {
    error AlwaysRevert();

    constructor() ERC20("Bad", "BAD") {}

    function mint(address to, uint256 amount) external {
        _mint(to, amount);
    }

    function transfer(address, uint256) public pure override returns (bool) {
        revert AlwaysRevert();
    }

    function transferFrom(address, address, uint256) public pure override returns (bool) {
        revert AlwaysRevert();
    }
}
