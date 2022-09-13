// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./ERC20.sol";
import "./ReentrancyGuard.sol";
import "./SafeERC20.sol";


contract MainBridgeMainToken is ReentrancyGuard {
    address owner;
    ERC20 private mainToken;
    bool requireWhiteList;  // if this is true, then only the whitelisted addresses can transfer the tokens
    bool requireMaxPercent; // if this is true, only a cenrtain percent of coins will be available for transfer
    uint maxPercentAvailableForTransfer; // defining the percent if the requireMaxPercent is true

    // we need to keep the commissions in our contract, so we add a function to withdrawal the founds
    // 1 per transaction | 5 per transaction - fixed fees
    uint256 public commisionValue;
    uint256 public commission;
    uint256 collectedFees;

    mapping(address => uint256) public initialLimits; // initial limits of tokens that can be transfered
    mapping(address => uint256) public allreadyTrasfered; // initial limits of tokens that can be transfered
    mapping(address => uint8) public whiteList; // whitelist of addresses that can transfer tokens 
    mapping(address => uint8) public blackList; // theese adresses are blacklisted

    event TokensLocked(address indexed requester, uint amount, address contractAddress, uint timestamp);
    // event TokensUnlocked(address indexed requester, uint amount, uint timestamp);

    constructor () payable{
        owner = msg.sender;
        requireWhiteList = true;
        requireMaxPercent = true;
        maxPercentAvailableForTransfer = 20;
        commisionValue = 1;
        commission = commisionValue * 10**18;
    }

    function receiveTokens(address _transferTo) external payable nonReentrant returns (bool) {
        address user = msg.sender;
        uint256 amount = msg.value;

        require(blackList[user]==0, "User is blacklisted");          // check if user is blacklisted
        
        // check if we have whitelist active
        if (requireWhiteList){
            require(whiteList[user]==1, "User is not in the whitelist"); // check if user is allowed to transfer from this address
        }
        
        // check if we have specific percent set for transfer
        uint256 initialBalance = user.balance;
        if (requireMaxPercent) {
            if (initialLimits[user]==0) {
                initialLimits[user] = (initialBalance/100)*maxPercentAvailableForTransfer;
            }
            require(amount + allreadyTrasfered[user] <= initialLimits[user], "For the momment, you can transfer only a specific percent of your tokens");
        } else {
            require(amount <= initialBalance, "you cannot transfer more than you have");
        }

        // payable(address(this)).transfer(_amount);

        allreadyTrasfered[user] += amount;
        uint256 afterFees = amount - commission; // after fees
        collectedFees += commission;
        emit TokensLocked(user, afterFees, _transferTo, block.timestamp);

        return true;
    }

    function unlockTokens (address payable _user, uint _amount) onlyOwner nonReentrant external payable returns (bool){
        uint256 afterFees = _amount - commission; // after fees
        // SafeERC20.safeApprove(mainToken, _user, afterFees);
        _user.transfer(afterFees);
        collectedFees += commission;
        // emit TokensUnlocked(_user, afterFees, block.timestamp);

        return true;
    }

    function withdrawalTokens (address payable _user) onlyOwner nonReentrant external payable returns (bool){
        // SafeERC20.safeApprove(mainToken, _user, collectedFees);
        _user.transfer(collectedFees);
        collectedFees = 0;

        return true;
    }

    modifier onlyOwner {
      require(msg.sender == owner, "only gateway can execute this function");
      _;
    }

    function addToWhiteList(address _recipient) onlyOwner public {
        whiteList[_recipient] = 1;
    }

    function addToBlackList(address _recipient) onlyOwner public {
        whiteList[_recipient] = 1;
    }

    function removeFromWhiteList(address _recipient) onlyOwner public {
        whiteList[_recipient] = 0;
    }

    function removeFromBlackList(address _recipient) onlyOwner public {
        whiteList[_recipient] = 0;
    }

    function setPercent(uint percent) onlyOwner public {
        maxPercentAvailableForTransfer = percent;
    }

    function useWhiteList(bool value) onlyOwner public {
        requireWhiteList = value;
    }

    function usePercent(bool value) onlyOwner public {
        requireMaxPercent = value;
    }

    function changeCommissionValue(uint256 value) onlyOwner public {
        commisionValue = value;
        commission = commisionValue * 10**18;
    }
}
