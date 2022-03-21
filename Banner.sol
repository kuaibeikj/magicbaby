// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;
pragma experimental ABIEncoderV2;

import "hardhat/console.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";

contract Banner is AccessControl {
    using SafeMath for uint256;
    bytes32 public constant GLOBAL_ROLE = "GLOBAL_ROLE";
    BannerInfo[] public bannerArr;

    struct BannerInfo {
        uint id;
        string name;
        string webUrl;
        string imgUrl;
        // 0default 1Unhandled 2pass 3reject
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
        grantRole(GLOBAL_ROLE, msg.sender);
    }

    function setBanner(string calldata name_, string calldata webUrl_, string calldata imgUrl_) public auth(GLOBAL_ROLE) {
        BannerInfo memory iBannerInfo;
        iBannerInfo.id = bannerArr.length;
        iBannerInfo.name = name_;
        iBannerInfo.webUrl = webUrl_;
        iBannerInfo.imgUrl = imgUrl_;
        iBannerInfo.status = 1;
        iBannerInfo.createTime = block.timestamp;
        bannerArr.push(iBannerInfo);
    }

    function processBanner(uint id, uint status) public auth(GLOBAL_ROLE) {
        bannerArr[id].status = status;
    }

    function getBannerList(uint256 _page, uint256 _size) public view returns (BannerInfo[] memory returnBannerArr){
        uint256 bannerLength = bannerArr.length;
        require(_page >= 1, "invalid param");
        require(_page.sub(1).mul(_size) <= bannerLength, "invalid param");
        uint256 max;
        if (_page.mul(_size) >= bannerLength) {
            max = bannerLength;
        } else {
            max = _page.mul(_size);
        }
        uint256 begin = _page.sub(1).mul(_size);
        uint returnLength = max - begin;
        BannerInfo[] memory returnBannerArr1 = new BannerInfo[](returnLength);
        for (uint256 i = begin; i < max; i++) {
            returnBannerArr1[i] = bannerArr[i];
        }
        return returnBannerArr1;
    }

    function addRole(address account) public auth(GLOBAL_ROLE){
        grantRole(GLOBAL_ROLE, account);
    }

    function rmRole(address account) public auth(GLOBAL_ROLE){
        this.revokeRole(GLOBAL_ROLE, account);
    }

}
