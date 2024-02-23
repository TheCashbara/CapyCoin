// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "./ITaxHandler.sol";
import "./IPinkAntiBot.sol";

///   █████████                                                    ███
///  ███░░░░░███                                                  ░░░
///  ███     ░░░   ██████   ████████  █████ ████  ██████   ██████  ████  ████████
/// ░███          ░░░░░███ ░░███░░███░░███ ░███  ███░░███ ███░░███░░███ ░░███░░███
/// ░███           ███████  ░███ ░███ ░███ ░███ ░███ ░░░ ░███ ░███ ░███  ░███ ░███
/// ░░███     ███ ███░░███  ░███ ░███ ░███ ░███ ░███  ███░███ ░███ ░███  ░███ ░███
///  ░░█████████ ░░████████ ░███████  ░░███████ ░░██████ ░░██████  █████ ████ █████
///   ░░░░░░░░░   ░░░░░░░░  ░███░░░    ░░░░░███  ░░░░░░   ░░░░░░  ░░░░░ ░░░░ ░░░░░
///                         ░███       ███ ░███
///                         █████     ░░██████
///                         ░░░░░       ░░░░░░


contract CapyCoin is ERC20, Ownable {
    address public immutable _capylikBurnWallet;

    /// @notice The contract implementing tax calculations.
    ITaxHandler public taxHandler;
    IPinkAntiBot public pinkAntiBot;

    //Declare an Event
    event UpdateComplete(
        address from,
        address to,
        uint256 sendAmount,
        uint256 fee
    );

    constructor(
        address taxHandlerAddress,
        address capylikBurnWallet,
        address pinkAntiBot_
    ) ERC20("CapyCoin", "CAPYCOIN") Ownable(_msgSender()) {
        require(taxHandlerAddress != address(0) && capylikBurnWallet != address(0), "taxHandlerAddress and capylikBurnWallet can't be the zero address.");
        
        _capylikBurnWallet = capylikBurnWallet;
        taxHandler = ITaxHandler(taxHandlerAddress);

        uint256 totalSupply = 1000000000 * (10**decimals());
        uint256 halfTotalSupply = totalSupply / 2;
        // Mint initial supply to the contract owner
        _mint(_msgSender(), halfTotalSupply);
        // Mint burn event supply to capylik burn wallet
        _mint(capylikBurnWallet, halfTotalSupply);

        // Create an instance of the PinkAntiBot variable from the provided address
        pinkAntiBot = IPinkAntiBot(pinkAntiBot_);
        // Register the deployer to be the token owner with PinkAntiBot. You can
        // later change the token owner in the PinkAntiBot contract
       pinkAntiBot.setTokenOwner(_msgSender());
    }

    function _update(
        address from,
        address to,
        uint256 amount
    ) internal virtual override {
        require(
            from != address(0) ||
                (from == address(0) &&
                    (to == address(owner()) || to == _capylikBurnWallet)),
            "From can't be the zero address"
        );

        if (from == address(0)) {
            super._update(from, to, amount);
            emit UpdateComplete(from, to, amount, 0);
        } else {
            pinkAntiBot.onPreTransferCheck(from, to, amount);
            uint256 fee;
            address feeReciever;
            (fee, feeReciever) = taxHandler.getTaxAmount(from, to, amount);
            if (fee > 0) {
                super._update(from, feeReciever, fee);
            }
            super._update(from, to, amount - fee);

            emit UpdateComplete(from, to, amount - fee, fee);
        }
    }
}