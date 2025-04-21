// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import './HLUSDC.sol';
import './HLUSDCIssuer.sol';

contract HLUSDCIssuerFactory {
  mapping(address => address) public issuerOf;
  mapping(address => address) public ownerOf;

  address public owner;
  address public hlusdc;

  event IssuerCreated(address indexed issuer, address indexed owner);

  constructor(address _owner) {
    owner = _owner;
  }

  modifier onlyOwner() {
    require(msg.sender == owner, "Only owner can call this function");
    _;
  }

  modifier isActive() {
    require(hlusdc != address(0), "HLUSDC is not set");
    _;
  }


  // @dev create an issuer account for caller, only enabled after hlusdc is configured
  function createIssuerAccount() public isActive {
    // make sure caller is not already an issuer
    require(issuerOf[msg.sender] == address(0), "Issuer already exists");

    // create an issuer account for caller
    HLUSDCIssuer issuer = new HLUSDCIssuer(msg.sender, hlusdc, address(this));
    issuerOf[msg.sender] = address(issuer);
    ownerOf[address(issuer)] = msg.sender;
    emit IssuerCreated(address(issuer), msg.sender);
  }

  // check if HLUSDCIssuer is created from this factory
  function isIssuer(address issuer) public view returns (bool) {
    return ownerOf[issuer] != address(0);
  }

  // ... owner only ... 

  function setHLUSDC(address _hlusdc) public onlyOwner {
    require(hlusdc == address(0), "HLUSDC is already set");
    hlusdc = _hlusdc;
  }
}