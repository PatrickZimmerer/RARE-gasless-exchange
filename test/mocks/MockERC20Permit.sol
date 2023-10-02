// SPDX-License-Identifier: MIT
pragma solidity =0.8.19;

import {ERC20} from "openzeppelin/token/ERC20/ERC20.sol";
import {ERC20Permit} from "openzeppelin/token/ERC20/extensions/draft-ERC20Permit.sol";

contract MockERC20Permit is ERC20, ERC20Permit {
    constructor(
        string memory _name,
        string memory _symbol
    ) ERC20(_name, _symbol) ERC20Permit(_name) {}

    function mint(address to, uint256 amount) public virtual {
        _mint(to, amount);
    }

    function burn(address from, uint256 value) public virtual {
        _burn(from, value);
    }
}
