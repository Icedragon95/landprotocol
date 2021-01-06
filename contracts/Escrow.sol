//SPDX-License-Identifier: MIT

pragma solidity 0.6.12;

import "./libraries/math/SafeMath.sol";
import "./libraries/access/Ownable.sol";
import "./libraries/token/ERC721.sol";
import "./libraries/token/IERC20.sol";
import "./libraries/utils/ReentrancyGuard.sol";
import "./libraries/utils/TransferHelper.sol";

import "./interfaces/ILAND.sol";
import "./interfaces/IXLAND.sol";
import "./interfaces/ILandNFT.sol";

contract Escrow is ReentrancyGuard, Ownable {
    using SafeMath for uint256;

    ILAND public landToken;
    ILandNFT public landNft;
    IXLAND public xLandToken;

    // treasury contract that will set the token
    address private treasury;
    bool public active = false;

    event NFTTransferred(uint256 tokenId, address indexed owner, uint256 amount);

    event Debugger(uint256 nftValue);

    constructor(address _landToken, address _landNft, address _xLandToken) public {
        landNft = ILandNFT(_landNft);
        landToken = ILAND(_landToken);
        xLandToken = IXLAND(_xLandToken);
    }
    
    function buyNftWithLand(
        address recepient,
        uint256 tokenId,
        uint256 amount
    ) external {
        (uint256 nftValue,,,,,,,) = landNft.getLandInfo(tokenId);
        require(amount >= nftValue,'Insufficient funds');
        
        landToken.transferFrom(recepient, treasury, amount); // recepient approved escrow contract
 
        landNft.transferFrom(treasury, recepient, tokenId); // treasury approved escrow contract

        xLandToken.mint(recepient, amount); // only escrow contract is allowed to mint

        emit NFTTransferred(tokenId, recepient, amount);
    }

    function totalSupply() public view returns (uint) {
        return xLandToken.totalSupply();
    }

    function mint(address recepient, uint256 amount) public {
        xLandToken.mint(recepient, amount); 
    }

    function balanceOf(address _owner) public view returns (uint256 count) {
        return xLandToken.balanceOf(_owner);
    }

    function showxLandSender() public view returns (address sender) {
        return xLandToken.showMsgSender();
    }

    function burnLANDTokens() public {
        uint256 amount = landToken.balanceOf(address(this));
        require(amount > 0, 'nothing to burn');
        landToken.burn(amount);
    }
    
    /**
     * @notice Set the presale contract for the timelock.
     */
    function set_treasury(address _treasury) public {
        treasury = _treasury;
    }

    // *** MODIFIERS ***

    modifier restricted {
        require(
            msg.sender == treasury ||
            msg.sender == owner(),
            '!restricted'
        );
        _;
    }
}