// SPDX-License-Identifier: MIT

pragma solidity 0.6.12;

interface ILandNFT {

    function totalSupply() external view returns (uint256 total);

    /**
     * @dev Returns the amount of tokens owned by `_owner`.
     */
    function balanceOf(address _owner) external view returns (uint256 balance);
    function ownerOf(uint256 _tokenId) external view returns (address owner);
    function approve(address _to, uint256 _tokenId) external;
    function transfer(address _to, uint256 _tokenId) external;
    function transferFrom(address _from, address _to, uint256 _tokenId) external;
    function createLand(
        uint256 _size,
        uint256 _tileId,
        uint256 _value,
        address _owner,
        string calldata _url,
        string calldata _element,
        string calldata _name
    ) external;
    
    function getLand(uint256 _id) external view returns (
        uint256 creationTime,
        uint256 tileId,
        uint256 value
    );
}