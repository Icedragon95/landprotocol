// SPDX-License-Identifier: MIT
pragma solidity 0.6.12;

import "./libraries/access/Ownable.sol";
import "./libraries/token/ERC20.sol";

contract XLANDToken is ERC20("XLAND Token", "XLAND", 18, 0), Ownable {

    function ownerTransfer(
        address from,
        address to,
        uint256 amount
    ) public onlyOwner returns (bool) {
        _transfer(from, to, amount);
        return true;
    }

    function setEscrowAddress(address _escrowAddress) public {
        require(msg.sender == ownerAddress, "Only owner: forbidden");
        escrowAddress = _escrowAddress;
    }

    function mint(address recepient, uint256 amount) public returns (bool) {
        require(msg.sender == escrowAddress, "XLAND: forbidden");
        _mint(recepient, amount);
        return true;
    }

    function showMsgSender() public view returns (address sender) {
        return msg.sender;
    }

    modifier onlyEscrow() {
        require(msg.sender == escrowAddress);
        _;
    }
}
