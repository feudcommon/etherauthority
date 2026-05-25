// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Pausable.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Burnable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract InternshipCertificate is ERC721, ERC721URIStorage, ERC721Pausable, ERC721Burnable, Ownable {

    // ── State ──────────────────────────────────────────────────────────────
    uint256 private _nextTokenId;

    mapping(address => bool) public authorizedIssuers;
    mapping(uint256 => Certificate) public certificates;
    mapping(address => bool) public hasCertificate;

    struct Certificate {
        string  internName;
        string  role;
        string  company;
        uint256 startDate;
        uint256 endDate;
        address issuedBy;
        uint256 issuedAt;
    }

    // ── Events ─────────────────────────────────────────────────────────────
    event CertificateIssued(address indexed intern, uint256 indexed tokenId, string role, string company);
    event IssuerUpdated(address indexed issuer, bool authorized);

    // ── Errors ─────────────────────────────────────────────────────────────
    error NotAuthorizedIssuer();
    error ZeroAddress();
    error AlreadyHasCertificate(address intern);
    error InvalidDates();

    constructor(address initialOwner)
        ERC721("Internship Certificate", "ICERT")
        Ownable(initialOwner)
    {
        if (initialOwner == address(0)) revert ZeroAddress();
        authorizedIssuers[initialOwner] = true;
        emit IssuerUpdated(initialOwner, true);
    }

    // ── Issue Certificate ──────────────────────────────────────────────────

    /**
     * @notice Mint a certificate NFT to an intern.
     * @param  intern     Wallet address of the intern.
     * @param  internName Full name of the intern.
     * @param  role       Internship role/title.
     * @param  company    Company name.
     * @param  startDate  Unix timestamp of internship start.
     * @param  endDate    Unix timestamp of internship end.
     * @param  tokenURI_  IPFS URI pointing to the certificate metadata/image.
     */
    function issueCertificate(
        address intern,
        string calldata internName,
        string calldata role,
        string calldata company,
        uint256 startDate,
        uint256 endDate,
        string calldata tokenURI_
    ) external {
        if (!authorizedIssuers[msg.sender]) revert NotAuthorizedIssuer();
        if (intern == address(0)) revert ZeroAddress();
        if (hasCertificate[intern]) revert AlreadyHasCertificate(intern);
        if (endDate <= startDate) revert InvalidDates();

        uint256 tokenId = _nextTokenId;
        unchecked { _nextTokenId++; }

        certificates[tokenId] = Certificate({
            internName: internName,
            role:       role,
            company:    company,
            startDate:  startDate,
            endDate:    endDate,
            issuedBy:   msg.sender,
            issuedAt:   block.timestamp
        });

        hasCertificate[intern] = true;

        _safeMint(intern, tokenId);
        _setTokenURI(tokenId, tokenURI_);

        emit CertificateIssued(intern, tokenId, role, company);
    }

    // ── Admin ──────────────────────────────────────────────────────────────

    function setIssuer(address issuer, bool status) external onlyOwner {
        if (issuer == address(0)) revert ZeroAddress();
        authorizedIssuers[issuer] = status;
        emit IssuerUpdated(issuer, status);
    }

    function pause() external onlyOwner { _pause(); }
    function unpause() external onlyOwner { _unpause(); }

    // ── View ───────────────────────────────────────────────────────────────

    /// @notice Returns all certificate details for a given token ID.
    function getCertificate(uint256 tokenId) external view returns (Certificate memory) {
        return certificates[tokenId];
    }

    // ── Overrides ──────────────────────────────────────────────────────────

    function _update(address to, uint256 tokenId, address auth)
        internal override(ERC721, ERC721Pausable)
        returns (address)
    {
        return super._update(to, tokenId, auth);
    }

    function tokenURI(uint256 tokenId)
        public view override(ERC721, ERC721URIStorage)
        returns (string memory)
    {
        return super.tokenURI(tokenId);
    }

    function supportsInterface(bytes4 interfaceId)
        public view override(ERC721, ERC721URIStorage)
        returns (bool)
    {
        return super.supportsInterface(interfaceId);
    }
}