// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

interface IGraphSql {
    function touchBox(address contractAddress_, string calldata name_, uint price_, uint startTime_, uint endTime_, uint status_, uint onSaleNumber_, string calldata img_) external;
    function touchNFT(address contractAddress_, string calldata name_, uint price_, uint status_, address seller_, uint onSaleNumber_, uint tag_, string calldata img_) external;
    function touchNFTSingle(address contractAddress_, string calldata name_, uint price_, uint status_, address seller_, uint tag_, uint NFTId_, string calldata img_) external;
    function transferNFT(address contractAddress_, address from_, address to_, uint NFTId_, uint val) external;
    function addRole(address address_) external;
    function exchange(uint id_, string calldata name_, address[] memory sendContractAddress_, uint[] memory sendContractNumber_, string calldata img_, string calldata introduce_, uint status_, uint type_, string[] memory sendContractName_) external;
}

