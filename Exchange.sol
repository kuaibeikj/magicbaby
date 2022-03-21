// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;
pragma experimental ABIEncoderV2;

import "hardhat/console.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "./interface/IBaseNFT0.sol";
import "./interface/IGraphSql.sol";
import "./interface/INFTControl.sol";

contract Exchange is AccessControl {
    using SafeMath for uint256;
    bytes32 public constant GLOBAL_ROLE = "GLOBAL_ROLE";
    ExchangeInfo[] public exchangeInfo;
    History[] public historyArr;
    address public graphSqlAddress;
    uint notShipped;
    uint shipped;
    address  public NFTControlAddress;

    struct ExchangeInfo {
        uint id;
        string name;
        address getContractAddress;
        string img;
        string introduce;
        address[] sendContractAddress;
        uint[] sendContractNumber;
        string[] sendContractName;
        uint redeemed;
        // 0default 1Unhandled 2pass
        uint status;
    }

    struct History {
        uint orderId;
        uint exChangeId;
        string name;
        string information;
        // status 1to be deliver ed 2Shipped
        uint status;
        uint createTime;
    }

    // 定义一个拦截器用来判断权限
    modifier auth(bytes32 iRrole) {
        require(hasRole(iRrole, msg.sender), "Permission denied");
        _;
    }

    constructor(){
        _setupRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _setupRole(GLOBAL_ROLE, msg.sender);
    }

    function setGraphSqlAddress(address address_) public auth(GLOBAL_ROLE) {
        graphSqlAddress = address_;
    }

    function setNFTControlAddress(address address_) public auth(GLOBAL_ROLE) {
        NFTControlAddress = address_;
    }

    function submitExchange0(string calldata name_, address getContractAddress_, address[] memory sendContractAddress_, uint[] memory sendContractNumber_, string[] memory sendContractName_) public auth(GLOBAL_ROLE) {
        require(sendContractAddress_.length == sendContractNumber_.length, "the quantity of sendContractAddress must be equal to sendContractNumber");
        ExchangeInfo memory iExchangeInfo;
        iExchangeInfo.id = exchangeInfo.length;
        iExchangeInfo.name = name_;
        iExchangeInfo.getContractAddress = getContractAddress_;
        iExchangeInfo.img = "";
        iExchangeInfo.introduce = "";
        iExchangeInfo.sendContractAddress = sendContractAddress_;
        iExchangeInfo.sendContractNumber = sendContractNumber_;
        iExchangeInfo.sendContractName = sendContractName_;
        iExchangeInfo.status = 1;
        exchangeInfo.push(iExchangeInfo);
        IGraphSql(graphSqlAddress).exchange(iExchangeInfo.id, iExchangeInfo.name, iExchangeInfo.sendContractAddress, iExchangeInfo.sendContractNumber, iExchangeInfo.img, iExchangeInfo.introduce, 1, 1, iExchangeInfo.sendContractName);
    }

    function submitExchange1(string calldata name_, string calldata introduce_, string calldata img_, address[] memory sendContractAddress_, uint[] memory sendContractNumber_, string[] memory sendContractName_) public auth(GLOBAL_ROLE) {
        require(sendContractAddress_.length == sendContractNumber_.length && sendContractAddress_.length == 1, "the quantity of sendContractAddress must be equal to sendContractNumber");
        ExchangeInfo memory iExchangeInfo;
        iExchangeInfo.id = exchangeInfo.length;
        iExchangeInfo.name = name_;
        iExchangeInfo.getContractAddress = address(0);
        iExchangeInfo.img = img_;
        iExchangeInfo.introduce = introduce_;
        iExchangeInfo.sendContractAddress = sendContractAddress_;
        iExchangeInfo.sendContractNumber = sendContractNumber_;
        iExchangeInfo.sendContractName = sendContractName_;
        iExchangeInfo.status = 1;
        exchangeInfo.push(iExchangeInfo);
        IGraphSql(graphSqlAddress).exchange(iExchangeInfo.id, iExchangeInfo.name, iExchangeInfo.sendContractAddress, iExchangeInfo.sendContractNumber, iExchangeInfo.img, iExchangeInfo.introduce, 1, 2, iExchangeInfo.sendContractName);
    }

    function processExchange(uint id_, uint status_) public auth(GLOBAL_ROLE) {
        exchangeInfo[id_].status = status_;
        ExchangeInfo memory iExchangeInfo = exchangeInfo[id_];
        IGraphSql(graphSqlAddress).exchange(iExchangeInfo.id, iExchangeInfo.name, iExchangeInfo.sendContractAddress, iExchangeInfo.sendContractNumber, iExchangeInfo.img, iExchangeInfo.introduce, status_, 2, iExchangeInfo.sendContractName);
    }

    function setStatus(uint id_, uint status_) public auth(GLOBAL_ROLE) {
        require(historyArr[id_].status != status_, 'Same status, no modification required');
        historyArr[id_].status = status_;
        if(status_ == 1){
            notShipped--;
            shipped++;
        } else {
            notShipped++;
            shipped--;
        }
    }

    function getRuleById(uint id_) public view returns(ExchangeInfo memory iExchangeInfo) {
        return exchangeInfo[id_];
    }

    function getList(uint256 _page, uint256 _size) public view returns (History[] memory exchangeList){
        uint256 exchangeLength = historyArr.length;
        require(_page >= 1, "invalid param");
        require(_page.sub(1).mul(_size) <= exchangeLength, "invalid param");
        uint256 max;
        if (_page.mul(_size) >= exchangeLength) {
            max = exchangeLength;
        } else {
            max = _page.mul(_size);
        }
        uint256 begin = _page.sub(1).mul(_size);
        uint returnLength = max - begin;
        History[] memory exchangeArr = new History[](returnLength);
        for (uint256 i = begin; i < max; i++) {
            exchangeArr[i] = historyArr[i];
        }
        return exchangeArr;
    }

    function toExchange(uint id_, string calldata information_) public{
        ExchangeInfo memory iExchangeInfo = exchangeInfo[id_];
        require(iExchangeInfo.status == 2, 'status error');
        for (uint256 i = 0; i < iExchangeInfo.sendContractAddress.length; i++) {
            IBaseNFT0 NFTObj0 = IBaseNFT0(iExchangeInfo.sendContractAddress[i]);
            require(NFTObj0.balanceOf(msg.sender) >= iExchangeInfo.sendContractNumber[i], 'Not enough NFT');
            for (uint256 j = 0; j < iExchangeInfo.sendContractNumber[i]; j++) {
                uint iTokenId = NFTObj0.tokenOfOwnerByIndex(msg.sender, 0);
                NFTObj0.burnBase(iTokenId);
            }
        }
        exchangeInfo[id_].redeemed++;
        if(iExchangeInfo.getContractAddress == address(0)){
            History memory iHistory;
            iHistory.orderId = historyArr.length;
            iHistory.exChangeId = id_;
            iHistory.name = iExchangeInfo.name;
            iHistory.information = information_;
            iHistory.createTime = block.timestamp;
            iHistory.status = 0;
            notShipped++;
            historyArr.push(iHistory);
        } else {
//            iHistory.status = 1;
            INFTControl NFTControlObj = INFTControl(NFTControlAddress);
            NFTControlObj.NFTMint(iExchangeInfo.getContractAddress, msg.sender, 0);
        }
    }

    function getExchangeInfoLength() public view returns(uint){
        return exchangeInfo.length;
    }

    function quantityShipped() public view returns(uint){
        return shipped;
    }

    function unshippedQuantity() public view returns(uint){
        return notShipped;
    }

    function addRole(address account) public auth(GLOBAL_ROLE){
        grantRole(GLOBAL_ROLE, account);
    }

    function rmRole(address account) public auth(GLOBAL_ROLE){
        this.revokeRole(GLOBAL_ROLE, account);
    }

}
