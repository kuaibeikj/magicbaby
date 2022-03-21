// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;
pragma experimental ABIEncoderV2;

import "hardhat/console.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";

contract GraphSql is AccessControl {
    bytes32 public constant GLOBAL_ROLE = "GLOBAL_ROLE";

    event eTouchBox(address contractAddress_, string name_, uint indexed price_, uint startTime_, uint endTime_, uint indexed status_, uint onSaleNumber_, string img_);
    event eTouchNFT(address contractAddress_, string name_, uint indexed price_, uint indexed status_, address seller_, uint onSaleNumber_, uint tag_, string img_);
    event eTouchNFTSingle(address contractAddress_, string name_, uint indexed price_, uint indexed status_, address seller_, uint tag_, uint NFTId_, string img_);
    event eTransferNFT(address contractAddress_, address from_, address to_, uint NFTId_, uint val);
    event eExchange(uint indexed id_, string name_, address[] sendContractAddress_, uint[] sendContractNumber_, string img_, string introduce_, uint status_, uint type_, string[] sendContractName_);

    // 定义一个拦截器用来判断权限
    modifier auth(bytes32 iRrole) {
        require(hasRole(iRrole, msg.sender), "Permission denied");
        _;
    }

    constructor(){
        _setupRole(GLOBAL_ROLE, msg.sender);
        _setupRole(DEFAULT_ADMIN_ROLE, msg.sender);
    }

    function supportsInterface(bytes4 interfaceId) public view virtual override(AccessControl) returns (bool) {
        return super.supportsInterface(interfaceId);
    }

    function touchBox(address contractAddress_, string calldata name_, uint price_, uint startTime_, uint endTime_, uint status_, uint onSaleNumber_, string calldata img_) public auth(GLOBAL_ROLE){
        emit eTouchBox(contractAddress_, name_, price_, startTime_, endTime_, status_, onSaleNumber_, img_);
    }

    function touchNFT(address contractAddress_, string calldata name_, uint price_, uint status_, address seller_, uint onSaleNumber_, uint tag_, string calldata img_) public auth(GLOBAL_ROLE){
        emit eTouchNFT(contractAddress_, name_, price_, status_, seller_, onSaleNumber_, tag_, img_);
    }

    function touchNFTSingle(address contractAddress_, string calldata name_, uint price_, uint status_, address seller_, uint tag_, uint NFTId_, string calldata img_) public auth(GLOBAL_ROLE){
        emit eTouchNFTSingle(contractAddress_, name_, price_, status_, seller_, tag_, NFTId_, img_);
    }

    function transferNFT(address contractAddress_, address from_, address to_, uint NFTId_, uint val) public auth(GLOBAL_ROLE){
        emit eTransferNFT(contractAddress_, from_, to_, NFTId_, val);
    }

    function exchange(uint id_, string calldata name_, address[] memory sendContractAddress_, uint[] memory sendContractNumber_, string calldata img_, string calldata introduce_, uint status_, uint type_, string[] memory sendContractName_) public auth(GLOBAL_ROLE){
        emit eExchange(id_, name_, sendContractAddress_, sendContractNumber_, img_, introduce_, status_, type_, sendContractName_);
    }

    function addRole(address address_) public auth(DEFAULT_ADMIN_ROLE){
        grantRole(GLOBAL_ROLE, address_);
        grantRole(DEFAULT_ADMIN_ROLE, address_);
    }

    function rmRole(address account) public auth(GLOBAL_ROLE){
        this.revokeRole(GLOBAL_ROLE, account);
    }



}
