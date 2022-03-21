// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;
pragma experimental ABIEncoderV2;

import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "hardhat/console.sol";
import "./interface/IBaseNFT.sol";
import "./interface/IBaseNFT0.sol";
import "./interface/IRandom.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "./interface/INFTControl.sol";

/*
* Store additional NFT information, circulation, etc.
*/
// name=BoxNFTControl.sol npm run build
contract BoxNFTControl is AccessControl {
    using SafeMath for uint256;
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
    address public randomAddress;
    address  public NFTControlAddress;

    struct NFTInfo {
        string tokenName;
        string tokenImg;
        uint price;
        uint startTime;
        uint endTime;
        string introduce;
        address[] NFTAddressArr;
        // How many NFTs are there in total
        uint[] NFTTotal;
        // How many NFTs have been opened from the blind box
        uint[] NFTOpened;
    }

    event eOpenBox(address contractAddress_, address toAddress_);

    modifier auth(bytes32 iRole) {
        require(hasRole(iRole, msg.sender), "Permission denied");
        _;
    }

    constructor() {
        _setupRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _setupRole(GLOBAL_ROLE, msg.sender);
    }

    function addAuth(address account) public{
        grantRole(GLOBAL_ROLE, account);
    }

    function rmAuth(address account) public auth(GLOBAL_ROLE){
        this.revokeRole(GLOBAL_ROLE, account);
    }

    function setTokenHost(string calldata tokenHost_) public auth(GLOBAL_ROLE){
        tokenHost = tokenHost_;
    }

    function setBaseNFTAddress(address address_) public auth(GLOBAL_ROLE){
        baseNFTAddress = address_;
    }

    function setNFTControlAddress(address address_) public auth(GLOBAL_ROLE) {
        NFTControlAddress = address_;
    }

    function setRandomAddress(address address_) public auth(GLOBAL_ROLE) {
        randomAddress = address_;
    }

    function getCreatedContractArrLength() public view returns(uint){
        return createdContractArr.length;
    }

    function getNFTCreatedArrLength(address createdAddress) public view returns(uint){
        return NFTCreatedArr[createdAddress].length;
    }

    /*
    * param0 string[name_, symbol_, tokenImg_, introduce_]
    * param1 uint[price_, startTime_, endTime, issueNumber_]
    * param2 address[NFTAddress1, NFTAddress2...]
    * param3 uint[uint, uint...]
    */
    function createNFTContract(string[] memory param0, uint[] memory param1, address[] memory param2, uint[] memory param3, address graphSqlAddress_) public auth(GLOBAL_ROLE) returns(address){
        address createdNFTAddress = IBaseNFT(baseNFTAddress).factoryCreatedNFTContract(param0[0], param0[1], '', graphSqlAddress_);
        IBaseNFT0 NFTObj0 = IBaseNFT0(createdNFTAddress);
        string memory tokenUri = string(abi.encodePacked(tokenHost, addressToString(createdNFTAddress)));
        NFTObj0.setBaseURI(tokenUri);
//        NFTObj0.grantRole(GLOBAL_ROLE, address(0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266));

        NFTInfo memory iNFTInfo;
        iNFTInfo.tokenName = param0[0];
        iNFTInfo.tokenImg = param0[2];
        iNFTInfo.price = param1[0];
        iNFTInfo.startTime = param1[1];
        iNFTInfo.endTime = param1[2];
        iNFTInfo.introduce = param0[3];
        iNFTInfo.NFTAddressArr = param2;
        iNFTInfo.NFTTotal = param3;
        iNFTInfo.NFTOpened = new uint[](param3.length);

        attrKey[createdNFTAddress] = iNFTInfo;

        issueNumber[createdNFTAddress] = param1[3];
        NFTCreatorAddress[createdNFTAddress] = tx.origin;
        createdContractArr.push(createdNFTAddress);
        NFTCreatedArr[tx.origin].push(createdNFTAddress);
        return createdNFTAddress;
    }

    function addressToString(address _addr) public pure returns(string memory) {
        bytes32 value = bytes32(uint256(uint160(address(_addr))));

        bytes memory alphabet = "0123456789abcdef";

        bytes memory str = new bytes(51);
        str[0] = "0";
        str[1] = "x";
        for (uint i = 0; i < 20; i++) {
            str[2+i*2] = alphabet[uint(uint8(value[i + 12] >> 4))];
            str[3+i*2] = alphabet[uint(uint8(value[i + 12] & 0x0f))];
        }
        return string(str);
    }

    function openBox(address NFTAddress, uint NFTId) payable public{
        IBaseNFT0 NFTObj0 = IBaseNFT0(NFTAddress);
        require(NFTObj0.ownerOf(NFTId) == msg.sender, 'not owner');
        NFTInfo memory iNFTInfo = attrKey[NFTAddress];
        uint iIssueNumber = issueNumber[NFTAddress];
        uint iOpened = 0;
        for (uint i = 0; i < iNFTInfo.NFTAddressArr.length; i++) {
            iOpened = iOpened.add(iNFTInfo.NFTOpened[i]);
        }
        require(iIssueNumber.sub(iOpened) > 0, 'The box is gone');
        uint randomRs = IRandom(randomAddress).getRandom(iIssueNumber - iOpened);
        uint iIndex = 0;
        for (uint i = 0; i < iNFTInfo.NFTAddressArr.length; i++) {
            iIndex = iIndex.add(iNFTInfo.NFTTotal[i].sub(iNFTInfo.NFTOpened[i]));
            if(randomRs < iIndex){
                NFTBurn(NFTAddress, NFTId);
                INFTControl(NFTControlAddress).NFTMint(iNFTInfo.NFTAddressArr[i], msg.sender, msg.value);
                attrKey[NFTAddress].NFTOpened[i]++;
                emit eOpenBox(iNFTInfo.NFTAddressArr[i], msg.sender);
                i = iNFTInfo.NFTAddressArr.length;
                return;
            }
        }
        // The blind box has been opened
        if(iIssueNumber.sub(iOpened) == 1){

        }
    }

    function NFTMint(address NFTAddress, address _to, uint _val) public auth(GLOBAL_ROLE){
        IBaseNFT0 NFTObj0 = IBaseNFT0(NFTAddress);
        NFTObj0.mintBase(_to, _val);
    }

    function NFTBurn(address NFTAddress, uint tokenId) private{
        IBaseNFT0 NFTObj0 = IBaseNFT0(NFTAddress);
        NFTObj0.burnBase(tokenId);
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
