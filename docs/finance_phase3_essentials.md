# Finance Phase 3 essentials (adjustment, write-off, export)

## Adjustment (Fund Accounts)

**Where:** Fund Accounts → select account → **Adjustment (fix balance with reason)**

- Increase (+) or decrease (−)
- Amount + **required reason**
- Posts `FundTransactionType.adjustment` with server-side balance math
- Shown in history with tune icon

Use when: cash count ≠ app, opening error, bank fee not logged, etc.  
Do **not** use instead of voiding a wrong expense (use void for that).

## Write-off (Advances)

**Where:** Finance → Advances → open advance → **Write off**

- Closes remaining outstanding as unrecoverable
- **No cash returns** to the fund (already left at issue)
- Status → `writtenOff`, reason stored in notes + audit log

Use when: employee left, float never returned, loss accepted.

## Settle vs write-off

| Action | Money to fund? | Use when |
|--------|----------------|----------|
| Settle | Optional return | They paid back (all or part) |
| Write off | No | You give up on remaining balance |

## Export for accountant

**Expenses:** Expenses tab → **Export CSV** (exports current filtered list)  
**Advances:** Advances tab → **Export CSV**

CSV is for Excel / their software. They do not log into this app.

## Not in this slice (later)

- Full month close UI
- Budgets
- Bank reconciliation
- Chart-of-accounts mapping
