// SPDX-License-Identifier :MIT

pragma solidity^0.8.19;

import "@openzeppelin/contracts@4.9.6/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts@4.9.6/token/ERC721/extensions/ERC721URIStorage.sol";
import "@openzeppelin/contracts@4.9.6/token/ERC721/extensions/ERC721Royalty.sol";
import "@openzeppelin/contracts@4.9.6/access/Ownable.sol";
import "@openzeppelin/contracts@4.9.6/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts@4.9.6/utils/cryptography/MerkleProof.sol";

contract Minting is ERC721URIStorage,ERC721Royalty,Ownable,ReentrancyGuard {
    uint256 public maxSupply = 10_000;
    uint256 public maxPerWallet = 5;
    uint256 public publicMintPrice = 0.05 ether;
    uint256 public whitelistPrice = 0.03 ether;
    uint256 public totalMinted;
    bool public revealed = false;
    bool public publicSaleActive = false;
    bool public whitelistActive = false;

    string private baseTokenURI;
    string public  unrevealedURI;
    bytes32 public merkleRoot;

    mapping(address => uint256) public mintedPerWallet;
    mapping(address => bool)    public whitelistClaimed;

    event Minted(address indexed to, uint256 indexed tokenId);
    event Revealed(string baseURI);
    event PhaseChanged(bool whitelist, bool publicSale);
    event Withdrawn(address indexed to, uint256 amount);

    constructor(
        string memory _name,
        string memory _symbol,
        string memory _unrevealedURI,
        bytes32 _merkleRoot,
        address _royaltyReciever,
        uint96 _royaltyFeeNumerator //ex: 500 = 5%
        )ERC721(_name,_symbol){
        unrevealedURI=_unrevealedURI;
        merkleRoot=_merkleRoot;
        _setDefaultRoyalty(_royaltyReciever,_royaltyFeeNumerator);
    }

    modifier withinSupply(uint256 qty) {
        require(totalMinted + qty <= maxSupply, "Exceeds max supply");
        _;
    }

    modifier withinWalletLimit(uint256 qty) {
        require(
            mintedPerWallet[msg.sender] + qty <= maxPerWallet,
            "Exceeds per-wallet limit"
        );
        _;
    }

    function mint(uint256 qty)
        external
        payable 
        nonReentrant
        withinSupply(qty)
        withinWalletLimit(qty){
            require(publicSaleActive,"Sale is not active");
            require(msg.value >= publicMintPrice*qty,"Insufficient ETH");
            _miniBatch(msg.sender,qty);
    }

    function whitelistMint(uint256 qty,bytes32[] calldata proof)
    external payable
    nonReentrant
    withinWalletLimit(qty)
    withinSupply(qty){
        require(publicSaleActive,"Public Sale is not active");
        require(whitelistActive,"Whitelist is not active");
        require(msg.value >= publicMintPrice*qty, "Insufficient ETH");
        require(_verifyProof(proof,msg.sender),"Invalid merkle proof");
        whitelistClaimed[msg.sender]=true;
        _miniBatch(msg.sender,qty);
    }
    function ownerMint(address to, uint256 qty)
        external
        onlyOwner
        withinSupply(qty)
    {
        _miniBatch(to, qty);
    }

    //INTERNAL
    function _miniBatch(address to, uint256 qty) internal {
        for(uint256 i=0;i<qty;i++){
            uint256 tokenId=++totalMinted;
            _safeMint(to,qty);
            emit Minted(to,tokenId);
        }
        mintedPerWallet[to]=++qty;
    }

    function _verifyProof(bytes32[] calldata proof,address addr)
    internal view returns(bool){
        bytes32 leaf = keccak256(abi.encodePacked(addr));
        return MerkleProof.verify(proof, merkleRoot, leaf);
    }

    function tokenURI(uint256 tokenId)
        public view override(ERC721, ERC721URIStorage)
        returns (string memory)
    {
        if (!revealed) return unrevealedURI;
        return super.tokenURI(tokenId);
    }

    function _baseURI() internal view override returns (string memory){
        return baseTokenURI;
    }

    function reveal(string calldata _baseURI) external onlyOwner{
        baseTokenURI = _baseURI;
        revealed     = true;
        emit Revealed(_baseURI);
    }

    function setPhase(bool _whitelist, bool _public) external onlyOwner {
        whitelistActive  = _whitelist;
        publicSaleActive = _public;
        emit PhaseChanged(_whitelist, _public);
    }

    function setMerkleRoot(bytes32 _root) external onlyOwner {
        merkleRoot = _root;
    }

    function setPrices(uint256 _public, uint256 _wl) external onlyOwner {
        publicMintPrice = _public;
        whitelistPrice  = _wl;
    }

    function setMaxPerWallet(uint256 _max) external onlyOwner {
        maxPerWallet = _max;
    }

    function setRoyalty(address receiver, uint96 feeNumerator)
        external onlyOwner
    {
        _setDefaultRoyalty(receiver, feeNumerator);
    }

    function withdraw() external onlyOwner nonReentrant {
        uint256 bal = address(this).balance;
        require(bal > 0, "Nothing to withdraw");
        (bool ok,) = payable(owner()).call{value: bal}("");
        require(ok, "Transfer failed");
        emit Withdrawn(owner(), bal);
    }
    
    function supportsInterface(bytes4 interfaceId)
        public view override(ERC721URIStorage, ERC721Royalty)
        returns (bool)
    {
        return super.supportsInterface(interfaceId);
    }

     function _burn(uint256 tokenId)
        internal
        override(ERC721URIStorage, ERC721Royalty)
    {
        super._burn(tokenId);
    }

}
