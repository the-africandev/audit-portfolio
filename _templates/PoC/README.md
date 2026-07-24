# PoC — <Protocol> <Finding Title>

Runnable proof of concept for the finding described in the parent [`README.md`](../README.md).

## Setup

```bash
forge install
forge build
```

## Reproduce

```bash
forge test --match-test test_Exploit -vvv
```

## What it shows

<1–2 sentences: the test sets up <state>, performs <attack>, and asserts <loss / unauthorized
outcome>. A passing test = the exploit works.>

## Files

| File | Purpose |
|------|---------|
| `test/Exploit.t.sol` | The exploit test |
| `src/` | Minimal reproduction of the vulnerable contract(s), or a fork setup |
| `foundry.toml` | Build/fork config |

> If this PoC forks mainnet or a testnet, set `FORK_URL` and note the block number here.
