# [High] CarthaVault deposits & withdrawals freeze once the vault holds deployed GM — `_getGmPrice` reads a transient oracle with no error handling

| | |
|---|---|
| **Protocol** | 0xMarkets / Cartha Vaults — a yield vault that deploys LP capital into a GMX-v2-style perp DEX |
| **Engagement** | HackenProof (audit contest) |
| **Date** | 2026-06-08 |
| **Severity** | High (Impact: High · Likelihood: High) |
| **Status** | Confirmed by the 0xMarkets team (2026-06-22) |
| **Commit / Scope** | `cartha @ 4c51f2a` — `CarthaVault.sol`, `PoolDeployLib.sol`, `Oracle.sol` |
| **Report link** | HackenProof submission (private per program rules) |

---

## Summary

`CarthaVault` prices its LP shares off total value locked (TVL), and TVL includes the value of the GM (0xMarkets market) tokens the vault has deployed into the perp DEX. That GM value is read from `0xMarkets Oracle.getPrimaryPrice` — via `PoolDeployLib._getGmPrice` — **with no error handling.**

The 0xMarkets `Oracle` is *transient* (standard GMX-v2 design): a keeper sets prices at the start of an execution and clears them at the end, so in any ordinary user transaction `getPrimaryPrice` reverts `EmptyPrimaryPrice`. As soon as the vault holds any deployed GM (`gmBalance > 0` — its normal steady state), every user-facing operation that touches TVL reverts: `depositAndLock`, `release`, `requestRelease`, and `totalValueLocked()`. New LPs cannot deposit and, more seriously, **existing LPs cannot withdraw — their funds are frozen.**

## Vulnerability Details

The GM price is read on the share-price path with no `try/catch` and no fallback:

```solidity
// PoolDeployLib._getGmPrice — reads the transient oracle, NO error handling
I0xMReader.PriceProps memory indexPrice = o.getPrimaryPrice(mkt.indexToken);   // reverts outside a keeper exec
I0xMReader.PriceProps memory longPrice  = o.getPrimaryPrice(mkt.longToken);
I0xMReader.PriceProps memory shortPrice = o.getPrimaryPrice(mkt.shortToken);
(gmPrice,) = r.getMarketTokenPrice(dataStore, mkt, indexPrice, longPrice, shortPrice, MAX_PNL_FACTOR_FOR_DEPOSITS, false);
```

The only guard short-circuits when there is *no* GM balance or *no* reader — so it protects the vault only while nothing is deployed. The instant liquidity is deployed, execution takes the reverting branch:

```solidity
// PoolDeployLib.gmValueInUsdc
uint256 gmBalance = poolToken != address(0) ? IERC20(poolToken).balanceOf(address(this)) : 0;
if (gmBalance == 0 || reader == address(0)) return 0;   // safe ONLY while nothing is deployed
int256 gmPrice = _getGmPrice(...);                       // else -> reverts
```

TVL — which every share operation depends on — includes that value:

```solidity
// CarthaVault._totalValueLocked  ->  _convertToShares / _convertToAssets
//   -> depositAndLock / release / requestRelease
return IERC20($.asset).balanceOf(address(this)) + _gmValueInUsdc($);
```

On the oracle side, the revert is by design. `primaryPrices` are set (`onlyController`) and wiped by `clearAllPrices()`; the `withOraclePrices` modifier used by every keeper execution is literally `setPrices(...) ; _ ; clearAllPrices()`:

```solidity
// 0xMarkets Oracle.getPrimaryPrice
function getPrimaryPrice(address token) external view returns (Price.Props memory) {
    Price.Props memory price = primaryPrices[token];
    if (price.isEmpty()) { revert Errors.EmptyPrimaryPrice(token); }   // empty between keeper executions
    return price;
}
```

**The assumption the code makes** is that `getPrimaryPrice` returns a usable value whenever the vault reads it. That holds only *inside* a keeper execution. A standalone `depositAndLock` / `release` is never inside one — so the assumption never holds in user context.

**Full unprivileged call chain:**

```
depositAndLock (whenNotPaused)
  └─ _convertToShares
       └─ _totalValueLocked
            └─ _gmValueInUsdc
                 └─ _getGmPrice
                      └─ Oracle.getPrimaryPrice  ⇒ revert EmptyPrimaryPrice

release / requestRelease (whenNotPaused)
  └─ _convertToAssets  ───────────────────────────┘  (same tail)
```

The trigger is fully unprivileged, and no privileged party can route around it — the keeper *clearing* prices is precisely the cause.

### On-chain confirmation

The live 0xMarkets `Oracle` at `0x03F2a8b7D07D937a0568459a0a1299E4d2BECFAA` reverts on a plain `eth_call`, confirming prices exist only inside a keeper execution (not a testnet artifact):

```bash
cast call 0x03F2a8b7D07D937a0568459a0a1299E4d2BECFAA \
  "getPrimaryPrice(address)((uint256,uint256))" \
  0x0000000000000000000000000000000000000001 --rpc-url <base-sepolia>
# -> reverts 0xcd64a025…   ==  EmptyPrimaryPrice(address)
```

This step was decisive: the project's own fixtures mocked a *persistent* oracle that always returned a price, which hides the bug entirely. Confirming the real oracle's behavior on-chain and building a faithful mock is what surfaced it.

## Impact

Once a child vault has deployed liquidity into a 0xMarkets market — its normal, yield-earning operating state — `_gmValueInUsdc` takes the reverting branch, so:

- **`depositAndLock`** reverts → no new LP deposits.
- **`release` / `requestRelease`** revert → **existing LPs cannot withdraw; funds frozen.**
- **`totalValueLocked()`** and every share-price read revert → keepers and integrators depending on it break.

The trigger (`gmBalance > 0`) is the protocol's *intended* steady state, not an edge case: the vault cannot simultaneously be deployed (its entire purpose) and remain open to user entry/exit.

**Severity — High, not Critical.** The freeze is keeper-recoverable: a keeper can `recallFromPool` all GM so `gmBalance == 0`, after which `_gmValueInUsdc` short-circuits to `0` and user functions work again. But that requires keeper action and forces the vault out of its deployed, yield-earning state. This is *temporary freezing of funds* + "unable to operate in the intended state" → **High**, rather than permanent loss.

## Proof of Concept

Runnable Foundry test — [`PoC/test/OracleDoSAudit.t.sol`](PoC/test/OracleDoSAudit.t.sol) (drop into `cartha-vaults/test/vault/` at commit `4c51f2a`). It uses a `TransientOracleMock` that reverts `EmptyPrimaryPrice` when prices are cleared — matching the real oracle's between-execution state.

```bash
forge test --match-path "test/vault/OracleDoSAudit.t.sol" -vv
# Expected: 2 passing.
```

```solidity
// PoC/test/OracleDoSAudit.t.sol (excerpt)
function test_DOS_tvl_and_deposit_revert_when_GM_deployed_and_oracle_cleared() public {
    // Control: BEFORE deploy, gmBalance==0 → gmValueInUsdc short-circuits, deposit works.
    uint256 shares0 = _deposit(lpHonest, 100_000 * U);
    assertGt(shares0, 0, "control: deposit works pre-deploy (gmBalance==0)");
    assertEq(gold.totalValueLocked(), 100_000 * U, "control: TVL = idle USDC");

    // Keeper-executed deploy: GM tokens are now minted to the vault.
    gmGold.mint(address(gold), 50_000e18);
    reader.setPool(50_000e18, 50_000 * U, 50_000 * U);

    // Oracle is in its normal cleared state → every TVL-pricing path reverts.
    vm.expectRevert(abi.encodeWithSelector(TransientOracleMock.EmptyPrimaryPrice.selector, INDEX));
    gold.totalValueLocked();

    // A fresh, unprivileged deposit reverts on the same path:
    address lp2 = address(0xB);
    usdc.mint(lp2, 50_000 * U);
    vm.startPrank(lp2);
    usdc.approve(address(gold), 50_000 * U);
    vm.expectRevert(abi.encodeWithSelector(TransientOracleMock.EmptyPrimaryPrice.selector, INDEX));
    gold.depositAndLock(poolIdGold, 50_000 * U, 1);   // -> _convertToShares -> _totalValueLocked -> getPrimaryPrice
    vm.stopPrank();
}
```

A second test, `test_DOS_control_works_only_when_prices_set`, proves the same deployed state computes `TVL = 150k` **only while prices are set** (mid-keeper-execution) and reverts again once cleared — confirming the revert is specifically the cleared-oracle state, not a broken fixture.

**Result:**
```
[PASS] test_DOS_tvl_and_deposit_revert_when_GM_deployed_and_oracle_cleared()
  DoS confirmed: with GM deployed + oracle cleared, TVL & deposit revert EmptyPrimaryPrice
[PASS] test_DOS_control_works_only_when_prices_set()
  Confirmed: TVL works only while prices are set (mid-keeper-exec); reverts once cleared
Suite result: ok. 2 passed; 0 failed
```

## Recommended Mitigation

- Do **not** read GM prices from the transient `Oracle.getPrimaryPrice` on user-facing or view paths. Source index / long / short prices from a **persistent** feed and pass them to `Reader.getMarketTokenPrice`, or use a persistent GM-price view.
- 0xMarkets' own documentation prescribes exactly this: under *Upgrades*, it reminds integrators to price market tokens off **"Chainlink price feeds for market tokens,"** not the transient reader/oracle path Cartha uses.
- At minimum, wrap `_getGmPrice` in `try/catch` with explicit, safe failure behavior — never price shares off a source that can revert with no fallback.

```solidity
// Sketch: persistent-feed pricing instead of the transient oracle
(gmPrice,) = reader.getMarketTokenPrice(
    dataStore, mkt,
    _chainlinkPrice(mkt.indexToken),   // persistent feed, callable in any user tx
    _chainlinkPrice(mkt.longToken),
    _chainlinkPrice(mkt.shortToken),
    MAX_PNL_FACTOR_FOR_DEPOSITS, false
);
```

## References

- GMX-v2 oracle design — prices set/cleared around keeper execution (`withOraclePrices` modifier).
- 0xMarkets docs, *Upgrades* — prescribes Chainlink price feeds for market-token pricing.
- Generalizable class: an unwrapped external read on a share-price / TVL path is a DoS candidate — the dependency must be modelled by its real runtime behavior (transient vs persistent), not by a convenient mock.
