// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;
pragma experimental ABIEncoderV2;

import "hardhat/console.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";

contract User is AccessControl {
    using SafeMath for uint256;
    bytes32 public constant GLOBAL_ROLE = "GLOBAL_ROLE";
    mapping(address => UserInfo) public userInfo;

    struct UserInfo {
        // allow mortgage
        string name;
        address userAddress;
        string email;
        string website;
        string introduce;
        string haedImg;
        string bgImg;
        // 0default 1Unhandled 2pass 3reject
        uint status;
    }

    address[] public userAddressArr;

    // 定义一个拦截器用来判断权限
    modifier auth(bytes32 iRrole) {
        require(hasRole(iRrole, msg.sender), "Permission denied");
        _;
    }

    constructor(){
        _setupRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _setupRole(GLOBAL_ROLE, msg.sender);
    }

    function submitAudit(string calldata name_, string calldata email_, string calldata website_, string calldata introduce_) public{
        require(userInfo[msg.sender].status == 0, 'user address already exists');
        UserInfo memory iUserInfo;
        iUserInfo.userAddress = msg.sender;
        iUserInfo.name = name_;
        iUserInfo.email = email_;
        iUserInfo.website = website_;
        iUserInfo.introduce = introduce_;
        iUserInfo.status = 1;
        userInfo[msg.sender] = iUserInfo;
        userAddressArr.push(msg.sender);
    }

    function processAudit(address userAddress, uint status) public auth(GLOBAL_ROLE) {
        userInfo[userAddress].status = status;
    }

    function setAudit(string calldata name_, string calldata introduce_, string calldata haedImg_, string calldata bgImg_) public{
        userInfo[msg.sender].name = name_;
        userInfo[msg.sender].introduce = introduce_;
        userInfo[msg.sender].haedImg = haedImg_;
        userInfo[msg.sender].bgImg = bgImg_;
    }

    function setHeadImg(string calldata img_) public{
        userInfo[msg.sender].haedImg = img_;
    }

    function setBgImg(string calldata img_) public{
        userInfo[msg.sender].bgImg = img_;
    }

    function getUserInfo(address addr_) public view returns (UserInfo memory iUserInfo){
        iUserInfo = userInfo[addr_];
        return iUserInfo;
    }

    function getUserList(uint256 _page, uint256 _size) public view returns (UserInfo[] memory UserInfoList){
        uint256 userLength = userAddressArr.length;
        require(_page >= 1, "invalid param");
        require(_page.sub(1).mul(_size) <= userLength, "invalid param");
        uint256 max;
        if (_page.mul(_size) >= userLength) {
            max = userLength;
        } else {
            max = _page.mul(_size);
        }
        uint256 begin = _page.sub(1).mul(_size);
        uint returnLength = max - begin;
        UserInfo[] memory userArr = new UserInfo[](returnLength);
        for (uint256 i = begin; i < max; i++) {
            userArr[i] = userInfo[userAddressArr[i]];
        }
        return userArr;
    }

    function addRole(address account) public auth(GLOBAL_ROLE){
        grantRole(GLOBAL_ROLE, account);
    }

    function rmRole(address account) public auth(GLOBAL_ROLE){
        this.revokeRole(GLOBAL_ROLE, account);
    }

}
