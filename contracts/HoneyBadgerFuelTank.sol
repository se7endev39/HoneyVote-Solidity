// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./interfaces/IUniswapV2Router02.sol";
import "./interfaces/IFuelTank.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/utils/Context.sol";
import "@openzeppelin/contracts/access/Ownable.sol";


contract HoneyBadgerFuelTank is Context, Ownable, IFuelTank {
  IUniswapV2Router02 uniswapRouter;

  address uniswapRouterAddress = 0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D;
  address public oldHoneyBadgerAddress;
  address public honeyBadgerAddress;

  mapping (address => uint) public reclaimableBalances;
  uint public liquidityBalance;

  uint public reclaimGuaranteeTime;
  uint public reclaimStartTime;

  constructor (address _oldHoneyBadgerAddress) {
    oldHoneyBadgerAddress = _oldHoneyBadgerAddress;
    uniswapRouter = IUniswapV2Router02(uniswapRouterAddress);
  }

  function addHoneyBadgeraddress(address _honeyBadgerAddress) public onlyOwner {
    require(honeyBadgerAddress == address(0));
    honeyBadgerAddress = _honeyBadgerAddress;
  }

  bool public nozzleOpen = false;
  function openNozzle() external override {
    require(!nozzleOpen, "AlreadyOpen");
    require(honeyBadgerAddress != address(0), "HoneyBadgerNotInitialized");
    require(msg.sender == honeyBadgerAddress, "MustBeHoneyBadger");

    reclaimStartTime = block.timestamp + (86400 * 2);
    reclaimGuaranteeTime = block.timestamp + (86400 * 9);

    nozzleOpen = true;
  }

  function addTokens(address user, uint amount) external override {
    require(honeyBadgerAddress != address(0), "HoneyBadgerNotInitialized");
    require(msg.sender == honeyBadgerAddress, "MustBeHoneyBadger");
    require(!nozzleOpen, "MustBePhase1");

    require(amount > 100, "amountTooSmall"); 

    uint granule = amount / 100;
    uint reclaimable = granule * 72;
    uint fuel = granule * 25;

    liquidityBalance += fuel;
    reclaimableBalances[user] = reclaimableBalances[user] + reclaimable;
  }

  function reclaimOldHoneyBadger() private {
    require(nozzleOpen, "Phase1");
    require(block.timestamp >= reclaimStartTime, "Phase2");
    address sender = msg.sender;
    require(reclaimableBalances[sender] > 0, "BalanceEmpty");

    IERC20(oldHoneyBadgerAddress).transfer(sender, reclaimableBalances[sender]);
    reclaimableBalances[sender] = 0;
  }

  function sellOldHoneyBadger(uint256 amount, uint256 amountOutMin) public onlyOwner {
    require(nozzleOpen);
    if (block.timestamp < reclaimGuaranteeTime) {
      require(amount <= liquidityBalance, "NotEnoughFuel");
      liquidityBalance -= amount;
    }

    IERC20 oldHoneyBadger = IERC20(oldHoneyBadgerAddress);
    require(oldHoneyBadger.approve(uniswapRouterAddress, amount), "Could not approve old honeybadger transfer");

    address[] memory path = new address[](2);
    path[0] = oldHoneyBadgerAddress;
    path[1] = uniswapRouter.WETH();
    uniswapRouter.swapExactTokensForTokensSupportingFeeOnTransferTokens(amount, amountOutMin, path, address(this), block.timestamp);
  }

  function provideLockedLiquidity(
        uint amountWETHDesired, uint amountHBDCDesired,
        uint amountWETHMin, uint amountHBDCMin,
        uint deadline) public onlyOwner {

    require(nozzleOpen);
    require(honeyBadgerAddress != address(0));

    address wethAddress = uniswapRouter.WETH();

    require(IERC20(wethAddress).approve(uniswapRouterAddress, amountWETHDesired),
      "Could not approve WETH transfer");

    require(IERC20(honeyBadgerAddress).approve(uniswapRouterAddress, amountHBDCDesired),
      "Could not approve HoneyBadger transfer");

    uniswapRouter.addLiquidity(
      uniswapRouter.WETH(),
      honeyBadgerAddress,
      amountWETHDesired,
      amountHBDCDesired,
      amountWETHMin,
      amountHBDCMin,
      address(0x000000000000000000000000000000000000dEaD),
      deadline); 
  }
}
