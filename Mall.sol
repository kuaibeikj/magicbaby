// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;
pragma experimental ABIEncoderV2;

import {TransferHelper} from "@uniswap/lib/contracts/libraries/TransferHelper.sol";
//import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "hardhat/console.sol";
import "./interface/IBoxControl.sol";
import "./interface/INFTControl.sol";
import "./interface/IGraphSql.sol";
import "./interface/IUser.sol";
import "./interface/IERC721Base.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";


/*
* Blind box and NFT mall
*/
// name=Mall.sol npm run build
contract Mall is AccessControl, IERC721Receiver {
    using SafeMath for uint256;
    bytes32 public constant GLOBAL_ROLE = "GLOBAL_ROLE";

    address  public boxControlAddress;
    address  public NFTControlAddress;
    address  public graphSqlAddress;
    address  public userContractAddress;
    address  public handlingFeeAddress;
    address  public feeErc20TokenAddress;
    // val / 10000
    uint[] fees;

    // control address => info
    mapping(address => boxNFTControlInfo) public boxNFTControlList;
    mapping(address => NFTControlInfo) public NFTControlList;
    // (NFT address + NFT Id) => info
    // address maybe box or NFT control
    mapping(string => ProductInfo) public NFTList;

    struct boxNFTControlInfo {
        // Already sold
        uint soldNumber;
        address seller;
        // 0 Not created 1 Created but not sold 2 On sale 3 sold out
        uint status;
    }

    struct NFTControlInfo {
        uint price;
        uint onSaleNumber;
        // Already sold
        uint soldNumber;
        address seller;
        // 0 Not created 1 Created but not sold 2 On sale 3 sold out
        uint status;
    }

    struct ProductInfo {
        uint price;
        address seller;
        address contractAddress;
        // 0 Not mint 1 mint but not sold 2 On sale
        uint status;
        uint NFTId;
    }

    modifier auth(bytes32 iRole) {
        require(hasRole(iRole, msg.sender), "Permission denied");
        _;
    }

    constructor() {
        _setupRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _setupRole(GLOBAL_ROLE, msg.sender);
    }


    function setBoxControlAddress(address address_) public auth(GLOBAL_ROLE) {
        boxControlAddress = address_;
    }

    function setNFTControlAddress(address address_) public auth(GLOBAL_ROLE) {
        NFTControlAddress = address_;
    }

    function setGraphSqlAddress(address address_) public auth(GLOBAL_ROLE) {
        graphSqlAddress = address_;
    }

    function setUserContractAddress(address address_) public auth(GLOBAL_ROLE) {
        userContractAddress = address_;
    }

    function setHandlingFeeAddress(address address_) public auth(GLOBAL_ROLE) {
        handlingFeeAddress = address_;
    }

    function setFeeErc20TokenAddress(address address_) public auth(GLOBAL_ROLE) {
        feeErc20TokenAddress = address_;
    }

    function setFees(uint[] memory arr) public auth(GLOBAL_ROLE) {
        fees = arr;
    }

    /*
    * param0 string[name_, symbol_, tokenImg_, introduce_]
    * param1 uint[price_, startTime_, endTime_, issueNumber_]
    * param2 address[NFTAddress1, NFTAddress2...]
    * param3 uint[uint, uint...]
    */
    function createBox(string[] memory param0, uint[] memory param1, address[] memory param2, uint[] memory param3) public auth(GLOBAL_ROLE) {
        uint boxLength = 0;
        for (uint i = 0; i < param2.length; i++) {
            NFTControlInfo memory iMallNFTInfo = NFTControlList[param2[i]];
            uint issueNumber = INFTControl(NFTControlAddress).issueNumber(param2[i]);
            require(issueNumber >= iMallNFTInfo.soldNumber.add(param3[i]).add(iMallNFTInfo.onSaleNumber), 'The NFT sold is out of stock');
            NFTControlList[param2[i]].soldNumber = iMallNFTInfo.soldNumber.add(param3[i]);
            boxLength += param3[i];
        }
        require(param1[3] == boxLength);
        address createdBoxAddress = IBoxControl(boxControlAddress).createNFTContract(param0, param1, param2, param3, graphSqlAddress);
        IGraphSql(graphSqlAddress).addRole(createdBoxAddress);
        boxNFTControlList[createdBoxAddress].seller = msg.sender;
        boxNFTControlList[createdBoxAddress].status = 1;
        IGraphSql(graphSqlAddress).touchBox(createdBoxAddress,  param0[0], param1[0], param1[1], param1[2], 1, param1[3], param0[2]);
    }

    /*
    * change box status
    */
    function SetBoxStatus(address BoxAddress, uint status_) public auth(GLOBAL_ROLE) {
//        require(boxNFTControlList[BoxAddress].status == 1, 'status err');
        boxNFTControlList[BoxAddress].status = status_;
        IBoxControl.NFTInfo memory iBoxInfo = IBoxControl(boxControlAddress).getNFTContractInfo(BoxAddress);
        IGraphSql(graphSqlAddress).touchBox(BoxAddress, iBoxInfo.tokenName, iBoxInfo.price, iBoxInfo.startTime, iBoxInfo.endTime, status_, IBoxControl(boxControlAddress).issueNumber(BoxAddress), iBoxInfo.tokenImg);
    }

    /*
    * same as NFTControl's method createNFTContract
    */
    function createNFTContract(string[] memory param0, uint[] memory param1) public{
        if(!hasRole(GLOBAL_ROLE, msg.sender)){
            IUser.UserInfo memory iUserInfo = IUser(userContractAddress).getUserInfo(msg.sender);
            require(iUserInfo.status == 2, 'auth error');
        }
        address NFTAddress = INFTControl(NFTControlAddress).createNFTContract(param0, param1, graphSqlAddress);
        IGraphSql(graphSqlAddress).addRole(NFTAddress);
        INFTControl.NFTInfo memory iNFTInfo = INFTControl(NFTControlAddress).getNFTContractInfo(NFTAddress);
        IGraphSql(graphSqlAddress).touchNFT(NFTAddress, iNFTInfo.tokenName, 0, 1, msg.sender, 0, iNFTInfo.tag, iNFTInfo.tokenImg);
    }


    /*
    * change NFT status
    */
    function SetNFTStatus(address NFTAddress, uint status_, uint price_, uint onSaleNumber_) public {
        address NFTContractOwner = INFTControl(NFTControlAddress).NFTCreatorAddress(NFTAddress);
        uint NFTIssueNumber = INFTControl(NFTControlAddress).issueNumber(NFTAddress);
        INFTControl.NFTInfo memory iNFTInfo = INFTControl(NFTControlAddress).getNFTContractInfo(NFTAddress);
        require(NFTContractOwner == msg.sender, 'not owner');
        require(NFTIssueNumber >= onSaleNumber_.add(NFTControlList[NFTAddress].soldNumber), 'Inventory shortage');
        NFTControlList[NFTAddress].price = price_;
        NFTControlList[NFTAddress].onSaleNumber = onSaleNumber_;
        NFTControlList[NFTAddress].status = status_;
        NFTControlList[NFTAddress].seller = NFTContractOwner;
        IGraphSql(graphSqlAddress).touchNFT(NFTAddress, iNFTInfo.tokenName, price_, status_, NFTContractOwner, onSaleNumber_, iNFTInfo.tag, iNFTInfo.tokenImg);
    }

    /*
    * change NFT single status
    */
    function setNFTSingleStatus(address NFTAddress, uint NFTId, uint price_, uint status_) public {
        require(status_ == 1 || status_ == 2, 'status err');
        string memory strs = string(abi.encodePacked(addressToString(NFTAddress), uint2str(NFTId)));
        ProductInfo memory iProductInfo = NFTList[strs];
        if (status_ == 2) {
            require(IERC721Base(NFTAddress).ownerOf(NFTId) == msg.sender, 'not NFT owner');
            iProductInfo.seller = msg.sender;
        } else if (status_ == 1) {
            require(iProductInfo.seller == msg.sender, 'This product is not owned by sender');
        }
        iProductInfo.price = price_;
        iProductInfo.contractAddress = NFTAddress;
        iProductInfo.NFTId = NFTId;
        iProductInfo.status = status_;
        NFTList[strs] = iProductInfo;

        if (status_ == 2) {
            IERC721Base(NFTAddress).transferFrom(msg.sender, address(this), NFTId);
        } else if (status_ == 1) {
            IERC721Base(NFTAddress).transferFrom(address(this), msg.sender, NFTId);
        }
        INFTControl.NFTInfo memory iNFTInfo = INFTControl(NFTControlAddress).getNFTContractInfo(NFTAddress);
        if(keccak256(abi.encodePacked(iNFTInfo.tokenName)) == keccak256(abi.encodePacked(''))){
            IBoxControl.NFTInfo memory iBoxNFTInfo = IBoxControl(boxControlAddress).getNFTContractInfo(NFTAddress);
            IGraphSql(graphSqlAddress).touchNFTSingle(NFTAddress, iBoxNFTInfo.tokenName, price_, status_, msg.sender, 0, NFTId, iBoxNFTInfo.tokenImg);
        } else {
            IGraphSql(graphSqlAddress).touchNFTSingle(NFTAddress, iNFTInfo.tokenName, price_, status_, msg.sender, iNFTInfo.tag, NFTId, iNFTInfo.tokenImg);
        }
    }


    function buyBox(address NFTAddress, uint num, uint amount) public payable {
        IBoxControl.NFTInfo memory iBoxNFTInfo = IBoxControl(boxControlAddress).getNFTContractInfo(NFTAddress);
        uint issueNumber = IBoxControl(boxControlAddress).issueNumber(NFTAddress);
        boxNFTControlInfo memory iMallBoxInfo = boxNFTControlList[NFTAddress];

        require(iBoxNFTInfo.endTime >= block.timestamp, 'already expired');
        require(iBoxNFTInfo.startTime <= block.timestamp, 'Not yet started');
        require(iMallBoxInfo.status == 2, 'Box status err');
//        require(address(msg.sender).balance > iBoxNFTInfo.price.mul(num), 'Insufficient balance');
        require(issueNumber >= iMallBoxInfo.soldNumber.add(num), 'Insufficient balance');

        if(feeErc20TokenAddress == address(0)){
            require(msg.value == iBoxNFTInfo.price.mul(num), 'Payment amount error');
            TransferHelper.safeTransferETH(iMallBoxInfo.seller, iBoxNFTInfo.price.mul(num));
        } else {
            require(amount == iBoxNFTInfo.price.mul(num), 'Payment amount error');
            IERC20(feeErc20TokenAddress).transferFrom(msg.sender, iMallBoxInfo.seller, iBoxNFTInfo.price.mul(num));
        }

        for (uint i = 0; i < num; i++) {
            IBoxControl(boxControlAddress).NFTMint(NFTAddress, msg.sender, iBoxNFTInfo.price);
        }
        iMallBoxInfo.soldNumber = iMallBoxInfo.soldNumber.add(num);
        // sold out
        if (issueNumber == iMallBoxInfo.soldNumber) {
            iMallBoxInfo.status = 3;
        }
        boxNFTControlList[NFTAddress] = iMallBoxInfo;
        IGraphSql(graphSqlAddress).touchBox(NFTAddress, iBoxNFTInfo.tokenName, iBoxNFTInfo.price, iBoxNFTInfo.startTime, iBoxNFTInfo.endTime, iMallBoxInfo.status, issueNumber.sub(iMallBoxInfo.soldNumber), iBoxNFTInfo.tokenImg);
    }

    function buyNFT(address NFTAddress, uint num, uint amount) public payable {
        NFTControlInfo memory iMallNFTInfo = NFTControlList[NFTAddress];
        require(iMallNFTInfo.status != 0, 'NFT not created');
//        require(iMallNFTInfo.onSaleNumber >= iMallNFTInfo.soldNumber.add(num), 'Insufficient balance');
        require(iMallNFTInfo.onSaleNumber >= num, 'Insufficient balance');

        uint iFee = iMallNFTInfo.price.mul(num).mul(fees[0]).div(10000);

        if(feeErc20TokenAddress == address(0)){
            require(msg.value == iMallNFTInfo.price.mul(num), 'Payment amount error');
            TransferHelper.safeTransferETH(iMallNFTInfo.seller, iMallNFTInfo.price.mul(num).sub(iFee));
            TransferHelper.safeTransferETH(handlingFeeAddress, iFee);
        } else {
            require(amount == iMallNFTInfo.price.mul(num), 'Payment amount error');
            IERC20(feeErc20TokenAddress).transferFrom(msg.sender, iMallNFTInfo.seller, iMallNFTInfo.price.mul(num).sub(iFee));
            IERC20(feeErc20TokenAddress).transferFrom(msg.sender, handlingFeeAddress, iFee);
        }

        iMallNFTInfo.soldNumber = iMallNFTInfo.soldNumber.add(num);
        iMallNFTInfo.onSaleNumber = iMallNFTInfo.onSaleNumber.sub(num);
        if (iMallNFTInfo.onSaleNumber == 0) {
            uint NFTIssueNumber = INFTControl(NFTControlAddress).issueNumber(NFTAddress);
            // sold out
            if(NFTIssueNumber == iMallNFTInfo.soldNumber){
                iMallNFTInfo.status = 3;
            } else {
                iMallNFTInfo.status = 1;
            }
        }
        NFTControlList[NFTAddress] = iMallNFTInfo;
        INFTControl.NFTInfo memory iNFTInfo = INFTControl(NFTControlAddress).getNFTContractInfo(NFTAddress);
        for (uint i = 0; i < num; i++) {
            INFTControl(NFTControlAddress).NFTMint(NFTAddress, msg.sender, iMallNFTInfo.price);
        }
        IGraphSql(graphSqlAddress).touchNFT(NFTAddress, iNFTInfo.tokenName, iMallNFTInfo.price, iMallNFTInfo.status, iMallNFTInfo.seller, iMallNFTInfo.onSaleNumber, iNFTInfo.tag, iNFTInfo.tokenImg);
    }

    // need test
    function buyNFTSingle(address NFTAddress, uint NFTId, uint amount) public payable {
        string memory strs = string(abi.encodePacked(addressToString(NFTAddress), uint2str(NFTId)));
        ProductInfo memory iProductInfo = NFTList[strs];
        require(iProductInfo.status == 2, 'status err');

        uint iFee = iProductInfo.price.mul(fees[1]).div(10000);

        if(feeErc20TokenAddress == address(0)){
            require(msg.value == iProductInfo.price, 'Payment amount error');
            TransferHelper.safeTransferETH(iProductInfo.seller, iProductInfo.price.sub(iFee));
            TransferHelper.safeTransferETH(handlingFeeAddress, iFee);
        } else {
            require(amount == iProductInfo.price, 'Payment amount error');
            IERC20(feeErc20TokenAddress).transferFrom(msg.sender, iProductInfo.seller, iProductInfo.price.sub(iFee));
            IERC20(feeErc20TokenAddress).transferFrom(msg.sender, handlingFeeAddress, iFee);
        }

        IERC721Base(NFTAddress).transferFrom1(address(this), msg.sender, NFTId, iProductInfo.price);
        NFTList[strs].status = 1;
        NFTList[strs].seller = msg.sender;
        INFTControl.NFTInfo memory iNFTInfo = INFTControl(NFTControlAddress).getNFTContractInfo(NFTAddress);
        if(keccak256(abi.encodePacked(iNFTInfo.tokenName)) == keccak256(abi.encodePacked(''))){
            IBoxControl.NFTInfo memory iBoxNFTInfo = IBoxControl(boxControlAddress).getNFTContractInfo(NFTAddress);
            IGraphSql(graphSqlAddress).touchNFTSingle(NFTAddress, iBoxNFTInfo.tokenName, NFTList[strs].price, NFTList[strs].status, NFTList[strs].seller, 0, NFTId, iBoxNFTInfo.tokenImg);
        } else {
            IGraphSql(graphSqlAddress).touchNFTSingle(NFTAddress, iNFTInfo.tokenName, NFTList[strs].price, NFTList[strs].status, NFTList[strs].seller, iNFTInfo.tag, NFTId, iNFTInfo.tokenImg);
        }
    }

    function getBoxNFTControlList(address address_) public view returns (boxNFTControlInfo memory iBoxNFTControlInfo) {
        iBoxNFTControlInfo = boxNFTControlList[address_];
        if(iBoxNFTControlInfo.status == 0) {
            iBoxNFTControlInfo.status = 1;
        }
        return iBoxNFTControlInfo;
    }

    function getNFTControlList(address address_) public view returns (NFTControlInfo memory iNFTControlInfo) {
        iNFTControlInfo = NFTControlList[address_];
        if(iNFTControlInfo.status == 0) {
            iNFTControlInfo.status = 1;
        }
        return iNFTControlInfo;
    }

    function getNFTList(address NFTAddress, uint NFTId) public view returns (ProductInfo memory ProductInfo1) {
        string memory str = string(abi.encodePacked(addressToString(NFTAddress), uint2str(NFTId)));
        ProductInfo1 = NFTList[str];
        if(ProductInfo1.status == 0) {
            ProductInfo1.status = 1;
        }
        return ProductInfo1;
    }

    function addressToString(address _addr) internal pure returns (string memory) {
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

    function uint2str(uint _i) internal pure returns (string memory _uintAsString) {
        if (_i == 0) {
            return "0";
        }
        uint j = _i;
        uint len;
        while (j != 0) {
            len++;
            j /= 10;
        }
        bytes memory bstr = new bytes(len);
        uint k = len;
        while (_i != 0) {
            k = k - 1;
            uint8 temp = (48 + uint8(_i - _i / 10 * 10));
            bytes1 b1 = bytes1(temp);
            bstr[k] = b1;
            _i /= 10;
        }
        return string(bstr);
    }

    /**
   * Always returns `IERC721Receiver.onERC721Received.selector`.
   */
    function onERC721Received(address, address, uint256, bytes memory) public virtual override returns (bytes4) {
        return this.onERC721Received.selector;
    }

    function addRole(address account) public auth(GLOBAL_ROLE){
        grantRole(GLOBAL_ROLE, account);
    }

    function rmRole(address account) public auth(GLOBAL_ROLE){
        this.revokeRole(GLOBAL_ROLE, account);
    }


}
