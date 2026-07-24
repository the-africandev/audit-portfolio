<!--
FINDING WRITEUP TEMPLATE
Copy this file to: <category>/<YYYY-MM-DD>-<protocol>/README.md
Fill every section. Delete these HTML comments before committing.
One writeup per finding. If an engagement produced several findings, either give each its
own file (finding-01.md, finding-02.md) or repeat the "Finding" block below per issue.
-->

# [Severity] <Short, specific finding title>

> Example: `[High] Settlement rounds losing shares down, letting the last claimant drain dust from the pool`

| | |
|---|---|
| **Protocol** | <name> |
| **Engagement** | <Code4rena / Sherlock / Cantina / Immunefi / Independent> |
| **Date** | <YYYY-MM-DD> |
| **Severity** | <Critical / High / Medium / Low> (Impact: _ × Likelihood: _) |
| **Status** | <Confirmed / Acknowledged / Fixed / Duplicate / Disputed / Rewarded $X> |
| **Commit / Scope** | `<commit hash>` — `path/to/Contract.sol` |
| **Report link** | <link to official submission, if public> |

---

## Summary

<2–3 sentences, plain English. What is broken and what an attacker gains. A busy lead should
grasp the whole bug from this paragraph alone.>

## Vulnerability Details

<The technical root cause. Walk through the exact code path. Quote the offending lines with
file:line references and fenced code blocks. Explain the *assumption the code makes* and why
it does not hold.>

```solidity
// path/to/Contract.sol:L123
function vulnerable(...) external {
    // annotate the exact line where the invariant breaks
}
```

## Impact

<Concrete consequence. Who loses what, and how much. If funds: quantify (worst case, realistic
case). Tie the severity rating to this — impact × likelihood. Be honest; don't inflate.>

## Proof of Concept

<A runnable Foundry test that demonstrates the exploit. Link to the PoC folder and paste the
key test here. State the exact command to reproduce.>

```bash
forge test --match-test test_Exploit -vvv
```

```solidity
// PoC/test/Exploit.t.sol (excerpt)
function test_Exploit() public {
    // arrange → act → assert the loss/unauthorized state change
}
```

**Result:**
```
<paste the passing exploit output / before-after balances>
```

## Recommended Mitigation

<The fix. Show the corrected code where possible. Note any trade-offs or alternative
approaches. This section is what separates a bug reporter from an auditor.>

```solidity
// suggested fix
```

## References

- <related CVEs, prior findings, EIPs, or docs>
