pragma solidity 0.6.12;

import "./lib/token/BEP20/BEP20.sol";

// El Rune
contract El is BEP20('El', 'EL') {
    uint256 public vaultFee = 0;
    uint256 public charityFee = 0;
    uint256 public devFee = 0;
    uint256 public botFee = 0;

    address public vaultAddress;
    address public charityAddress;
    address public devAddress;
    address public botAddress;

    mapping (address => bool) public isExcluded;
    address[] public excluded;

    mapping (address => bool) public isBot;
    address[] public bot;

    bool mintable = true;

    function mint(address _to, uint256 _amount) public onlyOwner {
        require(mintable == true, 'Minting has been forever disabled');
        _mint(_to, _amount);
    }

    function safe32(uint n, string memory errorMessage) internal pure returns (uint32) {
        require(n < 2**32, errorMessage);
        return uint32(n);
    }

    function getChainId() internal pure returns (uint) {
        uint256 chainId;
        assembly { chainId := chainid() }
        return chainId;
    }

    function disableMintingForever() public onlyOwner() {
        mintable = false;
    }

    function setFeeInfo(address _vaultAddress, address _charityAddress, address _devAddress, address _botAddress, uint256 _vaultFee, uint256 _charityFee, uint256 _devFee, uint256 _botFee) public onlyOwner()
    {
        require (_vaultAddress != address(0) && _charityAddress != address(0) && _devAddress != address(0) && _botAddress != address(0), "RUNE::setFeeInfo: Cannot use zero address");
        require (_vaultFee <= 100 && _charityFee <= 10 && _devFee <= 10 && _botFee <= 2000, "RUNE::_transfer: Fee constraints");

        vaultAddress = _vaultAddress;
        charityAddress = _charityAddress;
        devAddress = _devAddress;
        botAddress = _botAddress;

        vaultFee = _vaultFee;
        charityFee = _charityFee;
        devFee = _devFee;
        botFee = _botFee;
    }

    function addExcluded(address account) external onlyOwner() {
        require(!isExcluded[account], "RUNE::addExcluded: Account is already excluded");

        isExcluded[account] = true;
        excluded.push(account);
    }

    function removeExcluded(address account) external onlyOwner() {
        require(isExcluded[account], "RUNE::removeExcluded: Account isn't excluded");
        for (uint256 i = 0; i < excluded.length; i++) {
            if (excluded[i] == account) {
                excluded[i] = excluded[excluded.length - 1];
                isExcluded[account] = false;
                excluded.pop();
                break;
            }
        }
    }

    function addBot(address account) external onlyOwner() {
        require(!isBot[account], "RUNE::addBot: Account is already bot");

        isBot[account] = true;
        bot.push(account);
    }

    function removeBot(address account) external onlyOwner() {
        require(isBot[account], "RUNE::removeBot: Account isn't bot");
        for (uint256 i = 0; i < bot.length; i++) {
            if (bot[i] == account) {
                bot[i] = bot[bot.length - 1];
                isBot[account] = false;
                bot.pop();
                break;
            }
        }
    }

    function _transfer(address sender, address recipient, uint256 amount) internal override {
        require(sender != address(0), "RUNE::_transfer: Transfer from the zero address");
        require(recipient != address(0), "RUNE::_transfer: Transfer to the zero address");
    
        if (isBot[sender]) {
            _transferBot(sender, recipient, amount);
        } else if (isExcluded[sender] && !isExcluded[recipient]) {
            _transferFromExcluded(sender, recipient, amount);
        } else if (!isExcluded[sender] && isExcluded[recipient]) {
            _transferToExcluded(sender, recipient, amount);
        } else if (!isExcluded[sender] && !isExcluded[recipient]) {
            _transferStandard(sender, recipient, amount);
        } else if (isExcluded[sender] && isExcluded[recipient]) {
            _transferBothExcluded(sender, recipient, amount);
        } else {
            _transferStandard(sender, recipient, amount);
        }
    }

    function _transferBot(address sender, address recipient, uint256 amount) private {
        uint256 _botFee = amount.mul(botFee).div(10000);
        uint256 transferAmount = amount.sub(_botFee)

        if (_botFee > 0) {
            emit Transfer(sender, botAddress, _botFee);
            _balances[botAddress] = _balances[botAddress].add(_botFee);
        }

        _balances[sender] = _balances[sender].sub(amount);
        _balances[recipient] = _balances[recipient].add(transferAmount);

        emit Transfer(sender, recipient, transferAmount);
    }

    function _transferStandard(address sender, address recipient, uint256 amount) private {
        uint256 _vaultFee = amount.mul(vaultFee).div(10000);
        uint256 _charityFee = amount.mul(charityFee).div(10000);
        uint256 _devFee = amount.mul(devFee).div(10000);
        uint256 transferAmount = amount.sub(_vaultFee).sub(_charityFee).sub(_devFee);

        if (_vaultFee > 0) {
            emit Transfer(sender, vaultAddress, _vaultFee);
            _balances[vaultAddress] = _balances[vaultAddress].add(_vaultFee);
        }

        if (_charityFee > 0) {
            emit Transfer(sender, charityAddress, _charityFee);
            _balances[charityAddress] = _balances[charityAddress].add(_charityFee);
        }

        if (_devFee > 0) {
            emit Transfer(sender, devAddress, _devFee);
            _balances[devAddress] = _balances[devAddress].add(_devFee);
        }

        _balances[sender] = _balances[sender].sub(amount);
        _balances[recipient] = _balances[recipient].add(transferAmount);

        emit Transfer(sender, recipient, transferAmount);
    }

    function _transferToExcluded(address sender, address recipient, uint256 amount) private {
        _balances[sender] = _balances[sender].sub(amount);
        _balances[recipient] = _balances[recipient].add(amount);

        emit Transfer(sender, recipient, amount);
    }

    function _transferFromExcluded(address sender, address recipient, uint256 amount) private {
        _balances[sender] = _balances[sender].sub(amount);
        _balances[recipient] = _balances[recipient].add(amount);

        emit Transfer(sender, recipient, amount);
    }

    function _transferBothExcluded(address sender, address recipient, uint256 amount) private {
        _balances[sender] = _balances[sender].sub(amount);
        _balances[recipient] = _balances[recipient].add(amount);

        emit Transfer(sender, recipient, amount);
    }

}