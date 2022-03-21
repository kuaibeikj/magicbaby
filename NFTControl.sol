// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;
pragma experimental ABIEncoderV2;

import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "hardhat/console.sol";
import "./interface/IBaseNFT.sol";
import "./interface/IBaseNFT0.sol";

/*
* Store additional NFT information, circulation, etc.
*/
// name=NFTControl.sol npm run build
contract NFTControl is AccessControl {
    bytes32 public constant GLOBAL_ROLE = "GLOBAL_ROLE";

    // nft info
    mapping(address => NFTInfo) public attrKey;
    // Created contract address[]
    address[] public createdContractArr;
    // NFT Contract owner
    // NFT token address => NFT creator
    mapping(address => address) public NFTCreatorAddress;
    // User created NFT array
    // NFT creator => NFT token address[]
    mapping(address => address[]) public NFTCreatedArr;
    // NFT issue number
    mapping(address => uint) public issueNumber;

    string public tokenHost;

    address public baseNFTAddress;


    struct NFTInfo {
        string tokenName;
        // token picture
        string tokenImg;
        uint tag;
        string website;
        string introduce;
        string attrDescrip;
    }

    modifier auth(bytes32 iRole) {
        require(hasRole(iRole, msg.sender), "Permission denied");
        _;
    }

    constructor() {
        _setupRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _setupRole(GLOBAL_ROLE, msg.sender);
    }

    function addAuth(address account) public {
        grantRole(GLOBAL_ROLE, account);
    }

    function rmAuth(address account) public auth(GLOBAL_ROLE) {
        this.revokeRole(GLOBAL_ROLE, account);
    }

    function setTokenHost(string calldata tokenHost_) public auth(GLOBAL_ROLE) {
        tokenHost = tokenHost_;
    }

    function setBaseNFTAddress(address address_) public auth(GLOBAL_ROLE) {
        baseNFTAddress = address_;
    }

    function getCreatedContractArrLength() public view returns (uint){
        return createdContractArr.length;
    }

    function getNFTCreatedArrLength(address createdAddress) public view returns (uint){
        return NFTCreatedArr[createdAddress].length;
    }

    /*
    * param0 string[name_, symbol_, tokenImg_, website_, introduce_, attrDescrip_]
    * param1 uint[tag1_, issueNumber_]
    */
    function createNFTContract(string[] memory param0, uint[] memory param1, address graphSqlAddress_) public auth(GLOBAL_ROLE) returns (address){
        address createdNFTAddress = IBaseNFT(baseNFTAddress).factoryCreatedNFTContract(param0[0], param0[1], '', graphSqlAddress_);
        IBaseNFT0 NFTObj0 = IBaseNFT0(createdNFTAddress);
        string memory tokenUri = string(abi.encodePacked(tokenHost, addressToString(address(NFTObj0))));
        NFTObj0.setBaseURI(tokenUri);

        NFTInfo memory iNFTInfo;
        iNFTInfo.tokenName = param0[0];
        iNFTInfo.tokenImg = param0[2];
        iNFTInfo.tag = param1[0];
        iNFTInfo.website = param0[3];
        iNFTInfo.introduce = param0[4];
        iNFTInfo.attrDescrip = param0[5];
        attrKey[address(NFTObj0)] = iNFTInfo;

        issueNumber[address(NFTObj0)] = param1[1];
        NFTCreatorAddress[address(NFTObj0)] = tx.origin;
        createdContractArr.push(address(NFTObj0));
        NFTCreatedArr[tx.origin].push(address(NFTObj0));
        return createdNFTAddress;
    }

    function addressToString(address _addr) public pure returns (string memory) {
        bytes32 value = bytes32(uint256(uint160(address(_addr))));

        bytes memory alphabet = "0123456789abcdef";

        bytes memory str = new bytes(51);
        str[0] = "0";
        str[1] = "x";
        for (uint i = 0; i < 20; i++) {
            str[2 + i * 2] = alphabet[uint(uint8(value[i + 12] >> 4))];
            str[3 + i * 2] = alphabet[uint(uint8(value[i + 12] & 0x0f))];
        }
        return string(str);
    }

    function NFTMint(address NFTAddress, address _to, uint _val) public auth(GLOBAL_ROLE) {
        IBaseNFT0 NFTObj0 = IBaseNFT0(NFTAddress);
        NFTObj0.mintBase(_to, _val);
    }

    function getNFTContractInfo(address addr_) public view returns (NFTInfo memory iNFTInfo){
        iNFTInfo = attrKey[addr_];
        return iNFTInfo;
    }

    function addRole(address account) public auth(GLOBAL_ROLE){
        grantRole(GLOBAL_ROLE, account);
    }

    function rmRole(address account) public auth(GLOBAL_ROLE){
        this.revokeRole(GLOBAL_ROLE, account);
    }


}
