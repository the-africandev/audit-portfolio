// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test, console} from "forge-std/Test.sol";
import {ERC1967Proxy} from "openzeppelin-contracts/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import {UpgradeableBeacon} from "openzeppelin-contracts/contracts/proxy/beacon/UpgradeableBeacon.sol";
import {IERC20} from "openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import {CarthaVaultFactory} from "../../src/CarthaVaultFactory.sol";
import {CarthaVault} from "../../src/CarthaVault.sol";
import {Diamond} from "../../src/diamond/Diamond.sol";
import {MockERC20} from "../mocks/MockERC20.sol";
import {DiamondTestUtils} from "../utils/DiamondTestUtils.sol";
import {ICarthaVaultFactory} from "../../src/interfaces/ICarthaVaultFactory.sol";
import {ICarthaVault} from "../../src/interfaces/ICarthaVault.sol";
import {ICarthaAccessControl} from "../../src/interfaces/ICarthaAccessControl.sol";
import {I0xMReader} from "../../src/interfaces/I0xMReader.sol";
import {I0xMOracle} from "../../src/interfaces/I0xMOracle.sol";
import {Roles} from "../../src/diamond/Roles.sol";

/// @notice F-ORACLE-DOS — CarthaVault is frozen (DoS) once it holds deployed GM, because
///         PoolDeployLib._getGmPrice reads the 0xMarkets Oracle.getPrimaryPrice with no try/catch.
///
///   Place at: cartha-vaults/test/vault/OracleDoSAudit.t.sol   (repo @ 4c51f2a, current main HEAD)
///   Run:      forge test --match-path "test/vault/OracleDoSAudit.t.sol" -vv
///   Expected: 2 passing.
///
///         The 0xMarkets Oracle is transient: prices are set at the start of a keeper execution and
///         CLEARED at the end (OracleModule.withOraclePrices = setPrices(...) ; _ ; clearAllPrices()).
///         So in any normal (non-keeper) tx getPrimaryPrice reverts EmptyPrimaryPrice. Confirmed
///         on-chain: live Oracle 0x03F2a8b7D07D937a0568459a0a1299E4d2BECFAA reverts 0xcd64a025
///         (= EmptyPrimaryPrice). This TransientOracleMock reproduces that exactly — it REVERTS for
///         an unset (cleared) price, rather than returning (0,0).
contract TransientOracleMock is I0xMOracle {
    error EmptyPrimaryPrice(address token);

    mapping(address => I0xMReader.PriceProps) private _p;
    mapping(address => bool) private _set;

    // keeper "setPrices" at start of execution
    function setPrice(address token, uint256 min, uint256 max) external {
        _p[token] = I0xMReader.PriceProps(min, max);
        _set[token] = true;
    }

    // keeper "clearAllPrices" at end of execution
    function clear(address token) external {
        delete _p[token];
        _set[token] = false;
    }

    function getPrimaryPrice(address token) external view returns (I0xMReader.PriceProps memory) {
        if (!_set[token]) revert EmptyPrimaryPrice(token); // cleared => revert, exactly like the real Oracle
        return _p[token];
    }
}

contract ReaderMock is I0xMReader {
    MarketProps private _market;
    uint256 public gmSupply;
    uint256 public longAmount;
    uint256 public shortAmount;

    function setMarket(MarketProps memory m) external {
        _market = m;
    }

    function setPool(uint256 _gmSupply, uint256 _longAmount, uint256 _shortAmount) external {
        gmSupply = _gmSupply;
        longAmount = _longAmount;
        shortAmount = _shortAmount;
    }

    function getMarket(address, address) external view returns (MarketProps memory) {
        return _market;
    }

    function getMarketTokenPrice(
        address,
        MarketProps memory,
        PriceProps memory,
        PriceProps memory longP,
        PriceProps memory shortP,
        bytes32,
        bool maximize
    ) external view returns (int256, MarketPoolValueInfoProps memory) {
        uint256 lp = maximize ? longP.max : longP.min;
        uint256 sp = maximize ? shortP.max : shortP.min;
        uint256 poolValue6 = (longAmount * lp + shortAmount * sp) / 1e6;
        MarketPoolValueInfoProps memory info;
        if (gmSupply == 0) return (0, info);
        return (int256((poolValue6 * 1e30) / gmSupply), info);
    }
}

contract OracleDoSAuditTest is Test {
    CarthaVaultFactory factory;
    ICarthaVault gold;
    MockERC20 usdc;
    MockERC20 gmGold;
    ReaderMock reader;
    TransientOracleMock oracle;
    Diamond diamond;
    ICarthaAccessControl accessControl;

    address admin = address(0x1);
    address keeperBot = address(0x2);
    address lpHonest = address(0xA);

    bytes32 poolIdGold = keccak256("XAU/USD");
    address constant INDEX = address(0x222);
    uint256 constant U = 1e6;

    function setUp() public {
        vm.startPrank(admin);
        (diamond, accessControl) = DiamondTestUtils.deployDiamond(admin);
        accessControl.grantRole(Roles.FACTORY, admin);
        accessControl.grantRole(Roles.KEEPER_BOT, keeperBot);
        accessControl.grantRole(Roles.ADMIN, admin);

        CarthaVault childImpl = new CarthaVault();
        UpgradeableBeacon childBeacon = new UpgradeableBeacon(address(childImpl), admin);
        CarthaVault parentImplPlaceholder = new CarthaVault();
        UpgradeableBeacon parentBeacon = new UpgradeableBeacon(address(parentImplPlaceholder), admin);
        CarthaVaultFactory factoryImpl = new CarthaVaultFactory();
        ERC1967Proxy factoryProxy = new ERC1967Proxy(
            address(factoryImpl),
            abi.encodeWithSelector(
                CarthaVaultFactory.initialize.selector, address(childBeacon), address(parentBeacon), address(diamond)
            )
        );
        factory = CarthaVaultFactory(address(factoryProxy));

        usdc = new MockERC20("USD Coin", "USDC", 6);
        gmGold = new MockERC20("GM Gold", "GMG", 18);
        reader = new ReaderMock();
        oracle = new TransientOracleMock();

        gold = ICarthaVault(
            factory.deployVault(
                ICarthaVaultFactory.VaultConfig({asset: address(usdc), poolId: poolIdGold, name: "g", symbol: "g"})
            )
        );
        CarthaVault(address(gold)).setMinimumLockAmount(1);
        CarthaVault(address(gold)).setMaxLockDays(365);

        // Wire the 0xM integration exactly as the README's deploy step 10 prescribes.
        CarthaVault(address(gold)).setPoolToken(address(gmGold));
        CarthaVault(address(gold)).setMarketToken(address(gmGold));
        CarthaVault(address(gold)).setReader(address(reader));
        CarthaVault(address(gold)).setOracle(address(oracle));
        CarthaVault(address(gold)).setDataStore(address(0xDDDD));
        vm.stopPrank();

        reader.setMarket(I0xMReader.MarketProps(address(gmGold), INDEX, address(usdc), address(usdc)));
        // NOTE: oracle is deliberately left CLEARED (no setPrice) — the normal between-execution state.
    }

    function _deposit(address who, uint256 amount) internal returns (uint256) {
        usdc.mint(who, amount);
        vm.startPrank(who);
        usdc.approve(address(gold), amount);
        gold.depositAndLock(poolIdGold, amount, 1);
        vm.stopPrank();
        return CarthaVault(address(gold)).balanceOf(who);
    }

    // ========================================================================
    // CORE: once GM is deployed and the oracle is in its normal (cleared) state,
    // TVL reads and user deposits REVERT EmptyPrimaryPrice → vault frozen.
    // ========================================================================
    function test_DOS_tvl_and_deposit_revert_when_GM_deployed_and_oracle_cleared() public {
        // Control: BEFORE any GM is deployed, gmBalance==0 so gmValueInUsdc short-circuits
        // to 0 (no oracle read) → a deposit works even with the oracle cleared.
        uint256 shares0 = _deposit(lpHonest, 100_000 * U);
        assertGt(shares0, 0, "control: deposit works pre-deploy (gmBalance==0)");
        assertEq(gold.totalValueLocked(), 100_000 * U, "control: TVL = idle USDC");

        // Simulate a keeper-EXECUTED deploy: GM tokens are now minted to the vault.
        // (deployToPool -> 0xM keeper executeDeposit -> GM minted to receiver==vault.)
        gmGold.mint(address(gold), 50_000e18);
        reader.setPool(50_000e18, 50_000 * U, 50_000 * U);

        // The oracle is in its normal cleared state (keeper's withOraclePrices already
        // ran clearAllPrices). Now every TVL-pricing path reverts.
        vm.expectRevert(abi.encodeWithSelector(TransientOracleMock.EmptyPrimaryPrice.selector, INDEX));
        gold.totalValueLocked();

        // A new unprivileged deposit (FRESH depositor, no existing position) reverts:
        // depositAndLock -> _convertToShares -> _totalValueLocked -> _getGmPrice -> getPrimaryPrice.
        address lp2 = address(0xB);
        usdc.mint(lp2, 50_000 * U);
        vm.startPrank(lp2);
        usdc.approve(address(gold), 50_000 * U);
        vm.expectRevert(abi.encodeWithSelector(TransientOracleMock.EmptyPrimaryPrice.selector, INDEX));
        gold.depositAndLock(poolIdGold, 50_000 * U, 1);
        vm.stopPrank();

        console.log("DoS confirmed: with GM deployed + oracle cleared, TVL & deposit revert EmptyPrimaryPrice");
    }

    // ========================================================================
    // CONTROL: the SAME deployed state works IFF prices happen to be set
    // (i.e. only inside a keeper execution) — proving the revert above is
    // specifically the cleared-oracle state, not a broken fixture.
    // ========================================================================
    function test_DOS_control_works_only_when_prices_set() public {
        _deposit(lpHonest, 100_000 * U);
        gmGold.mint(address(gold), 50_000e18);
        // pool worth 50k USDC (25k long + 25k short) backing the 50k GM supply => GM worth 50k.
        reader.setPool(50_000e18, 25_000 * U, 25_000 * U);

        // Set prices (as a keeper does at the start of an execution).
        oracle.setPrice(address(usdc), U, U); // long == short == USDC
        oracle.setPrice(INDEX, U, U);

        uint256 tvl = gold.totalValueLocked();
        assertEq(tvl, 150_000 * U, "with prices set, TVL = 100k idle + 50k GM");

        // Now clear them (keeper's clearAllPrices at end of execution) → reverts again.
        oracle.clear(address(usdc));
        oracle.clear(INDEX);
        vm.expectRevert(abi.encodeWithSelector(TransientOracleMock.EmptyPrimaryPrice.selector, INDEX));
        gold.totalValueLocked();

        console.log("Confirmed: TVL works only while prices are set (mid-keeper-exec); reverts once cleared");
    }
}
