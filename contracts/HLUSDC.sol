// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./interfaces/L1Write.sol";
import "./HLUSDCIssuerFactory.sol";

/**
 * @title Wrapped HLUSDC
 * @author @chrisling-dev
 * @notice An ERC20 wrapper of USDC (Spot) on Hyperliquid L1
 * @dev HLUSDC is minted by `HLUSDCIssuer` and can be redeemed for USDC on L1
 */
contract HLUSDC {
  string public name = "Wrapped Hyperliquid USDC";
  string public symbol = "WHLUSDC";
  uint8 public decimals = 6;
  uint8 public spotDecimals = 8;

  address constant SPOT_BALANCE_PRECOMPILE_ADDRESS = 0x0000000000000000000000000000000000000801;
  address constant SYSTEM_PRECOMPILE_ADDRESS = 0x3333333333333333333333333333333333333333;

  L1Write public systemPrecompile = L1Write(SYSTEM_PRECOMPILE_ADDRESS);

  struct SpotBalance {
    uint64 total;
    uint64 hold;
    uint64 entryNtl;
  }

  event Approval(address indexed src, address indexed guy, uint wad);
  event Transfer(address indexed src, address indexed dst, uint wad);
  event Deposit(address indexed dst, uint wad);
  event Withdrawal(address indexed src, uint wad);

  mapping(address => uint256) public balanceOf;
  mapping(address => mapping(address => uint256)) public allowance;
  uint256 public totalSupply;

  // owner is able to rescue balances sent to contract by mistake
  address public owner;
  HLUSDCIssuerFactory public issuerFactory;

  // @dev denomitator is L1 spot asset decimals, default to 1 usdc on L1
  uint64 public l1AccountActivationFee = 1e8;

  constructor(address _owner) {
    owner = _owner;
  }

  modifier onlyOwner() {
    require(msg.sender == owner, "Only owner can call this function");
    _;
  }

  modifier onlyIssuer() {
    require(issuerFactory.isIssuer(msg.sender), "Only issuer can call this function");
    _;
  }

  // all issuers can mint HLUSDC
  // the validations are done in the issuer contract
  function mint(uint64 amount) public onlyIssuer {
    // issuers mint using amount denominated in L1 spot decimals
    uint256 convertedAmount = convertToContractDecimals(amount);
    balanceOf[msg.sender] += convertedAmount;
    totalSupply += convertedAmount;

    emit Deposit(msg.sender, convertedAmount);
    emit Transfer(address(0), msg.sender, convertedAmount);
  }

  // anyone with hlUSD can withdraw
  // if a mint request is active, any withdrawal will reduce the locked spot balance
  // to mimic the new spot balance on l1 after the withdrawal
  function withdraw(uint256 amount) public {
    uint64 convertedAmount = convertToSpotDecimals(amount);
    require(convertedAmount > l1AccountActivationFee, "Amount must be greater than account activation fee");

    require(balanceOf[msg.sender] >= amount);
    balanceOf[msg.sender] -= amount;
    totalSupply -= amount;

    // a withdraw fee is applied to offset the account activation fee on L1
    systemPrecompile.sendSpot(msg.sender, 0, convertedAmount - l1AccountActivationFee);

    emit Withdrawal(msg.sender, amount);
    emit Transfer(msg.sender, address(0), amount);
  }

  function approve(address guy, uint256 amount) public returns (bool) {
    allowance[msg.sender][guy] = amount;
    emit Approval(msg.sender, guy, amount);
    return true;
  }

  function transfer(address dst, uint256 amount) public returns (bool) {
    return transferFrom(msg.sender, dst, amount);
  }

  function transferFrom(address src, address dst, uint256 amount) public returns (bool) {
    require(balanceOf[src] >= amount);

    if (src != msg.sender && allowance[src][msg.sender] != type(uint256).max) {
      require(allowance[src][msg.sender] >= amount);
      allowance[src][msg.sender] -= amount;
    }

    balanceOf[src] -= amount;
    balanceOf[dst] += amount;

    emit Transfer(src, dst, amount);

    return true;
  }

  // ... utility functions ...

  function convertToSpotDecimals(uint256 amount) public view returns (uint64) {
    return uint64(amount * 10 ** spotDecimals / 10 ** decimals);
  }

  function convertToContractDecimals(uint64 amount) public view returns (uint256) {
    return amount * 10 ** decimals / 10 ** spotDecimals;
  }

  // ... owner only ... 

  function revokeOwnership() public onlyOwner {
    owner = address(0);
  }

  function setL1AccountActivationFee(uint64 fee) public onlyOwner {
    require(fee > 0, "fee must be greater than 0");
    l1AccountActivationFee = fee;
  }

  function setIssuerFactory(address _issuerFactory) public onlyOwner {
    issuerFactory = HLUSDCIssuerFactory(_issuerFactory);
  }

  // allows owner to rescue tokens send to the contract by mistake
  function rescueSpot(uint64 token, uint64 amount) public onlyOwner {
    require(amount > 0, "amount must be greater than 0");

    SpotBalance memory contractBalance = spotBalance(address(this), token);
    uint64 convertedTotalSupply = convertToSpotDecimals(totalSupply);

    // compute the extra L1 spot balance not recorded in totalSupply
    // keep 1e8 to keep the account activated on L1
    uint64 additionalBalance = contractBalance.total - 1e8 - convertedTotalSupply;

    if(amount == type(uint64).max) {
      require(additionalBalance > 0, "No additional balance to skim");
      // send all additional balance to owner address
      systemPrecompile.sendSpot(owner, token, additionalBalance);
    } else {
      require(amount <= additionalBalance, "Cannot skim more than spot balance - totalSupply");
      // send custom amount of spot balance to owner address
      systemPrecompile.sendSpot(owner, token, amount);
    }
  }

  // rescue perps usdc accidentally sent to the contract
  function rescuePerps(uint64 wad) public onlyOwner {
    systemPrecompile.sendUsdClassTransfer(wad, false);
  }

  // ... precompile reads ...

  function spotBalance(address user, uint64 token) public view returns (SpotBalance memory) {
    bool success;
    bytes memory result;
    (success, result) = SPOT_BALANCE_PRECOMPILE_ADDRESS.staticcall(abi.encode(user, token));
    require(success, "SpotBalance precompile call failed");
    return abi.decode(result, (SpotBalance));
  }
}