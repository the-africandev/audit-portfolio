# Security Audit Reports & Findings

Smart contract security research by **[@the-africandev](https://github.com/the-africandev)**.
This repository is a running record of my audit contest findings, bug bounty submissions, and independent security research.

> Focus: Solidity / EVM smart contract security — DeFi, prediction markets, and protocol logic.

---

## 📊 Track Record

| Date | Protocol | Platform | Severity | Status | Report |
|------|----------|----------|----------|--------|--------|
| _2026-04_ | PasswordStore | Practice (Cyfrin) | High · Med | — | [PDF](practice/2026-04-25-password-store-report.pdf) |
| | | | | | |

<!--
Add newest findings at the TOP. Suggested Status values:
Confirmed · Acknowledged · Fixed · Duplicate · Disputed · Rewarded ($X)
Keep severities honest — inflated severities are the fastest way to lose credibility.
-->

**Summary:** _X findings across Y engagements — A High/Critical, B Medium._
_(Update these counts as the table grows — recruiters read this line first.)_

---

## 🔗 Profiles

- **Code4rena:** _add link_
- **Sherlock:** _add link_
- **Cantina:** _add link_
- **CodeHawks:** _add link_
- **Immunefi / HackenProof:** _add link_
- **X / Twitter:** _add link_

---

## 📁 Repository Structure

| Folder | Contents |
|--------|----------|
| [`contests/`](contests/) | Findings from competitive audits (Code4rena, Sherlock, Cantina, CodeHawks) |
| [`bug-bounties/`](bug-bounties/) | Bug bounty submissions (Immunefi, HackenProof) — redacted per program rules |
| [`independent/`](independent/) | Self-directed deep-dives on live or public protocols |
| [`practice/`](practice/) | Training exercises and first-flights (learning, not production findings) |
| [`_templates/`](_templates/) | Reusable finding-writeup + Foundry PoC templates |

Each engagement lives in its own dated folder — e.g. `contests/2026-05-<protocol>/` — containing a `README.md` writeup and, where applicable, a runnable `PoC/`.

---

## ✍️ About

I'm a smart contract security researcher specializing in EVM/Solidity. I hunt for logic
errors, access-control gaps, economic/oracle manipulation, and the business-logic bugs that
pattern-matching tools miss. Every finding here includes a root-cause writeup and, where the
target allows, a runnable proof of concept.

**Available for:** private audits · audit-firm roles · bug bounty collaborations.
**Contact:** _add email / X DM_

---

_Disclosure note: bug bounty findings are published only after remediation and in accordance
with each program's disclosure policy. Nothing here is disclosed in violation of an active embargo._
