pragma solidity 0.6.12;

import "../lib/math/SafeMath.sol";
import "../lib/token/BEP20/IBEP20.sol";
import "../lib/token/BEP20/SafeBEP20.sol";
import "../lib/access/Ownable.sol";

import "../runes/El.sol";

// MasterChef is the master of Rune. He can make Rune and he is a fair guy.
//
// Note that it's ownable and the owner wields tremendous power. The ownership
// will be transferred to a governance smart contract once RUNE is sufficiently
// distributed and the community can show to govern itself.
//
// Have fun reading it. Hopefully it's bug-free. God bless.
contract ElChef is Ownable {
    using SafeMath for uint256;
    using SafeBEP20 for IBEP20;

    // Info of each user.
    struct UserInfo {
        uint256 amount;         // How many LP tokens the user has provided.
        uint256 rewardDebt;     // Reward debt. See explanation below.
        //
        // We do some fancy math here. Basically, any point in time, the amount of RUNEs
        // entitled to a user but is pending to be distributed is:
        //
        //   pending reward = (user.amount * pool.accRunePerShare) - user.rewardDebt
        //
        // Whenever a user deposits or withdraws LP tokens to a pool. Here's what happens:
        //   1. The pool's `accRunePerShare` (and `lastRewardBlock`) gets updated.
        //   2. User receives the pending reward sent to his/her address.
        //   3. User's `amount` gets updated.
        //   4. User's `rewardDebt` gets updated.
    }

    // Info of each pool.
    struct PoolInfo {
        IBEP20 lpToken;           // Address of LP token contract.
        uint256 allocPoint;       // How many allocation points assigned to this pool. RUNEs to distribute per block.
        uint256 lastRewardBlock;  // Last block number that RUNEs distribution occurs.
        uint256 accRunePerShare;   // Accumulated RUNEs per share, times 1e12. See below.
        uint16 depositFeeBP;      // Deposit fee in basis points
    }

    // The RUNE TOKEN!
    ElRune public rune;
    // Dev address
    address public devAddress;
    // Charity address
    address public charityAddress;
    // RUNE tokens created per block.
    uint256 public runePerBlock;
    // Bonus muliplier for early rune makers.
    uint256 public constant BONUS_MULTIPLIER = 1;
    // Vault address
    address public vaultAddress;
    // Void address
    address public voidAddress;

    // Mint percent breakdown
    uint256 public devMintPercent = 0;
    uint256 public vaultMintPercent = 0;
    uint256 public charityMintPercent = 0;

    // Deposit fee breakdown
    uint256 public devDepositPercent = 0;
    uint256 public vaultDepositPercent = 0;
    uint256 public charityDepositPercent = 0;

    // Info of each pool.
    PoolInfo[] public poolInfo;
    // Info of each user that stakes LP tokens.
    mapping (uint256 => mapping (address => UserInfo)) public userInfo;
    // Total allocation points. Must be the sum of all allocation points in all pools.
    uint256 public totalAllocPoint = 0;
    // The block number when RUNE mining starts.
    uint256 public startBlock;

    event Deposit(address indexed user, uint256 indexed pid, uint256 amount);
    event Withdraw(address indexed user, uint256 indexed pid, uint256 amount);
    event EmergencyWithdraw(address indexed user, uint256 indexed pid, uint256 amount);

    constructor(
        ElRune _rune,
        address _devAddress,
        address _vaultAddress,
        address _charityAddress,
        address _voidAddress,
        uint256 _runePerBlock,
        uint256 _startBlock
    ) public {
        rune = _rune;
        devAddress = _devAddress;
        vaultAddress = _vaultAddress;
        charityAddress = _charityAddress;
        voidAddress = _voidAddress;
        runePerBlock = _runePerBlock;
        startBlock = _startBlock;
    }

    function poolLength() external view returns (uint256) {
        return poolInfo.length;
    }

    // Add a new lp to the pool. Can only be called by the owner.
    // XXX DO NOT add the same LP token more than once. Rewards will be messed up if you do.
    function add(uint256 _allocPoint, IBEP20 _lpToken, uint16 _depositFeeBP, bool _withUpdate) public onlyOwner {
        require(_depositFeeBP <= 10000, "add: invalid deposit fee basis points");
        if (_withUpdate) {
            massUpdatePools();
        }
        uint256 lastRewardBlock = block.number > startBlock ? block.number : startBlock;
        totalAllocPoint = totalAllocPoint.add(_allocPoint);
        poolInfo.push(PoolInfo({
            lpToken: _lpToken,
            allocPoint: _allocPoint,
            lastRewardBlock: lastRewardBlock,
            accRunePerShare: 0,
            depositFeeBP: _depositFeeBP
        }));
    }

    // Update the given pool's RUNE allocation point and deposit fee. Can only be called by the owner.
    function set(uint256 _pid, uint256 _allocPoint, uint16 _depositFeeBP, bool _withUpdate) public onlyOwner {
        require(_depositFeeBP <= 10000, "set: invalid deposit fee basis points");
        if (_withUpdate) {
            massUpdatePools();
        }
        totalAllocPoint = totalAllocPoint.sub(poolInfo[_pid].allocPoint).add(_allocPoint);
        poolInfo[_pid].allocPoint = _allocPoint;
        poolInfo[_pid].depositFeeBP = _depositFeeBP;
    }

    // Return reward multiplier over the given _from to _to block.
    function getMultiplier(uint256 _from, uint256 _to) public view returns (uint256) {
        return _to.sub(_from).mul(BONUS_MULTIPLIER);
    }

    // View function to see pending RUNEs on frontend.
    function pendingRune(uint256 _pid, address _user) external view returns (uint256) {
        PoolInfo storage pool = poolInfo[_pid];
        UserInfo storage user = userInfo[_pid][_user];
        uint256 accRunePerShare = pool.accRunePerShare;
        uint256 lpSupply = pool.lpToken.balanceOf(address(this));
        if (block.number > pool.lastRewardBlock && lpSupply != 0) {
            uint256 multiplier = getMultiplier(pool.lastRewardBlock, block.number);
            uint256 runeReward = multiplier.mul(runePerBlock).mul(pool.allocPoint).div(totalAllocPoint);
            accRunePerShare = accRunePerShare.add(runeReward.mul(1e12).div(lpSupply));
        }
        return user.amount.mul(accRunePerShare).div(1e12).sub(user.rewardDebt);
    }

    // Update reward variables for all pools. Be careful of gas spending!
    function massUpdatePools() public {
        uint256 length = poolInfo.length;
        for (uint256 pid = 0; pid < length; ++pid) {
            updatePool(pid);
        }
    }

    // Update reward variables of the given pool to be up-to-date.
    function updatePool(uint256 _pid) public {
        PoolInfo storage pool = poolInfo[_pid];
        if (block.number <= pool.lastRewardBlock) {
            return;
        }
        uint256 lpSupply = pool.lpToken.balanceOf(address(this));
        if (lpSupply == 0 || pool.allocPoint == 0 || runePerBlock == 0) {
            pool.lastRewardBlock = block.number;
            return;
        }
        uint256 multiplier = getMultiplier(pool.lastRewardBlock, block.number);
        uint256 runeReward = multiplier.mul(runePerBlock).mul(pool.allocPoint).div(totalAllocPoint);
        rune.mint(devAddress, runeReward.mul(devMintPercent).div(10000));
        rune.mint(vaultAddress, runeReward.mul(vaultMintPercent).div(10000));
        rune.mint(charityAddress, runeReward.mul(charityMintPercent).div(10000));
        rune.mint(address(this), runeReward);
        pool.accRunePerShare = pool.accRunePerShare.add(runeReward.mul(1e12).div(lpSupply));
        pool.lastRewardBlock = block.number;
    }

    // Deposit LP tokens to MasterChef for RUNE allocation.
    function deposit(uint256 _pid, uint256 _amount) public {
        PoolInfo storage pool = poolInfo[_pid];
        UserInfo storage user = userInfo[_pid][msg.sender];
        updatePool(_pid);
        if (user.amount > 0) {
            uint256 pending = user.amount.mul(pool.accRunePerShare).div(1e12).sub(user.rewardDebt);
            if(pending > 0) {
                safeRuneTransfer(msg.sender, pending);
            }
        }
        if(_amount > 0) {
            pool.lpToken.safeTransferFrom(address(msg.sender), address(this), _amount);
            if(pool.depositFeeBP > 0){
                uint256 depositFee = _amount.mul(pool.depositFeeBP).div(10000);
                pool.lpToken.safeTransfer(vaultAddress, depositFee.mul(vaultDepositPercent).div(10000));
                pool.lpToken.safeTransfer(devAddress, depositFee.mul(devDepositPercent).div(10000));
                pool.lpToken.safeTransfer(charityAddress, depositFee.mul(charityDepositPercent).div(10000));
                user.amount = user.amount.add(_amount).sub(depositFee);
            }else{
                user.amount = user.amount.add(_amount);
            }
        }
        user.rewardDebt = user.amount.mul(pool.accRunePerShare).div(1e12);
        emit Deposit(msg.sender, _pid, _amount);
    }

    // Withdraw LP tokens from MasterChef.
    function withdraw(uint256 _pid, uint256 _amount) public {
        PoolInfo storage pool = poolInfo[_pid];
        UserInfo storage user = userInfo[_pid][msg.sender];
        require(user.amount >= _amount, "withdraw: not good");
        updatePool(_pid);
        uint256 pending = user.amount.mul(pool.accRunePerShare).div(1e12).sub(user.rewardDebt);
        if(pending > 0) {
            safeRuneTransfer(msg.sender, pending);
        }
        if(_amount > 0) {
            user.amount = user.amount.sub(_amount);
            pool.lpToken.safeTransfer(address(msg.sender), _amount);
        }
        user.rewardDebt = user.amount.mul(pool.accRunePerShare).div(1e12);
        emit Withdraw(msg.sender, _pid, _amount);
    }

    // Withdraw without caring about rewards. EMERGENCY ONLY.
    function emergencyWithdraw(uint256 _pid) public {
        PoolInfo storage pool = poolInfo[_pid];
        UserInfo storage user = userInfo[_pid][msg.sender];
        uint256 amount = user.amount;
        user.amount = 0;
        user.rewardDebt = 0;
        pool.lpToken.safeTransfer(address(msg.sender), amount);
        emit EmergencyWithdraw(msg.sender, _pid, amount);
    }

    // Safe rune transfer function, just in case if rounding error causes pool to not have enough RUNEs.
    function safeRuneTransfer(address _to, uint256 _amount) internal {
        uint256 runeBal = rune.balanceOf(address(this));
        if (_amount > runeBal) {
            rune.transfer(_to, runeBal);
        } else {
            rune.transfer(_to, _amount);
        }
    }

    //Arcane has to add hidden dummy pools inorder to alter the emission, here we make it simple and transparent to all.
    function updateEmissionRate(uint256 _runePerBlock) public onlyOwner {
        massUpdatePools();
        runePerBlock = _runePerBlock;
    }

    function setInfo(address _vaultAddress, address _charityAddress, address _devAddress, uint256 _vaultMintPercent, uint256 _charityMintPercent, uint256 _devMintPercent, uint256 _vaultDepositPercent, uint256 _charityDepositPercent, uint256 _devDepositPercent) external
    {
        require(msg.sender == devAddress, "dev: wut?");
        require (_vaultAddress != address(0) && _charityAddress != address(0) && _devAddress != address(0), "Cannot use zero address");
        require (_vaultMintPercent <= 9500 && _charityMintPercent <= 250 && _devMintPercent <= 250, "Mint percent constraints");
        require (_vaultDepositPercent <= 9500 && _charityDepositPercent <= 250 && _devDepositPercent <= 250, "Mint percent constraints");

        vaultAddress = _vaultAddress;
        charityAddress = _charityAddress;
        devAddress = _devAddress;

        vaultMintPercent = _vaultMintPercent;
        charityMintPercent = _charityMintPercent;
        devMintPercent = _devMintPercent;

        vaultDepositPercent = _vaultDepositPercent;
        charityDepositPercent = _charityDepositPercent;
        devDepositPercent = _devDepositPercent;
    }

    function rune_proxy_setFeeInfo(address _vaultAddress, address _charityAddress, address _devAddress, address _botAddress, uint256 _vaultFee, uint256 _charityFee, uint256 _devFee, uint256 _botFee) external
    {
        require(msg.sender == devAddress, "dev: wut?");
        rune.setFeeInfo(_vaultAddress, _charityAddress, _devAddress, _botAddress, _vaultFee, _charityFee, _devFee, _botFee);
    }

    function rune_proxy_addExcluded(address _account) external {
        require(msg.sender == devAddress, "dev: wut?");
        rune.addExcluded(_account);
    }

    function rune_proxy_removeExcluded(address _account) external {
        require(msg.sender == devAddress, "dev: wut?");
        rune.removeExcluded(_account);
    }

    function throwRuneInTheVoid() external {
        require(msg.sender == devAddress, "dev: wut?");
        massUpdatePools();
        runePerBlock = 0;
        rune.disableMintingForever();
        rune.transferOwnership(voidAddress);
    }
}