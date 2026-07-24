# Templates

Reusable scaffolding so every finding lands in the repo with consistent, professional formatting.

## Adding a new finding

1. **Create the engagement folder:**
   ```bash
   mkdir -p contests/2026-05-<protocol>
   cp _templates/finding-writeup-template.md contests/2026-05-<protocol>/README.md
   cp -r _templates/PoC contests/2026-05-<protocol>/PoC   # only if you have a runnable PoC
   ```
2. **Write it up:** fill in `README.md` (root cause → impact → PoC → fix). Delete the guiding comments.
3. **Prove it:** implement `PoC/test/Exploit.t.sol` until `forge test` passes and demonstrates the loss.
4. **Index it:** add a row to the top of the track-record table in the repo root [`README.md`](../README.md), and bump the summary counts.

## Files

| File | Use |
|------|-----|
| `finding-writeup-template.md` | The per-finding report format |
| `PoC/` | Minimal Foundry project skeleton for a runnable exploit |

## Severity — keep it honest

Rate as **Impact × Likelihood**. Match the platform's rubric (Sherlock/C4 define these precisely).
An inflated severity that triage downgrades costs you more credibility than reporting a clean Medium.
