// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "./ITaxHandler.sol";


/// Calculates tax fee for a given token amount
contract TaxHandler is ITaxHandler, Ownable {
    uint16 private constant TAX_POINTS = 10000;
    uint16 private constant MAX_TAX_POINTS = 500; /// 5% of TAX_POINTS
    uint16 public _buyTaxPoints;
    uint16 public _sellTaxPoints;
    bool public _isTaxEnabled;

    address public receiver;

    mapping(address => bool) public whiteList;
    mapping(address => bool) public exchangePools;
    mapping(address => bool) public blackList;
    bool public _isBlacklistDisabled;

    event TaxPointsChanged(bool isBuyTax, uint16 newPoints);
    event RecieverChanged(address reciever);
    event TaxStatusChanged(bool isEnabled);
    event BlacklistDisabled();
    event AddedToWhitelist(address[] addressesAdded);
    event RemovedFromWhitelist(address[] addressesRemoved);
    event AddedToBlacklist(address[] addressesAdded);
    event RemovedFromBlacklist(address[] addressesRemoved);
    event AddedToExchangePool(address[] addressesAdded);
    event RemovedFromExchangePool(address[] addressesRemoved);

    constructor(address[] memory initialWhitelist)
        Ownable(_msgSender())
    {
        receiver = _msgSender();
        _isBlacklistDisabled = false;
        _isTaxEnabled = true;
        _buyTaxPoints = 500;
        _sellTaxPoints = 500;

        for (uint8 i = 0; i < initialWhitelist.length; i++) {
            whiteList[initialWhitelist[i]] = true;
        }
    }

    function getTaxAmount(
        address benefactor,
        address beneficiary,
        uint256 tokenAmount
    ) external view returns (uint256, address) {
        // Blacklisted addresses are only allowed to transfer to the receiver.
        if (!_isBlacklistDisabled && blackList[benefactor] == true) {
            if (beneficiary == receiver) {
                return (0, receiver);
            } else {
                revert("Benefactor has been blacklisted");
            }
        }

        if (!_isTaxEnabled) {
            return (0, receiver);
        }

        /// Exempted addresses don't pay tax.
        if (whiteList[benefactor] == true || whiteList[beneficiary] == true) {
            return (0, receiver);
        }

        /// Transactions between regular users (this includes contracts) aren't taxed.
        if (
            exchangePools[benefactor] == false &&
            exchangePools[beneficiary] == false
        ) {
            return (0, receiver);
        }

        /// Transactions between pools aren't taxed.
        if (
            exchangePools[benefactor] == true &&
            exchangePools[beneficiary] == true
        ) {
            return (0, receiver);
        }

        /// If the benefactor is found in the set of exchange pools, then it's a buy transactions, otherwise a sell
        /// transaction, because the other use cases have already been checked above.
        return (
            (tokenAmount / TAX_POINTS) *
                (
                    exchangePools[benefactor] == true
                        ? _buyTaxPoints
                        : _sellTaxPoints
                ),
            receiver
        );
    }

    function setTaxPoints(bool isBuyTax, uint16 points) external onlyOwner {
        require(
            points <= MAX_TAX_POINTS,
            "Tax points cannot exceed MAX_TAX_POINTS"
        );
        if (isBuyTax) {
            _buyTaxPoints = points;
        } else {
            _sellTaxPoints = points;
        }
        emit TaxPointsChanged(isBuyTax, points);
    }

    function setTaxStatus(bool isEnabled) external onlyOwner {
        _isTaxEnabled = isEnabled;
        emit TaxStatusChanged(isEnabled);
    }

    /// Once the blacklist is disabled it will stay disabled. This action is irreversible.
    function disableBlacklist() external onlyOwner {
        _isBlacklistDisabled = true;
        emit BlacklistDisabled();
    }

    function setReciever(address newReciever) external onlyOwner {
        require(
            newReciever != address(0),
            "Reciever can't be the zero address"
        );
        require(
            exchangePools[newReciever] == false,
            "Reciever can't be exchangePool"
        );

        receiver = newReciever;
        emit RecieverChanged(newReciever);
    }

    function addToWhitelist(address[] calldata toAddAddresses)
        external
        onlyOwner
    {
        for (uint256 i = 0; i < toAddAddresses.length; i++) {
            whiteList[toAddAddresses[i]] = true;
        }
        emit AddedToWhitelist(toAddAddresses);
    }

    function removeFromWhitelist(address[] calldata toRemoveAddresses)
        external
        onlyOwner
    {
        for (uint256 i = 0; i < toRemoveAddresses.length; i++) {
            delete whiteList[toRemoveAddresses[i]];
        }

        emit RemovedFromWhitelist(toRemoveAddresses);
    }

    function addToBlacklist(address[] calldata toAddAddresses)
        external
        onlyOwner
    {
        for (uint256 i = 0; i < toAddAddresses.length; i++) {
            blackList[toAddAddresses[i]] = true;
        }
        emit AddedToBlacklist(toAddAddresses);
    }

    function removeFromBlacklist(address[] calldata toRemoveAddresses)
        external
        onlyOwner
    {
        for (uint256 i = 0; i < toRemoveAddresses.length; i++) {
            delete blackList[toRemoveAddresses[i]];
        }
        emit RemovedFromBlacklist(toRemoveAddresses);
    }

    function addToExchangePools(address[] calldata toAddAddresses)
        external
        onlyOwner
    {
        for (uint256 i = 0; i < toAddAddresses.length; i++) {
            exchangePools[toAddAddresses[i]] = true;
        }
        emit AddedToExchangePool(toAddAddresses);
    }

    function removeFromExchangePools(address[] calldata toRemoveAddresses)
        external
        onlyOwner
    {
        for (uint256 i = 0; i < toRemoveAddresses.length; i++) {
            delete exchangePools[toRemoveAddresses[i]];
        }
        emit RemovedFromExchangePool(toRemoveAddresses);
    }
}
