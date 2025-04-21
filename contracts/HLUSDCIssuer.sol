// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./interfaces/L1Write.sol";
import "./HLUSDC.sol";
import "./HLUSDCIssuerFactory.sol";

/**
 * @title HLUSDCIssuer
 * @author @chrisling-dev
 * @notice HLUSDCIssuer allows a users to mint HLUSDC by depositing USDC on L1, every user has their own HLUSDCIssuer
 */
contract HLUSDCIssuer {

    address constant SPOT_BALANCE_PRECOMPILE_ADDRESS = 0x0000000000000000000000000000000000000801;
    address constant SYSTEM_PRECOMPILE_ADDRESS = 0x3333333333333333333333333333333333333333;
    L1Write public systemPrecompile = L1Write(SYSTEM_PRECOMPILE_ADDRESS);

    HLUSDC public hlusdc;
    HLUSDCIssuerFactory public issuerFactory;
    address public owner;

    // mint states
    uint64 public mintAmount;
    uint64 public spotBalanceSnapshot;
    uint256 public mintRequestTimestamp;
    bool public isActivated;

    struct SpotBalance {
        uint64 total;
        uint64 hold;
        uint64 entryNtl;
    }

    constructor(address _owner, address _hlusdcAddress, address _issuerFactoryAddress) {
        owner = _owner;
        hlusdc = HLUSDC(_hlusdcAddress);
        issuerFactory = HLUSDCIssuerFactory(_issuerFactoryAddress);
    }

    modifier onlyOwner() {
        require(msg.sender == owner, "Only owner can call this function");
        _;
    }

    /**
     * Initiates a mint request by locking the contract and sending USDC on L1
     * @param l1Amount Amount of USDC to be deposited on L1
     * @dev call `initiateMintRequest` after user has deposited USDC on L1 to the contract address
     */
    function initiateMintRequest(uint64 l1Amount) public payable onlyOwner {
        // check if the contract is locked
        require(mintAmount == 0, "Mint request is already active");

        // amount must be greater than 0
        require(l1Amount > 0, "Amount must be greater than 0");

        // make sure contract has enough L1 USDC to transfer
        SpotBalance memory spotBalance = getSpotBalance(address(this), 0);
        require(spotBalance.total >= l1Amount, "Insufficient L1 USDC");

        // signal L1 to transfer the tokens
        systemPrecompile.sendSpot(address(hlusdc), 0, l1Amount);

        // lock contract
        mintAmount = l1Amount;
        spotBalanceSnapshot = spotBalance.total;
        mintRequestTimestamp = block.timestamp;

        // mark account as activated because spotBalance.total > l1Amount already tells us the account has balance / has been activated
        if(!isActivated) {
            isActivated = true;
        }
    }

    /**
     * Completes the mint by checking the balances on spotL1 and unlocks the contract
     * @param destination Address to receive the minted HLUSDC
     */
    function completeMint(address destination) public payable onlyOwner {
        // check if the contract is locked
        require(mintAmount > 0, "Mint request is not active");

        // token has been transferred on L1 if new balance = spotBalanceSnapshot - mintAmount
        SpotBalance memory spotBalance = getSpotBalance(address(this), 0);
        require(spotBalance.total == spotBalanceSnapshot - mintAmount, "Token has not been transferred on L1");

        uint256 oldBalance = hlusdc.balanceOf(address(this));
        hlusdc.mint(mintAmount);
        uint256 newBalance = hlusdc.balanceOf(address(this));
        
        // transfer to recipient
        if(destination != address(this)) {
            hlusdc.transfer(destination, newBalance - oldBalance);
        }

        // reset the mint request
        mintAmount = 0;
        spotBalanceSnapshot = 0;
        mintRequestTimestamp = 0;
    }

    // unlocks the contract if there was issue on L1 and USDC was not transferred
    // @dev DO NOT USE THIS FUNCTION IF USDC WAS TRANSFERRED ON L1 AS IT WILL LEAD TO LOSS OF USDC
    function clearMintRequest() public payable onlyOwner {
        mintAmount = 0;
        spotBalanceSnapshot = 0;
        mintRequestTimestamp = 0;
    }

    function transfer(address to, uint256 amount) public payable onlyOwner {
        hlusdc.transfer(to, amount);
    }

    // owners can withdraw spot balance from the contract when unlocked
    function withdrawSpot(uint64 token, uint64 amount) public payable onlyOwner {
      require(mintAmount == 0, "Active mint request");
      require(amount > 0, "Amount must be greater than 0");

      systemPrecompile.sendSpot(owner, token, amount);
    }

    function getMintState() public view returns (uint64, uint64, uint64, uint256, bool) {
      SpotBalance memory spotBalance = getSpotBalance(address(this), 0);
      return (mintAmount, spotBalanceSnapshot, spotBalance.total, mintRequestTimestamp, isActivated);
    }
    
      // ... precompile reads ...

    function getSpotBalance(address user, uint64 token) public view returns (SpotBalance memory) {
      bool success;
      bytes memory result;
      (success, result) = SPOT_BALANCE_PRECOMPILE_ADDRESS.staticcall(abi.encode(user, token));
      require(success, "SpotBalance precompile call failed");
      return abi.decode(result, (SpotBalance));
    }
}