// SPDX-License-Identifier: MIT

pragma solidity 0.6.12;

import "@openzeppelin/contracts/math/SafeMath.sol";
import "./libs/IBEP20.sol";
import "./libs/SafeBEP20.sol";

contract TokenTimelock {
    using SafeMath for uint256;
    using SafeBEP20 for IBEP20;

    IBEP20 public token;
    uint256 public releaseTime = now + 180 days;
    address public beneficiary;

    constructor(
        IBEP20 _token,
        address _beneficiary
    ) public {
        token = _token;
        beneficiary = _beneficiary;
    }

    function release() external {
        require(now >= releaseTime, "TokenTimelock: current time is before release time");
        uint256 amount = token.balanceOf(address(this));
        require(amount > 0, "TokenTimelock: no tokens to release");
        token.safeTransfer(beneficiary, amount);
    }

}