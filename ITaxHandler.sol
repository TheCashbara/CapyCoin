// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface ITaxHandler {
    function getTaxAmount(
        address benefactor,
        address beneficiary,
        uint256 amount
    ) external view returns (uint256, address);
}
