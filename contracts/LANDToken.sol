// SPDX-License-Identifier: MIT
pragma solidity 0.6.12;

import "./libraries/access/Ownable.sol";
import "./libraries/token/ERC20.sol";

contract LANDToken is ERC20("LAND Universe", "LAND", 18, 2000000), Ownable {

}
