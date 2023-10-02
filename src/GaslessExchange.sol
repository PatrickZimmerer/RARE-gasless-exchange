//SPDX-License-Identifier: MIT
pragma solidity =0.8.19;

import {IERC20} from "openzeppelin/token/ERC20/IERC20.sol";
import {IERC20Permit} from "openzeppelin/token/ERC20/extensions/IERC20Permit.sol";
import {ERC20Permit} from "openzeppelin/token/ERC20/extensions/draft-ERC20Permit.sol";
import {ERC2771Context} from "openzeppelin/metatx/ERC2771Context.sol";
import {ReentrancyGuard} from "openzeppelin/security/ReentrancyGuard.sol";

contract GaslessExchange is ERC2771Context, ReentrancyGuard {
    ERC20Permit public immutable tokenA;
    ERC20Permit public immutable tokenB;

    error GaslessExchange__WrongFromTokenAddress();
    error GaslessExchange__WrongToTokenAddress();
    error GaslessExchange__NotPermitted();
    error GaslessExchange__NotSameAmount();
    error GaslessExchange__MissmatchInOrder();

    struct Order {
        address from;
        uint256 fromAmount;
        address to;
        uint256 toAmount;
        address owner;
        address spender;
        uint256 value;
        uint256 deadline;
        uint8 v;
        bytes32 r;
        bytes32 s;
        uint256 nonce;
    }

    constructor(
        IERC20Permit _tokenA,
        IERC20Permit _tokenB,
        address trustedForwarder_
    ) ERC2771Context(trustedForwarder_) {
        tokenA = ERC20Permit(address(_tokenA));
        tokenB = ERC20Permit(address(_tokenB));
    }

    function matchOrders(
        Order[] calldata orders
    ) external nonReentrant returns (bool success) {
        uint256 currentTokenAAmount;
        uint256 currentTokenBAmount;

        uint256 length = orders.length;

        // loop through each order and transfer tokens to gasless exchange
        for (uint256 i = 0; i < length; ) {
            Order calldata order = orders[i];

            if (
                (order.from != address(tokenA) && order.from != address(tokenB))
            ) {
                revert GaslessExchange__WrongFromTokenAddress();
            }

            if ((order.to != address(tokenB) && order.to != address(tokenA))) {
                revert GaslessExchange__WrongToTokenAddress();
            }

            if (order.spender != address(this)) {
                revert GaslessExchange__NotPermitted();
            }

            if (order.fromAmount != order.value) {
                revert GaslessExchange__NotSameAmount();
            }

            if (order.from == address(tokenA)) {
                currentTokenAAmount += order.fromAmount;

                tokenA.permit(
                    order.owner,
                    order.spender,
                    order.value,
                    order.deadline,
                    order.v,
                    order.r,
                    order.s
                );

                tokenA.transferFrom(
                    order.owner,
                    address(this),
                    order.fromAmount
                );
            } else {
                currentTokenBAmount += order.fromAmount;

                tokenB.permit(
                    order.owner,
                    order.spender,
                    order.value,
                    order.deadline,
                    order.v,
                    order.r,
                    order.s
                );

                tokenB.transferFrom(
                    order.owner,
                    address(this),
                    order.fromAmount
                );
            }
            unchecked {
                ++i;
            }
        }

        // loop again and and transfer tokens to new owners
        for (uint256 i = 0; i < length; ) {
            Order calldata order = orders[i];

            if (order.to == address(tokenA)) {
                currentTokenAAmount -= order.toAmount;
                tokenA.transfer(order.owner, order.toAmount);
            } else {
                currentTokenBAmount -= order.toAmount;
                tokenB.transfer(order.owner, order.toAmount);
            }
            unchecked {
                ++i;
            }
        }

        if (currentTokenAAmount != 0 || currentTokenBAmount != 0) {
            revert GaslessExchange__MissmatchInOrder();
        }

        success = true;
    }
}
