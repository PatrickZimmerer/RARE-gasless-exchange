//SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Test, stdError} from "forge-std/Test.sol";

import {IERC20} from "openzeppelin/token/ERC20/IERC20.sol";
import {IERC20Permit} from "openzeppelin/token/ERC20/extensions/IERC20Permit.sol";
import {MinimalForwarder} from "openzeppelin/metatx/MinimalForwarder.sol";

import {MockERC20Permit} from "./mocks/MockERC20Permit.sol";
import {PermitSignature} from "./utils/PermitSignature.sol";

import {GaslessExchange} from "../src/GaslessExchange.sol";

// MinimalForwarder to pass into constructor for testing purposes
contract MyMinimalForwarder is MinimalForwarder {

}

contract GaslessExchangeTest is Test {
    string mnemonic =
        "test test test test test test test test test test test junk";

    uint256 deployerPrivateKey = vm.deriveKey(mnemonic, "m/44'/60'/0'/0/", 1);

    //  address = 0x70997970C51812dc3A010C7d01b50e0d17dc79C8
    address deployer = vm.addr(deployerPrivateKey);

    address trader1;
    address trader2;

    IERC20Permit tokenA;
    IERC20Permit tokenB;

    PermitSignature sigUtilsTokenA;
    PermitSignature sigUtilsTokenB;

    MyMinimalForwarder forwarder;
    GaslessExchange exchange;

    function setUp() public {
        vm.startPrank(deployer);
        vm.label(deployer, "Deployer");
        vm.deal(deployer, 1 ether);

        trader1 = vm.addr(11);
        trader2 = vm.addr(12);

        tokenA = IERC20Permit(address(new MockERC20Permit("TestTokenA", "A")));
        tokenB = IERC20Permit(address(new MockERC20Permit("TestTokenB", "B")));
        vm.label(address(tokenA), "TestTokenA");
        vm.label(address(tokenB), "TestTokenB");

        sigUtilsTokenA = new PermitSignature(tokenA.DOMAIN_SEPARATOR());
        sigUtilsTokenB = new PermitSignature(tokenB.DOMAIN_SEPARATOR());

        forwarder = new MyMinimalForwarder();
        exchange = new GaslessExchange(tokenA, tokenB, address(forwarder));
        vm.label(address(exchange), "GaslessExchange");

        deal({token: address(tokenA), to: deployer, give: 20 ether});

        vm.stopPrank();
    }

    modifier setupTokens() {
        deal({token: address(tokenA), to: trader1, give: 100 ether});
        deal({token: address(tokenA), to: trader2, give: 0 ether});

        deal({token: address(tokenB), to: trader1, give: 0 ether});
        deal({token: address(tokenB), to: trader2, give: 50 ether});

        assertEq(IERC20(address(tokenA)).balanceOf(trader1), 100 ether);
        assertEq(IERC20(address(tokenB)).balanceOf(trader2), 50 ether);
        _;
    }

    function test_matchOrders() external setupTokens {
        vm.startPrank(deployer);

        PermitSignature.Permit memory permitToken = PermitSignature.Permit({
            owner: trader1,
            spender: address(exchange),
            value: 100 ether,
            nonce: 0,
            deadline: 1 days
        });

        bytes32 digestTokenA = sigUtilsTokenA.getTypedDataHash(permitToken);

        (uint8 v, bytes32 r, bytes32 s) = vm.sign(11, digestTokenA);

        GaslessExchange.Order[] memory orders = new GaslessExchange.Order[](2);
        orders[0] = GaslessExchange.Order({
            from: address(tokenA),
            fromAmount: 100 ether,
            to: address(tokenB),
            toAmount: 50 ether,
            owner: trader1,
            spender: address(exchange),
            value: 100 ether,
            deadline: 1 days,
            v: v,
            r: r,
            s: s,
            nonce: 0
        });

        permitToken = PermitSignature.Permit({
            owner: trader2,
            spender: address(exchange),
            value: 50 ether,
            nonce: 0,
            deadline: 1 days
        });

        bytes32 digestTokenB = sigUtilsTokenB.getTypedDataHash(permitToken);
        (v, r, s) = vm.sign(12, digestTokenB);

        orders[1] = GaslessExchange.Order({
            from: address(tokenB),
            fromAmount: 50 ether,
            to: address(tokenA),
            toAmount: 100 ether,
            owner: trader2,
            spender: address(exchange),
            value: 50 ether,
            deadline: 1 days,
            v: v,
            r: r,
            s: s,
            nonce: 0
        });

        bool success = exchange.matchOrders(orders);
        require(success);

        assertEq(IERC20(address(tokenA)).balanceOf(trader2), 100 ether);
        assertEq(IERC20(address(tokenB)).balanceOf(trader1), 50 ether);
    }
}
