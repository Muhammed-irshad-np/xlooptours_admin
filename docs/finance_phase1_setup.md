# Finance Phase 1 — Setup notes

## Whitelist document shape (`allowed_users/{email}`)

```json
{
  "email": "user@company.com",
  "isAdmin": false,
  "isActive": true,
  "role": "finance"
}
```

### Roles

| role | Meaning |
|------|---------|
| `driver` | Submit own expenses |
| `coordinator` | Petty cash, limited money posts |
| `manager` | Approve expenses |
| `finance` | Pay, reverse, manage funds |
| `admin` | Full access (also `isAdmin: true`) |
| `viewer` | Read-only finance views |

### Legacy

Old docs with only `isAdmin: true` map to **admin**.  
Docs with no role and `isAdmin: false` map to **viewer**.

## What Phase 1 delivered

1. RBAC roles on login (Google + whitelist)
2. Firestore transactions for balances (no client `balanceAfter`)
3. Approve expense → posts withdrawal to fund (wallet integrity)
4. Void paid expense → reverse ledger line (no hard delete of posted money)
5. Unique expense numbers via `counters/expense_reference`
6. Audit log collection `finance_audit_log`
7. Soft-deactivate fund accounts with history
8. Tighter Firestore rules (auth + roles)

## Manual checklist after deploy

1. Deploy `firestore.rules`
2. Set `role` on each `allowed_users` doc
3. Create composite indexes if Firestore console prompts (expenses/date, fund_transactions)
4. Smoke test: deposit → approve expense → balance down → void → balance restored
