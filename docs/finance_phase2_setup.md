# Finance Phase 2 — Daily control

## What shipped

1. **Petty cash close from ledger** — deposits/expenses for the day come from fund transactions, not typed guesses.
2. **Verify = day lock** — writes `finance_day_locks/{accountId_yyyy-MM-dd}`. Further money posts on that day for that account are blocked.
3. **Live ledger totals** on open session + refresh button.
4. **Transfers UI** — Fund Accounts → Transfer (double-entry, both sides).
5. **Cash advances** — new Finance tab: issue (withdraw) + settle (optional return deposit).
6. **Approval limits & policy** — `finance_settings/policy` (defaults if missing):
   - manager 5,000 / finance 50,000 / admin unlimited
   - receipt required above 100
   - fuel requires vehicle; salary requires employee
   - block self-approve
7. **Real actors** on open/close/verify petty cash (not "Admin").

## Collections

| Collection | Purpose |
|------------|---------|
| `finance_day_locks` | Locked calendar days per fund account |
| `cash_advances` | Floats to staff |
| `finance_settings/policy` | Approval limits & rules |

## Smoke test

1. Open petty cash day → make deposit + approve expense → refresh totals.
2. Close session with counted cash/STC → discrepancy uses ledger expected.
3. Verify → try deposit same day → should fail (day locked).
4. Transfer A → B → both statements update.
5. Issue advance → fund down; settle with return → fund up.
6. Approve amount above role limit → rejected.

## Deploy

```bash
firebase deploy --only firestore:rules
```
