//SPDX-License-Identifier: Unlicense
pragma solidity ^0.6.6;
import "hardhat/console.sol";

// 0xa43818fD4200dF55758DE9eb97BFf7CC1D81A0Ad
// /Users/a123456/Sites/qipai/reachMovie/artifacts/contracts/Greeter.sol/Greeter.json
// /home/reachContract/artifacts/contracts/Greeter.sol/Greeter.json
contract GravatarRegistry {
  event NewGravatar(uint id, address owner, string displayName, string imageUrl);
  event UpdatedGravatar(uint id, address owner, string displayName, string imageUrl);

  struct Gravatar {
    address owner;
    string displayName;
    string imageUrl;
  }

  Gravatar[] public gravatars;

  mapping (uint => address) public gravatarToOwner;
  mapping (address => uint) public ownerToGravatar;

  function createGravatar(string memory _displayName, string memory _imageUrl) public {
    require(ownerToGravatar[msg.sender] == 0);
    gravatars.push(Gravatar(msg.sender, _displayName, _imageUrl));
    uint id = gravatars.length - 1;

    gravatarToOwner[id] = msg.sender;
    ownerToGravatar[msg.sender] = id;

    emit NewGravatar(id, msg.sender, _displayName, _imageUrl);
  }

  function getGravatar(address owner) public view returns (string memory, string memory) {
    uint id = ownerToGravatar[owner];
    return (gravatars[id].displayName, gravatars[id].imageUrl);
  }

  function updateGravatarName(string memory _displayName) public {
    require(ownerToGravatar[msg.sender] != 0);
    require(msg.sender == gravatars[ownerToGravatar[msg.sender]].owner);

    uint id = ownerToGravatar[msg.sender];

    gravatars[id].displayName = _displayName;
    emit UpdatedGravatar(id, msg.sender, _displayName, gravatars[id].imageUrl);
  }

  function updateGravatarImage(string memory _imageUrl) public {
    require(ownerToGravatar[msg.sender] != 0);
    require(msg.sender == gravatars[ownerToGravatar[msg.sender]].owner);

    uint id = ownerToGravatar[msg.sender];

    gravatars[id].imageUrl =  _imageUrl;
    emit UpdatedGravatar(id, msg.sender, gravatars[id].displayName, _imageUrl);
  }

  // the gravatar at position 0 of gravatars[]
  // is fake
  // it's a mythical gravatar
  // that doesn't really exist
  // dani will invoke this function once when this contract is deployed
  // but then no more
  function setMythicalGravatar() public {
    require(msg.sender == address(0x6a5Cf604e0115B77d70aB355190Fd1bbaeB7a9df));
    gravatars.push(Gravatar(address(0), " ", " "));
  }

  function testFor() public view{
    for (uint i = 0; i < 7; i++) {
    }
    for (uint i = 0; i < 7; i++) {
      console.log('___1', i);
      if(i > 4){
        console.log('___2', i);
//        i = 10;
        return;
      }
    }
  }
}
