// SPDX-License-Identifier: MIT

pragma solidity 0.6.12;

import "../access/Governable.sol";
import "../peripherals/interfaces/ITimelock.sol";

contract RewardManager is Governable {

    bool public isInitialized;

    ITimelock public timelock;
    address public rewardRouter;

    address public clpManager;

    address public stakedCmxTracker;
    address public bonusCmxTracker;
    address public feeCmxTracker;

    address public feeClpTracker;
    address public stakedClpTracker;

    address public stakedCmxDistributor;
    address public stakedClpDistributor;

    address public esCmx;
    address public bnCmx;

    address public cmxVester;
    address public clpVester;

    function initialize(
        ITimelock _timelock,
        address _rewardRouter,
        address _clpManager,
        address _stakedCmxTracker,
        address _bonusCmxTracker,
        address _feeCmxTracker,
        address _feeClpTracker,
        address _stakedClpTracker,
        address _stakedCmxDistributor,
        address _stakedClpDistributor,
        address _esCmx,
        address _bnCmx,
        address _cmxVester,
        address _clpVester
    ) external onlyGov {
        require(!isInitialized, "RewardManager: already initialized");
        isInitialized = true;

        timelock = _timelock;
        rewardRouter = _rewardRouter;

        clpManager = _clpManager;

        stakedCmxTracker = _stakedCmxTracker;
        bonusCmxTracker = _bonusCmxTracker;
        feeCmxTracker = _feeCmxTracker;

        feeClpTracker = _feeClpTracker;
        stakedClpTracker = _stakedClpTracker;

        stakedCmxDistributor = _stakedCmxDistributor;
        stakedClpDistributor = _stakedClpDistributor;

        esCmx = _esCmx;
        bnCmx = _bnCmx;

        cmxVester = _cmxVester;
        clpVester = _clpVester;
    }

    function updateEsCmxHandlers() external onlyGov {
        timelock.managedSetHandler(esCmx, rewardRouter, true);

        timelock.managedSetHandler(esCmx, stakedCmxDistributor, true);
        timelock.managedSetHandler(esCmx, stakedClpDistributor, true);

        timelock.managedSetHandler(esCmx, stakedCmxTracker, true);
        timelock.managedSetHandler(esCmx, stakedClpTracker, true);

        timelock.managedSetHandler(esCmx, cmxVester, true);
        timelock.managedSetHandler(esCmx, clpVester, true);
    }

    function enableRewardRouter() external onlyGov {
        timelock.managedSetHandler(clpManager, rewardRouter, true);

        timelock.managedSetHandler(stakedCmxTracker, rewardRouter, true);
        timelock.managedSetHandler(bonusCmxTracker, rewardRouter, true);
        timelock.managedSetHandler(feeCmxTracker, rewardRouter, true);

        timelock.managedSetHandler(feeClpTracker, rewardRouter, true);
        timelock.managedSetHandler(stakedClpTracker, rewardRouter, true);

        timelock.managedSetHandler(esCmx, rewardRouter, true);

        timelock.managedSetMinter(bnCmx, rewardRouter, true);

        timelock.managedSetMinter(esCmx, cmxVester, true);
        timelock.managedSetMinter(esCmx, clpVester, true);

        timelock.managedSetHandler(cmxVester, rewardRouter, true);
        timelock.managedSetHandler(clpVester, rewardRouter, true);

        timelock.managedSetHandler(feecmxTracker, cmxVester, true);
        timelock.managedSetHandler(stakedClpTracker, clpVester, true);
    }
}
