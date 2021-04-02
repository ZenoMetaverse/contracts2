pragma solidity 0.6.12;

import "./lib/math/SafeMath.sol";
import "./lib/token/BEP20/BEP20.sol";
import "./lib/token/BEP20/SafeBEP20.sol";
import "./RuneToken.sol";

contract Void {
    using SafeMath for uint256;

    RuneToken public rune;
    address public devAddress;

    constructor(
        RuneToken _rune,
        address _devAddress
    ) public {
        rune = _rune;
        devAddress = _devAddress;
    }

    function proxy_setFeeInfo(address _vaultAddress, address _charityAddress, address _devAddress, uint256 _vaultFee, uint256 _charityFee, uint256 _devFee) external
    {
        require(msg.sender == devAddress, "dev: wut?");
        rune.setFeeInfo(_vaultAddress, _charityAddress, _devAddress, _vaultFee, _charityFee, _devFee);
    }

    function proxy_addExcluded(address _account) external {
        require(msg.sender == devAddress, "dev: wut?");
        rune.addExcluded(_account);
    }

    function proxy_removeExcluded(address _account) external {
        require(msg.sender == devAddress, "dev: wut?");
        rune.removeExcluded(_account);
    }
}