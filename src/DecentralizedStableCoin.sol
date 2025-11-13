// SPDX-License-Identifier: MIT

pragma solidity ^0.8.19;

/**
 * @title Decentralized Stable Coin
 * @author Topgg
 * @Collateral: Exogenous (ETH & BTC)
 * @Minting: Algorithmic
 * @Relative Stability: Pegged to USD
 * @dev This is a minimal implementation of a Decentralized Stable Coin (DSC).
 *   The DSC is designed to maintain a stable value relative to the US Dollar
 *   through algorithmic mechanisms and collateralization with assets like ETH and BTC.
 *
 * This contract is meant to be governed by DCSEngine. This contract is just the ERC20
 *     implementation of our stablecoin system.
 */
import {ERC20Burnable, ERC20} from "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

contract DecentralizedStableCoin is ERC20Burnable, Ownable {
    error DecentralizedStableCoin__MustBeMoreThanZero();
    error DecentralizedStableCoin__BurnAmountExceedsBalance();
    error DecentralizedStableCoin__NotZeroAddress();

    constructor(address initialOwner) ERC20("DecentralizedStableCoin", "DSC") Ownable(initialOwner) {}

    function burn(uint256 _amount) public override onlyOwner {
        uint256 balance = balanceOf(msg.sender);
        if (_amount <= 0) {
            revert DecentralizedStableCoin__MustBeMoreThanZero();
        }
        if (balance < _amount) {
            revert DecentralizedStableCoin__BurnAmountExceedsBalance();
        }
        super.burn(_amount);
    }

    function mint(address _to, uint256 _amount) external onlyOwner returns (bool) {
        if (_to == address(0)) {
            revert DecentralizedStableCoin__NotZeroAddress();
        }
        if (_amount <= 0) {
            revert DecentralizedStableCoin__MustBeMoreThanZero();
        }
        _mint(_to, _amount);
        return true;
    }
}
