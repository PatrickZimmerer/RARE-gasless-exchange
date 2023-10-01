//SPDX-License-Identifier: MIT
pragma solidity =0.8.19;

import {IERC20} from "openzeppelin/token/ERC20/IERC20.sol";
import {IERC20Permit} from "openzeppelin/token/ERC20/extensions/IERC20Permit.sol";

import {MinimalForwarder} from "openzeppelin/metatx/MinimalForwarder.sol";
import {ERC20Permit} from "openzeppelin/token/ERC20/extensions/draft-ERC20Permit.sol";
import {ERC2771Context} from "openzeppelin/metatx/ERC2771Context.sol";
import {ReentrancyGuard} from "openzeppelin/security/ReentrancyGuard.sol";

contract MyMinimalForwarder is MinimalForwarder {}

contract GaslessExchange is ERC2771Context, ReentrancyGuard {
    ERC20Permit public immutable tokenA;
    ERC20Permit public immutable tokenB;

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

    function mactchOrders(
        Order[] calldata orders
    ) external nonReentrant returns (bool success) {
        uint256 currentTokenAAmount;
        uint256 currentTokenBAmount;

        uint256 length = orders.length;

        for (uint256 i = 0; i < length; i++) {
            Order calldata order = orders[i];

            require(
                order.from == address(tokenA) || order.from == address(tokenB),
                "from token is either tokenA or tokenB"
            );
            require(
                order.to == address(tokenB) || order.to == address(tokenA),
                "to token is either tokenA or tokenB"
            );

            require(
                order.spender == address(this),
                "must permit the token first"
            );
            require(
                order.fromAmount == order.value,
                "amount to sell must be equal to permited value"
            );

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
        }

        for (uint256 j = 0; j < length; j++) {
            Order calldata order = orders[j];

            if (order.to == address(tokenA)) {
                currentTokenAAmount -= order.toAmount;
                tokenA.transfer(order.owner, order.toAmount);
            } else {
                currentTokenBAmount -= order.toAmount;
                tokenB.transfer(order.owner, order.toAmount);
            }
        }

        require(
            currentTokenAAmount == 0 && currentTokenBAmount == 0,
            "each order did not match"
        );
        success = true;
    }
}
