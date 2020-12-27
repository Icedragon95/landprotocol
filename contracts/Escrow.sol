//SPDX-License-Identifier: MIT

pragma solidity 0.6.12;

import "./libraries/math/SafeMath.sol";
import "./libraries/token/IERC20.sol";
import "./libraries/utils/ReentrancyGuard.sol";


import "./interfaces/ILAND.sol";
import "./interfaces/IXLAND.sol";
import "./interfaces/ILandNFT.sol";

contract Escrow {
    using SafeMath for uint256;

    address public immutable landToken;
    address public immutable nftContract;
    address public immutable xLandToken;

    // manually track totalCapital to guard against reentrancy attacks
    uint256 public totalCapital;

    event NFTTransferred(uint256 tokenId, address indexed owner, uint256 amount);

    constructor(address _land, address _nftContract, address _xlandToken) public {
        landToken = _land;
        nftContract = _nftContract;
        xLandToken = _xlandToken;
    }

    function purchaseLandNFT(uint256 tokenId, uint256 amount) public {
     //   require(ownerOf(tokenId) == address(this), "Purchase token from owner");

   //     Neverland land = getNFTTokenInfo(tokenId);
      //  ILandNFT(nftContract).getNeverland(tokenId);
        require(amount > 0,'Insufficient funds');

        //ILAND(landToken).approve(address(this), amount);
        address account = msg.sender;
        IERC20(landToken).transferFrom(account, address(this), amount);

        ILandNFT(nftContract).transfer(msg.sender, tokenId);

        
        emit NFTTransferred(tokenId, msg.sender, amount);
    }

    function burnLANDTokens() public {
        uint256 amount = ILAND(landToken).balanceOf(address(this));
        require(amount > 0, 'nothing to burn');
        ILAND(landToken).burn(amount);
    }

    function mintXLandTokens(address recepient, uint256 _amount) public {
      IXLAND(xLandToken).mint(recepient, _amount);
    }
}