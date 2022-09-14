// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/common/ERC2981.sol";

contract TaffyNFT is ERC721, ERC2981, Ownable {
    // This is the REAL NFT Base Contract
    string public baseUri = "https://taffy.com";
    bool internal hasBaseUriChanged = false;
    string public contractURI;

    /**
     *  @param royaltyFeeInBips should be 100X the percent you wish to receive
        For example, a 3% royalty will require a royaltyFeeInBips value of 300.
     */
    constructor(string memory name, string memory ticker, uint96 royaltyFeeInBips, string memory _contractURI) ERC721(name, ticker) {
        setRoyaltyInfo(msg.sender, royaltyFeeInBips);
        contractURI = _contractURI;
    }

    function _baseURI() internal view override returns (string memory) {
        return baseUri;
    }

    /**
     *  @dev ATTENTION: THIS CAN ONLY BE CHANGED ONCE!
        MAKE SURE THE URI DOES NOT CONTAIN A TRAILING SLASH,
        e.g. ipfs://cidstring   -> CORRECT
        NOT ipfs://cidstring/   -> INCORRECT
        THIS CAN NOT BE CHANGED AGAIN IF YOU MAKE A MISTAKE
     */
    function changeBaseUri(string memory _newBaseUri) external onlyOwner {
        require(hasBaseUriChanged == false, "You can not change the base URI more than once");
        hasBaseUriChanged = true;
        baseUri = _newBaseUri;
    }

    function getBaseUri() external view returns (string memory) {
        return baseUri;
    }

    function supportsInterface(bytes4 interfaceId) public view override(ERC721, ERC2981) returns (bool) {
        return interfaceId == type(IERC2981).interfaceId || super.supportsInterface(interfaceId);
    }

    function setRoyaltyInfo(address _receiver, uint96 _royaltyFeeInBips) public onlyOwner {
        _setDefaultRoyalty(_receiver, _royaltyFeeInBips);
    }

    function setContractURI(string calldata _contractURI) external onlyOwner {
        contractURI = _contractURI;
    }
}