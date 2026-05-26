//SPDX-License-Identifier :MIT

pragma solidity ^0.8.19;

import "@openzeppelin/contracts@4.9.6/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts@4.9.6/token/ERC721/extensions/ERC721URIStorage.sol";
import "@openzeppelin/contracts@4.9.6/token/ERC721/extensions/ERC721Enumerable.sol";
import "@openzeppelin/contracts@4.9.6/access/Ownable.sol";

contract AchievementBadge is ERC721,ERC721URIStorage,ERC721Enumerable,Ownable{

    uint256 private _tokenIdCounter;

    struct BadgeType{
        string name;
        string metadataURI;
        bool exists;
    }

    mapping(uint256 => BadgeType) public badgeTypes;
    uint256 public badgeTypeCount;
    mapping(uint256 => uint256) public tokenBadgeType;
    mapping(address => mapping(uint256 => bool)) public hasBadge;

    event BadgeTypeCreated(uint256 indexed badgeTypeId,string name,string metadataURI);
    event BadgeAwarded(address indexed recipient,uint256 indexed tokenId,uint256 indexed badgeTypeId);
    event BadgeRevoked(address indexed from,uint256 indexed tokenId);

    constructor () ERC721("AchievementBadge", "BADGE"){}

    function createBadgeType(string memory name,string memory metadataURI) external onlyOwner returns (uint256 badgeTypeId) {
        
        require(bytes(name).length>0,"AchievementBadge: Name required");
        require(bytes(metadataURI).length>0,"AchievementBadge: URI required");
        badgeTypeId = badgeTypeCount;
        badgeTypeCount++;
        badgeTypes[badgeTypeId]=BadgeType(name,metadataURI,true);
        emit BadgeTypeCreated(badgeTypeId,name,metadataURI);
        return badgeTypeId;
    }

    function awardBadge(uint256 badgeTypeId, address recipient) external onlyOwner{
        require(recipient!=address(0),"Zero Address");
        require(!hasBadge[recipient][badgeTypeId],"already awarded");
        require(badgeTypes[badgeTypeId].exists,"invalid badge type");
        uint256 tokenId=_tokenIdCounter;
        _tokenIdCounter++;
        _safeMint(recipient, tokenId);
        _setTokenURI(tokenId, badgeTypes[badgeTypeId].metadataURI);
        tokenBadgeType[tokenId]=badgeTypeId;
        hasBadge[recipient][badgeTypeId]=true;
        emit BadgeAwarded(recipient, tokenId, badgeTypeId);
    }

     function batchAwardBadge(address[] calldata recipients, uint256 badgeTypeId)
        external
        onlyOwner
    {
        require(badgeTypes[badgeTypeId].exists, "AchievementBadge: invalid badge type");

        for (uint256 i = 0; i < recipients.length; i++) {
            address recipient = recipients[i];
            if (recipient != address(0) && !hasBadge[recipient][badgeTypeId]) {
                uint256 tokenId=_tokenIdCounter;
                _tokenIdCounter++;
                _safeMint(recipient, tokenId);
                _setTokenURI(tokenId, badgeTypes[badgeTypeId].metadataURI);

                tokenBadgeType[tokenId] = badgeTypeId;
                hasBadge[recipient][badgeTypeId] = true;

                emit BadgeAwarded(recipient, tokenId, badgeTypeId);
            }
        }
    }

    function revokeBadge(uint256 tokenId) external onlyOwner{
        require(tokenId<_tokenIdCounter,"Non existent Token ID");
        address badgeOwner=ownerOf(tokenId);
        uint256 badgeTypeId=tokenBadgeType[tokenId];
        hasBadge[badgeOwner][badgeTypeId]=false;
        delete tokenBadgeType[tokenId];
        _burn(tokenId);
        emit BadgeRevoked(badgeOwner,tokenId);
    }

    function updateBadgeTypeURI(uint256 badgeTypeId, string calldata newURI) external onlyOwner{
        require(badgeTypes[badgeTypeId].exists, "AchievementBadge: invalid badge type");
        require(bytes(newURI).length > 0, "AchievementBadge: URI required");
        badgeTypes[badgeTypeId].metadataURI=newURI;
    }

    function tokensOfOwner(address owneraddr) external view returns (uint256[] memory) {
        uint256 balance = balanceOf(owneraddr);
        uint256[] memory tokens = new uint256[](balance);
        for (uint256 i = 0; i < balance; i++) {
            tokens[i] = tokenOfOwnerByIndex(owneraddr, i);
        }
        return tokens;
    }
    function badgeTypeOfToken(uint256 tokenId)
        external
        view
        returns (string memory name, string memory metadataURI)
    {
        uint256 badgeTypeId = tokenBadgeType[tokenId];
        BadgeType memory bt = badgeTypes[badgeTypeId];
        return (bt.name, bt.metadataURI);
    }

     function _beforeTokenTransfer(
        address from,
        address to,
        uint256 tokenId,
        uint256 batchSize
    ) internal override(ERC721, ERC721Enumerable) {
        super._beforeTokenTransfer(from, to, tokenId, batchSize);
    }

    function _burn(uint256 tokenId)
        internal
        override(ERC721, ERC721URIStorage)
    {
        super._burn(tokenId);
    }

    function tokenURI(uint256 tokenId)
        public
        view
        override(ERC721, ERC721URIStorage)
        returns (string memory)
    {
        return super.tokenURI(tokenId);
    }

    function supportsInterface(bytes4 interfaceId)
        public
        view
        override(ERC721, ERC721Enumerable, ERC721URIStorage)
        returns (bool)
    {
        return super.supportsInterface(interfaceId);
    }
}

