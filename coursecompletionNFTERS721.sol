//SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin/contracts@4.9.6/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts@4.9.6/token/ERC721/extensions/ERC721URIStorage.sol";
import "@openzeppelin/contracts@4.9.6/token/ERC721/extensions/ERC721Enumerable.sol";
import "@openzeppelin/contracts@4.9.6/access/Ownable.sol";

contract NFT is ERC721, ERC721Enumerable, ERC721URIStorage, Ownable{
    uint256 private _tokenIdCounter;

    mapping(uint256 => CourseInfo) private _courseInfo;
    mapping(address => mapping(string => uint256)) private _studentCourseToken;
    mapping(string => uint256[]) private _courseTokens;

    struct CourseInfo {
        string courseId;
        string courseName;
        address student;
        uint256 completionDate;
        uint8 grade;
        bool isRevoked;
    }

    event CertificateMinted(
        uint256 indexed tokenId,
        address indexed student,
        string  courseId,
        string  courseName,
        uint256 completionDate,
        uint8   grade
    );
    event CertificateRevoked(uint256 indexed tokenId, address indexed student, string courseId);
    event MetadataUpdated(uint256 indexed tokenId, string newTokenURI);

    constructor(address initialOwner)
        ERC721("CourseCompletionCertificate", "CCC")
    {}

    function mintCertificate(
        address student,
        string  calldata courseId,
        string  calldata courseName,
        uint8   grade,
        string  calldata tokenURI_
    ) external onlyOwner returns (uint256 tokenId) {
        require(student != address(0),"Invalid student address");
        require(bytes(courseId).length > 0,"Course ID required");
        require(bytes(courseName).length > 0,"Course name required");
        require(grade <= 100,"Grade must be 0-100");
        require(_studentCourseToken[student][courseId] == 0,"Certificate already issued");

        _tokenIdCounter++;
        tokenId=_tokenIdCounter;

        _safeMint(student, tokenId);
        _setTokenURI(tokenId, tokenURI_);

        _courseInfo[tokenId] = CourseInfo({
            courseId:       courseId,
            courseName:     courseName,
            student:        student,
            completionDate: block.timestamp,
            grade:          grade,
            isRevoked:      false
        });

        _studentCourseToken[student][courseId] = tokenId;
        _courseTokens[courseId].push(tokenId);

        emit CertificateMinted(tokenId, student, courseId, courseName, block.timestamp, grade);
    }

    /// @notice Revokes a certificate by setting the isRevoked flag to true.
    /// @param tokenId The ID of the token to revoke.
    function revokeCertificate(uint256 tokenId) external onlyOwner {
        require(ownerOf(tokenId) != address(0),"Token does not exist");
        require(!_courseInfo[tokenId].isRevoked,"Already revoked");
        _courseInfo[tokenId].isRevoked = true;
        emit CertificateRevoked(tokenId, _courseInfo[tokenId].student, _courseInfo[tokenId].courseId);
    }

    function UpdateTokenURI(uint256 tokenId,string calldata newURI)
    external
    onlyOwner{
        require(_ownerOf(tokenId) != address(0),"Token does not exist");
        _setTokenURI(tokenId, newURI);
        emit MetadataUpdated(tokenId, newURI);
    }

    function getCertificateInfo(uint256 tokenId) 
    external
    view returns(CourseInfo memory){
        require(_ownerOf(tokenId) != address(0),"Token does not exist");
        return _courseInfo[tokenId];
    }

    function hasCertificate(address student,string calldata courseId) external view returns(bool){
        require(student != address(0),"Student address cannot be zero");
        if(_studentCourseToken[student][courseId]==0){
            return false;
        }
        uint256 tokenId=_studentCourseToken[student][courseId];
        return !_courseInfo[tokenId].isRevoked;
    }

    function getStudentCourseToken(address student, string calldata courseId) external view returns (uint256) {
        return _studentCourseToken[student][courseId];
    }

    function getCourseTokens(string calldata courseId) external view returns (uint256[] memory) {
        return _courseTokens[courseId];
    }

    function totalMinted() external view returns (uint256) {
        return _tokenIdCounter;
    }

    //soulbound
function _beforeTokenTransfer(address from, address to, uint256 tokenId, uint256 batchSize)
    internal override(ERC721, ERC721Enumerable) {
    require(from == address(0), "Soulbound: non-transferable");
    super._beforeTokenTransfer(from, to, tokenId, batchSize);
}

function _burn(uint256 tokenId)
    internal override(ERC721, ERC721URIStorage) {
    super._burn(tokenId);
}

function tokenURI(uint256 tokenId)
    public view override(ERC721, ERC721URIStorage)
    returns (string memory)
{
    return super.tokenURI(tokenId);
}

function supportsInterface(bytes4 interfaceId)
    public view override(ERC721, ERC721Enumerable, ERC721URIStorage)
    returns (bool)
{
    return super.supportsInterface(interfaceId);
}
}

