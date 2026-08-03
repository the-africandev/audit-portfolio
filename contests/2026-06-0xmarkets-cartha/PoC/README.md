# PoC — CarthaVault Transient-Oracle DoS

Runnable proof of concept for the finding described in the parent [`README.md`](../README.md).

## Setup

This PoC is a drop-in test for the Cartha vaults repo (`cartha @ 4c51f2a`). Place it at
`cartha-vaults/test/vault/OracleDoSAudit.t.sol` and build the project as usual:

```bash
forge install
forge build
```

The `foundry.toml` here is the minimal reference config; run against the Cartha repo's own
build (it depends on `CarthaVaultFactory`, `CarthaVault`, the Diamond test utils, and the
`I0xMReader` / `I0xMOracle` interfaces).

## Reproduce

```bash
forge test --match-path "test/vault/OracleDoSAudit.t.sol" -vv
# Expected: 2 passing.
```

## What it shows

The test wires the 0xM integration exactly as the deploy docs prescribe, then mints GM to the
vault (a keeper-executed deploy) with the oracle in its normal **cleared** state. It asserts
that `totalValueLocked()` and a fresh `depositAndLock` both revert `EmptyPrimaryPrice` — the
vault is frozen. A control test proves the same state works *only* while prices are set
(mid-keeper-execution), confirming the revert is the cleared-oracle state, not a fixture artifact.

The mock's fidelity is the whole point: `TransientOracleMock.getPrimaryPrice` **reverts** for an
unset price rather than returning `(0,0)`, reproducing the live Oracle at
`0x03F2a8b7D07D937a0568459a0a1299E4d2BECFAA` (which reverts `0xcd64a025` = `EmptyPrimaryPrice`).

## Files

| File | Purpose |
|------|---------|
| `test/OracleDoSAudit.t.sol` | The DoS test + faithful transient-oracle mock |
| `src/` | (empty — PoC runs inside the Cartha repo, not standalone) |
| `foundry.toml` | Reference build config |
