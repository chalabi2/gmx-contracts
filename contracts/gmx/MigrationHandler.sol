//SPDX-License-Identifier: MIT

pragma solidity 0.6.12;

import "../libraries/math/SafeMath.sol";
import "../libraries/token/IERC20.sol";
import "../libraries/utils/ReentrancyGuard.sol";

import "./interfaces/IAmmRouter.sol";
import "./interfaces/ICmxMigrator.sol";
import "../core/interfaces/IVault.sol";

contract MigrationHandler is ReentrancyGuard {
    using SafeMath for uint256;

    uint256 public constant USDG_PRECISION = 10 ** 18;

    bool public isInitialized;

    address public admin;
    address public ammRouterV1;
    address public ammRouterV2;

    address public vault;

    address public cmt;
    address public xcmt;
    address public usdg;
    address public bnb;
    address public busd;

    mapping (address => mapping (address => uint256)) public refundedAmounts;

    modifier onlyAdmin() {
        require(msg.sender == admin, "MigrationHandler: forbidden");
        _;
    }

    constructor() public {
        admin = msg.sender;
    }

    function initialize(
        address _ammRouterV1,
        address _ammRouterV2,
        address _vault,
        address _cmt,
        address _xcmt,
        address _usdg,
        address _bnb,
        address _busd
    ) public onlyAdmin {
        require(!isInitialized, "MigrationHandler: already initialized");
        isInitialized = true;

        ammRouterV1 = _ammRouterV1;
        ammRouterV2 = _ammRouterV2;

        vault = _vault;

        cmt = _cmt;
        xcmt = _xcmt;
        usdg = _usdg;
        bnb = _bnb;
        busd = _busd;
    }

    function redeemUsdg(
        address _migrator,
        address _redemptionToken,
        uint256 _usdgAmount
    ) external onlyAdmin nonReentrant {
        IERC20(usdg).transferFrom(_migrator, vault, _usdgAmount);
        uint256 amount = IVault(vault).sellUSDG(_redemptionToken, address(this));

        address[] memory path = new address[](2);
        path[0] = bnb;
        path[1] = busd;

        if (_redemptionToken != bnb) {
            path = new address[](3);
            path[0] = _redemptionToken;
            path[1] = bnb;
            path[2] = busd;
        }

        IERC20(_redemptionToken).approve(ammRouterV2, amount);
        IAmmRouter(ammRouterV2).swapExactTokensForTokens(
            amount,
            0,
            path,
            _migrator,
            block.timestamp
        );
    }

    function swap(
        address _migrator,
        uint256 _cmtAmountForUsdg,
        uint256 _xcmtAmountForUsdg,
        uint256 _cmtAmountForBusd
    ) external onlyAdmin nonReentrant {
        address[] memory path = new address[](2);

        path[0] = cmt;
        path[1] = usdg;
        IERC20(cmt).transferFrom(_migrator, address(this), _cmtAmountForUsdg);
        IERC20(cmt).approve(ammRouterV2, _cmtAmountForUsdg);
        IAmmRouter(ammRouterV2).swapExactTokensForTokens(
            _cmtAmountForUsdg,
            0,
            path,
            _migrator,
            block.timestamp
        );

        path[0] = xcmt;
        path[1] = usdg;
        IERC20(xcmt).transferFrom(_migrator, address(this), _xcmtAmountForUsdg);
        IERC20(xcmt).approve(ammRouterV2, _xcmtAmountForUsdg);
        IAmmRouter(ammRouterV2).swapExactTokensForTokens(
            _xcmtAmountForUsdg,
            0,
            path,
            _migrator,
            block.timestamp
        );

        path[0] = cmt;
        path[1] = busd;
        IERC20(cmt).transferFrom(_migrator, address(this), _cmtAmountForBusd);
        IERC20(cmt).approve(ammRouterV1, _cmtAmountForBusd);
        IAmmRouter(ammRouterV1).swapExactTokensForTokens(
            _cmtAmountForBusd,
            0,
            path,
            _migrator,
            block.timestamp
        );
    }

    function refund(
        address _migrator,
        address _account,
        address _token,
        uint256 _usdgAmount
    ) external onlyAdmin nonReentrant {
        address iouToken = ICmxMigrator(_migrator).iouTokens(_token);
        uint256 iouBalance = IERC20(iouToken).balanceOf(_account);
        uint256 iouTokenAmount = _usdgAmount.div(2); // each CMX is priced at $2

        uint256 refunded = refundedAmounts[_account][iouToken];
        refundedAmounts[_account][iouToken] = refunded.add(iouTokenAmount);

        require(refundedAmounts[_account][iouToken] <= iouBalance, "MigrationHandler: refundable amount exceeded");

        IERC20(usdg).transferFrom(_migrator, _account, _usdgAmount);
    }
}
