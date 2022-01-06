// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;
interface IFuelTank {
  function openNozzle() external;
  function addTokens(address user, uint amount) external;
}
