// SPDX-License-Identifier: MIT

pragma solidity 0.6.12;

import "../libraries/math/SafeMath.sol";
import "../libraries/token/IERC20.sol";
import "../libraries/token/SafeERC20.sol";
import "../libraries/utils/ReentrancyGuard.sol";
import "../libraries/utils/Address.sol";

import "./interfaces/IRewardTracker.sol";
import "../tokens/interfaces/IMintable.sol";
import "../tokens/interfaces/IWETH.sol";
import "../core/interfaces/IClpManager.sol";
import "../access/Governable.sol";

contract RewardRouter is ReentrancyGuard, Governable {
    using SafeMath for uint256;
    using SafeERC20 for IERC20;
    using Address for address payable;

    bool public isInitialized;

    address public weth;

    address public cmx;
    address public esCmx;
    address public bnCmx;

    address public clp; // CMX Liquidity Provider token

    address public stakedCmxTracker;
    address public bonusCmxTracker;
    address public feeCmxTracker;

    address public stakedClpTracker;
    address public feeClpTracker;

    address public clpManager;

    event StakeCmx(address account, uint256 amount);
    event UnstakeCmx(address account, uint256 amount);

    event StakeClp(address account, uint256 amount);
    event UnstakeClp(address account, uint256 amount);

    receive() external payable {
        require(msg.sender == weth, "Router: invalid sender");
    }

    function initialize(
        address _weth,
        address _cmx,
        address _esCmx,
        address _bnCmx,
        address _clp,
        address _stakedCmxTracker,
        address _bonusCmxTracker,
        address _feeCmxTracker,
        address _feeClpTracker,
        address _stakedClpTracker,
        address _clpManager
    ) external onlyGov {
        require(!isInitialized, "RewardRouter: already initialized");
        isInitialized = true;

        weth = _weth;

        cmx = _cmx;
        esCmx = _esCmx;
        bnCmx = _bnCmx;

        clp = _clp;

        stakedCmxTracker = _stakedCmxTracker;
        bonusCmxTracker = _bonusCmxTracker;
        feeCmxTracker = _feeCmxTracker;

        feeClpTracker = _feeClpTracker;
        stakedClpTracker = _stakedClpTracker;

        clpManager = _clpManager;
    }

    // to help users who accidentally send their tokens to this contract
    function withdrawToken(address _token, address _account, uint256 _amount) external onlyGov {
        IERC20(_token).safeTransfer(_account, _amount);
    }

    function batchStakeCmxForAccount(address[] memory _accounts, uint256[] memory _amounts) external nonReentrant onlyGov {
        address _cmx = cmx;
        for (uint256 i = 0; i < _accounts.length; i++) {
            _stakeCmx(msg.sender, _accounts[i], _cmx, _amounts[i]);
        }
    }

    function stakeCmxForAccount(address _account, uint256 _amount) external nonReentrant onlyGov {
        _stakeCmx(msg.sender, _account, cmx, _amount);
    }

    function stakeCmx(uint256 _amount) external nonReentrant {
        _stakeCmx(msg.sender, msg.sender, cmx, _amount);
    }

    function stakeEsCmx(uint256 _amount) external nonReentrant {
        _stakeCmx(msg.sender, msg.sender, esCmx, _amount);
    }

    function unstakeCmx(uint256 _amount) external nonReentrant {
        _unstakeCmx(msg.sender, cmx, _amount);
    }

    function unstakeEsCmx(uint256 _amount) external nonReentrant {
        _unstakeCmx(msg.sender, esCmx, _amount);
    }

    function mintAndStakeClp(address _token, uint256 _amount, uint256 _minUsdg, uint256 _minClp) external nonReentrant returns (uint256) {
        require(_amount > 0, "RewardRouter: invalid _amount");

        address account = msg.sender;
        uint256 clpAmount = IClpManager(clpManager).addLiquidityForAccount(account, account, _token, _amount, _minUsdg, _minClp);
        IRewardTracker(feeClpTracker).stakeForAccount(account, account, clp, clpAmount);
        IRewardTracker(stakedClpTracker).stakeForAccount(account, account, feeClpTracker, clpAmount);

        emit StakeClp(account, clpAmount);

        return clpAmount;
    }

    function mintAndStakeClpETH(uint256 _minUsdg, uint256 _minClp) external payable nonReentrant returns (uint256) {
        require(msg.value > 0, "RewardRouter: invalid msg.value");

        IWETH(weth).deposit{value: msg.value}();
        IERC20(weth).approve(clpManager, msg.value);

        address account = msg.sender;
        uint256 clpAmount = IClpManager(clpManager).addLiquidityForAccount(address(this), account, weth, msg.value, _minUsdg, _minClp);

        IRewardTracker(feeClpTracker).stakeForAccount(account, account, clp, clpAmount);
        IRewardTracker(stakedClpTracker).stakeForAccount(account, account, feeClpTracker, clpAmount);

        emit StakeClp(account, clpAmount);

        return clpAmount;
    }

    function unstakeAndRedeemClp(address _tokenOut, uint256 _clpAmount, uint256 _minOut, address _receiver) external nonReentrant returns (uint256) {
        require(_clpAmount > 0, "RewardRouter: invalid _clpAmount");

        address account = msg.sender;
        IRewardTracker(stakedClpTracker).unstakeForAccount(account, feeClpTracker, _clpAmount, account);
        IRewardTracker(feeClpTracker).unstakeForAccount(account, clp, _clpAmount, account);
        uint256 amountOut = IClpManager(clpManager).removeLiquidityForAccount(account, _tokenOut, _clpAmount, _minOut, _receiver);

        emit UnstakeClp(account, _clpAmount);

        return amountOut;
    }

    function unstakeAndRedeemClpETH(uint256 _clpAmount, uint256 _minOut, address payable _receiver) external nonReentrant returns (uint256) {
        require(_clpAmount > 0, "RewardRouter: invalid _clpAmount");

        address account = msg.sender;
        IRewardTracker(stakedClpTracker).unstakeForAccount(account, feeClpTracker, _clpAmount, account);
        IRewardTracker(feeClpTracker).unstakeForAccount(account, clp, _clpAmount, account);
        uint256 amountOut = IClpManager(clpManager).removeLiquidityForAccount(account, weth, _clpAmount, _minOut, address(this));

        IWETH(weth).withdraw(amountOut);

        _receiver.sendValue(amountOut);

        emit UnstakeClp(account, _clpAmount);

        return amountOut;
    }

    function claim() external nonReentrant {
        address account = msg.sender;

        IRewardTracker(feeCmxTracker).claimForAccount(account, account);
        IRewardTracker(feeClpTracker).claimForAccount(account, account);

        IRewardTracker(stakedCmxTracker).claimForAccount(account, account);
        IRewardTracker(stakedClpTracker).claimForAccount(account, account);
    }

    function claimEsCmx() external nonReentrant {
        address account = msg.sender;

        IRewardTracker(stakedCmxTracker).claimForAccount(account, account);
        IRewardTracker(stakedClpTracker).claimForAccount(account, account);
    }

    function claimFees() external nonReentrant {
        address account = msg.sender;

        IRewardTracker(feeCmxTracker).claimForAccount(account, account);
        IRewardTracker(feeClpTracker).claimForAccount(account, account);
    }

    function compound() external nonReentrant {
        _compound(msg.sender);
    }

    function compoundForAccount(address _account) external nonReentrant onlyGov {
        _compound(_account);
    }

    function batchCompoundForAccounts(address[] memory _accounts) external nonReentrant onlyGov {
        for (uint256 i = 0; i < _accounts.length; i++) {
            _compound(_accounts[i]);
        }
    }

    function _compound(address _account) private {
        _compoundCmx(_account);
        _compoundClp(_account);
    }

    function _compoundCmx(address _account) private {
        uint256 esCmxAmount = IRewardTracker(stakedCmxTracker).claimForAccount(_account, _account);
        if (esCmxAmount > 0) {
            _stakeCmx(_account, _account, esCmx, esCmxAmount);
        }

        uint256 bnCmxAmount = IRewardTracker(bonusCmxTracker).claimForAccount(_account, _account);
        if (bnCmxAmount > 0) {
            IRewardTracker(feeCmxTracker).stakeForAccount(_account, _account, bnCmx, bnCmxAmount);
        }
    }

    function _compoundClp(address _account) private {
        uint256 esCmxAmount = IRewardTracker(stakedClpTracker).claimForAccount(_account, _account);
        if (esCmxAmount > 0) {
            _stakeCmx(_account, _account, esCmx, esCmxAmount);
        }
    }

    function _stakeCmx(address _fundingAccount, address _account, address _token, uint256 _amount) private {
        require(_amount > 0, "RewardRouter: invalid _amount");

        IRewardTracker(stakedCmxTracker).stakeForAccount(_fundingAccount, _account, _token, _amount);
        IRewardTracker(bonusCmxTracker).stakeForAccount(_account, _account, stakedCmxTracker, _amount);
        IRewardTracker(feeCmxTracker).stakeForAccount(_account, _account, bonusCmxTracker, _amount);

        emit StakeCmx(_account, _amount);
    }

    function _unstakeCmx(address _account, address _token, uint256 _amount) private {
        require(_amount > 0, "RewardRouter: invalid _amount");

        uint256 balance = IRewardTracker(stakedCmxTracker).stakedAmounts(_account);

        IRewardTracker(feeCmxTracker).unstakeForAccount(_account, bonusCmxTracker, _amount, _account);
        IRewardTracker(bonusCmxTracker).unstakeForAccount(_account, stakedCmxTracker, _amount, _account);
        IRewardTracker(stakedCmxTracker).unstakeForAccount(_account, _token, _amount, _account);

        uint256 bnCmxAmount = IRewardTracker(bonusCmxTracker).claimForAccount(_account, _account);
        if (bnCmxAmount > 0) {
            IRewardTracker(feeCmxTracker).stakeForAccount(_account, _account, bnCmx, bnCmxAmount);
        }

        uint256 stakedBnCmx = IRewardTracker(feeCmxTracker).depositBalances(_account, bnCmx);
        if (stakedBnCmx > 0) {
            uint256 reductionAmount = stakedBnCmx.mul(_amount).div(balance);
            IRewardTracker(feeCmxTracker).unstakeForAccount(_account, bnCmx, reductionAmount, _account);
            IMintable(bnCmx).burn(_account, reductionAmount);
        }

        emit UnstakeCmx(_account, _amount);
    }
}
