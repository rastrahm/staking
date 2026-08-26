// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

/**
 * @title MockERC20Reentrant
 * @notice ERC-20 que reentra en `target` tras `transfer`/`transferFrom` y propaga el revert.
 */
contract MockERC20Reentrant is ERC20 {
    address public reenterTarget;
    bytes public reenterData;
    bool public reenterEnabled;
    uint256 public reenterCount;

    constructor(string memory name_, string memory symbol_) ERC20(name_, symbol_) {}

    function mint(address to, uint256 amount) external {
        _mint(to, amount);
    }

    function setReenter(address target, bytes calldata data) external {
        reenterTarget = target;
        reenterData = data;
        reenterEnabled = true;
    }

    function transfer(address to, uint256 amount) public override returns (bool) {
        bool ok = super.transfer(to, amount);
        _maybeReenter();
        return ok;
    }

    function transferFrom(address from, address to, uint256 amount) public override returns (bool) {
        bool ok = super.transferFrom(from, to, amount);
        _maybeReenter();
        return ok;
    }

    function _maybeReenter() private {
        if (!reenterEnabled || reenterTarget == address(0)) return;
        reenterEnabled = false;
        reenterCount += 1;
        (bool success, bytes memory ret) = reenterTarget.call(reenterData);
        if (!success) {
            assembly {
                revert(add(ret, 0x20), mload(ret))
            }
        }
        reenterEnabled = true;
    }
}
