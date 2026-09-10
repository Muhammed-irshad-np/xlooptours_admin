# Vehicle Maintenance Work Order — implementation plan

## 1. The problem today

Maintenance is currently a **record**, not a **process**.

`AddMaintenanceRecordDialog` (`lib/widgets/add_maintenance_record_dialog.dart`)
appends a `MaintenanceRecord` to `vehicles/{id}.maintenanceHistory` and mirrors
it into the typed `VehicleMaintenance` slots so
`GetVehicleMaintenanceAlertsUseCase` can reset the interval. That is the whole
flow. Consequences:

- **`cost` goes nowhere.** It is stored on the record and never reaches finance.
  No expense doc, no wallet deduction, no approval, no receipt requirement.
  Money leaves the company invisibly.
- **No accountability chain.** Nothing records who reported the fault, who
  authorised the spend, whether the car is actually at the shop right now.
- **Alerts nag forever.** An overdue alert keeps firing until someone closes it
  with a record, even when the car has been at the workshop for three days.
- **Retro-entry only.** The dialog is designed to log work *already done*.
  There is no representation of work that is *planned* or *in progress*.

The finance module is already strong (configurable `FinancePolicyEntity`,
`WorkflowPermissionConfig` per action, transactional `approveAndPostExpense`,
petty-cash sessions, day locks, cash advances). The work order does **not**
need to reinvent any of that — it needs to *feed* it.

## 2. Shape of the solution

One new feature module, following `rules.md`:

```
lib/features/maintenance/
  data/
    datasources/work_order_remote_data_source.dart
    models/work_order_model.dart
    repositories/work_order_repository_impl.dart
  domain/
    entities/work_order_entity.dart
    entities/work_order_line.dart
    entities/work_order_event.dart
    repositories/work_order_repository.dart
    services/work_order_transition_service.dart   # legal-next-action rules
    usecases/…
  presentation/
    pages/work_order_board_page.dart
    pages/work_order_detail_page.dart
    pages/work_order_form_page.dart
    providers/work_order_provider.dart
    widgets/…
```

New Firestore collection: **`work_orders`**.

### 2.1 Lifecycle

```
reported ──▶ pendingApproval ──▶ approved ──▶ inProgress ──▶ completed ──▶ closed
   │              │                                │
   └──▶ rejected  └──▶ rejected                    └──▶ onHold ──▶ inProgress
                                                     cancelled (any pre-completed state)
```

**`reported` is stage 0 of the same document, not a separate collection.**
One physical job = one doc = one timeline. A separate "requests" collection
would double the data model and force a copy step that can silently lose the
original complaint.

### 2.2 Three entry paths, one object

| Path | Who | Entry status | Notes |
|---|---|---|---|
| **A — Reported** | Fleet manager (Shamnad) or driver | `reported` | Minimal: vehicle, complaint, urgency, photos. No cost, no shop. Coordinator picks it up. |
| **B — From an alert** | Coordinator, one tap on an existing maintenance alert | `pendingApproval` (or `approved` if under auto-approve threshold) | Prefills vehicle, maintenance type, current odometer, last shop used. This is the highest-volume path and must be one tap. |
| **C — Ad-hoc** | Coordinator / admin | `pendingApproval` | Scheduled service, accident repair, anything not alert-driven. |

Path B is the one that matters for adoption. The alert already knows the
vehicle, the service type, the odometer and the previous shop — the "Create
Work Order" button should open a form that is already 80% filled.

### 2.3 `WorkOrderEntity`

```dart
// identity
String id;                     // = workOrderNumber, doc id
String workOrderNumber;        // WO-2026-0001, from `counters` (same pattern as
                               // FinanceRemoteDataSourceImpl.generateReferenceNumber)
WorkOrderStatus status;
WorkOrderSource source;        // reported | alert | adhoc
WorkOrderPriority priority;    // low | normal | high | vehicleDown

// subject
String vehicleId;
String vehiclePlate;           // denormalised for list rendering
String? vehicleName;           // "Toyota Land Cruiser 2022"
int? odometerAtRequest;
int? odometerAtService;

// the request
String complaint;              // free text, required on path A
String? reportedBy;            // display name
String? reportedByUserId;
String? reportedByRole;        // 'fleet_manager' etc.
DateTime? reportedAt;
List<String> reportedAttachmentUrls;

// the plan
List<WorkOrderLine> lines;     // see 2.4
String? shopId;
String? shopName;
DateTime? scheduledDate;
String? createdBy; String? createdByUserId; DateTime createdAt;

// approval
double estimatedTotal;         // sum of line estimates, minor units mirrored
int? estimatedTotalMinor;
String? approvedBy; String? approvedByUserId; DateTime? approvedAt;
double? approvedAmount;        // frozen at approval — variance is measured against this
String? rejectionReason;

// execution
DateTime? startedAt; String? startedBy;
DateTime? completedAt; String? completedBy;
double? actualTotal; int? actualTotalMinor;
List<String> invoiceUrls;      // shop invoice / receipt
String? shopInvoiceNumber;

// finance link
String? expenseId;             // set exactly once, on close — idempotency guard
String? fundAccountId;
String? paymentMethod;         // 'cash' | 'stcPay' — matches ExpenseEntity
bool paidFromDriverAdvance;    // see 8.3

// closure
DateTime? closedAt; String? closedBy;
String? cancellationReason;
String? notes;

// audit
List<WorkOrderEvent> timeline; // {at, actor, actorUserId, action, note, fromStatus, toStatus}
```

`WorkOrderEvent` is stored as a nested array (same choice as `lineItems` on
invoices — cheap, always read together, never queried independently).

### 2.4 `WorkOrderLine` — why lines are non-negotiable

```dart
String? maintenanceTypeId;     // FK to maintenance_types; null only for custom
String maintenanceTypeName;    // snapshot
String? customTypeName;
double estimatedCost; double? actualCost;
double? partsCost; double? laborCost;
String? partsReplaced;
String? notes;
bool completed;
// follow-up, mirroring MaintenanceRecord
bool followUpRequired; String? followUpReason;
DateTime? followUpDate; int? followUpKm;
DateTime? targetDueDate; int? notificationDays;
```

One workshop visit routinely covers engine oil **and** air filter **and** brake
pads. On close, each line must become its **own** `MaintenanceRecord` with its
own `serviceType`, or the alert engine will reset the wrong intervals — it
groups history by normalised service-type name
(`GetVehicleMaintenanceAlertsUseCase._normalizeServiceType`). One WO → N
maintenance records → N intervals reset correctly.

Lines store `maintenanceTypeId`, not just the name, so matching is by id and
not by the fragile string normalisation the alert engine has to do today.

## 3. The finance bridge — the point of the whole exercise

### 3.1 On `completed → closed`

Sequenced in `CloseWorkOrderUseCase`:

1. **Guard idempotency.** If `expenseId != null`, abort — the WO is already
   closed and posted. This is the single most likely source of duplicate money
   movement; it must be checked server-read-fresh, not from provider cache.
2. **Guard variance.** If `actualTotal > approvedAmount × (1 + tolerance)`,
   refuse to close and require re-approval (status → `pendingApproval` with a
   `varianceReason`). This is the control that makes the workflow worth having:
   an approved 400 SAR job cannot quietly become 2,400 SAR.
3. **Create the expense** via the existing `InsertExpenseUseCase`:
   - `expenseCategory: 'VEHICLES'`, `expenseType: 'Maintenance'`
   - `vehicleId` / `vehicleName` / `mileageKm` from the WO
   - `amount` = `actualTotal`, `amountMinor` mirrored
   - `receiptUrls` = `invoiceUrls`
   - `description` = shop name + line summary
   - `fundAccountId`, `paymentMethod` from the WO
   - **`workOrderId`** — new nullable field on `ExpenseEntity` / `ExpenseModel`
   - `status`: `pending` normally; `approved` when
     `policy.autoApproveExpenseWithinEstimate` is on and the actual is within
     the approved amount (see 3.2)
4. **Write back maintenance history.** One `MaintenanceRecord` per line,
   appended to `maintenanceHistory` **and** mirrored into the typed
   `VehicleMaintenance` slot, with `workOrderNumber` populated (the field
   already exists on `MaintenanceRecord` — free traceability both directions).
5. **Restore vehicle status.** `vehicle.status` was set to `'under_maintenance'`
   on `inProgress`; return it to its prior value, stored on the WO as
   `vehicleStatusBefore`.
6. **Stamp the WO** — `closedAt`, `closedBy`, `expenseId`, timeline event.

Wallet math is **never** reimplemented. The expense goes through the existing
`approveAndPostExpense`, which already handles day locks, petty-cash session
checks, cash/STC bucket resolution, insufficient-balance errors and the
`fund_transactions` ledger. That is the whole reason to route maintenance
money through `expenses` rather than inventing a parallel path.

### 3.2 Avoiding double approval

A naive build asks a manager to approve twice: once for the work order, once
for the expense it creates. That is the fastest way to get the feature
abandoned. Split the two approvals by meaning:

- **WO approval** authorises the *commitment* — "spend up to ~400 SAR at this
  shop on this car."
- **Expense approval** authorises the *payment* — "release 385 SAR from the
  Riyadh petty cash wallet."

Then collapse the second one when it carries no new information: with
`autoApproveExpenseWithinEstimate = true` (recommended default) and the actual
within the approved amount, the expense is created already `approved` and the
payer only confirms payment. Anything over the approved amount goes back
through approval, where it belongs.

## 4. Permissions — extend the existing policy, add no new system

`FinancePolicyEntity` already stores a `WorkflowPermissionConfig` per action
and already has an editor UI (`finance_workflow_policy_view.dart`). Add:

```dart
WorkflowPermissionConfig workOrderRaise    = ['driver','coordinator','manager','finance','admin','super_admin'];
WorkflowPermissionConfig workOrderIssue    = ['coordinator','manager','finance','admin','super_admin'];
WorkflowPermissionConfig workOrderApproval = ['manager','finance','admin','super_admin'];
WorkflowPermissionConfig workOrderClose    = ['coordinator','finance','admin','super_admin'];

double workOrderAutoApproveBelow       = 300;   // SAR; 0 disables auto-approve
double workOrderVarianceTolerancePct   = 10;
bool   autoApproveExpenseWithinEstimate = true;
bool   requireInvoiceOnComplete         = true;
```

New methods on `FinancePermissionService`: `canRaiseWorkOrder`,
`canIssueWorkOrder`, `canApproveWorkOrder(amount:)`, `canCloseWorkOrder` —
each delegating to `_check` exactly like the expense methods. Admin and
super-admin bypass, as everywhere else.

RBAC: add `AppPermission.manageMaintenance` (`'manage_maintenance'`) so the nav
item can be granted to Shamnad without giving him the whole Vehicles module.
Keep `manageVehicles` as an implicit grant so nothing breaks for existing
users.

Firestore rules for `work_orders`:

```
match /work_orders/{id} {
  allow read:   if isAllowedUser();
  allow create: if isAllowedUser();            // anyone may report
  allow update: if isCoordinatorOrAbove();     // status moves
  allow delete: if isAdmin();
}
```

Indexes: `(status ASC, createdAt DESC)` and `(vehicleId ASC, createdAt DESC)`.

## 5. UX

The design goal: **one screen, and every user sees only their own queue on it.**

### 5.1 Navigation

- **Vehicles → Work Orders** (primary home), with a badge showing the count of
  work orders awaiting *this user's* action.
- Vehicle Detail gets a **Work Orders** section listing that vehicle's WOs.
- Finance gets **nothing new** — maintenance expenses already appear in the
  Expenses tab, now with a "WO-2026-0014" chip linking back.

### 5.2 Work Order Board

Desktop: three lanes — **Needs your action** / **In progress** / **Done**.
Mobile: one scrolling list grouped by the same three headings.

"Needs your action" is computed per user from `WorkOrderTransitionService`:
a coordinator sees `reported` items to issue and `completed` items to close;
a manager sees `pendingApproval`; a driver sees only their own reports. Nobody
has to learn the state machine to use the screen.

Card: plate + vehicle, status pill, line summary ("Engine Oil + Air Filter"),
amount (estimate or actual), shop, age ("3d"), priority flag. Filters: status,
vehicle, shop, date range, "mine only". Search on plate / WO number.

### 5.3 Work Order Detail

- **Header** — plate, vehicle, WO number, status pill, priority.
- **Timeline** — the `WorkOrderEvent` list rendered as a vertical stepper.
  Reported by Shamnad → issued by coordinator → approved by manager → started
  → completed → closed, with names, timestamps and notes. This is the artefact
  that answers "who authorised this?" six months later.
- **Lines table** — estimate vs actual per line, variance highlighted when the
  actual exceeds the estimate.
- **Attachments** — complaint photos and shop invoice, reusing the existing
  receipt-preview widget from the expense flow (already CORS-fixed on web,
  per commit `be27052`).
- **Sticky action bar** — the *one* legal next action for this user as a
  primary button, everything else behind a "⋮" menu. No guessing which of nine
  buttons applies.

### 5.4 Report Issue dialog

Two required fields (vehicle, complaint) + urgency + optional photos. Reachable
from the board FAB, from Vehicle Detail, and — phase 3 — from a public
`/report-issue` link mirroring the existing `/driver-expense` public form, so
drivers never need an app login.

### 5.5 Alert integration (this is what kills alert fatigue)

- Every maintenance alert on the dashboard and on
  `all_vehicles_maintenance_history_screen.dart` gets **Create Work Order**
  alongside the existing Extend / Mark Completed.
- When an open WO already exists for that `vehicleId` + `maintenanceTypeId`,
  the alert stops nagging and instead shows **"WO-2026-0014 · In progress"**,
  tappable straight to the detail page.
- Closing a WO resets the interval through the history write-back, so the
  alert clears itself — no separate "mark completed" step.

### 5.6 Notifications

Add `NotificationType.workOrder`. Notify: on raise → coordinators; on submit →
approvers; on approve/reject → raiser + coordinator; on complete → whoever can
close; on close → finance.

## 6. Refactors this requires

Called out honestly, because skipping them forks the logic:

1. **Extract `MaintenanceHistoryWriter`** into
   `lib/features/vehicle/domain/services/`. The typed-slot mirroring
   (`_applyTypedRecord`) and type-name resolution (`_resolveTypeName`,
   including the `__car_wash__` / `__other__` sentinels) currently live inside
   `add_maintenance_record_dialog.dart`. Both the dialog and
   `CloseWorkOrderUseCase` need them. Extract first, then build on top.
2. **Keep the existing dialog**, relabelled "Log past maintenance" — genuine
   need for retro entry of work done before the WO system, and for jobs with
   no cost. It should offer "create a work order instead?" when a cost is
   entered.
3. **Dedupe key on maintenance records.** Both the dialog and WO close write
   history; add `sourceWorkOrderId` to `MaintenanceRecord` (alongside the
   existing `workOrderNumber`) so a record is never double-counted if someone
   logs the same job twice.

## 7. Phasing

**Phase 1 — core loop (2–3 days)**
Entity / model / repository / datasource / usecases + DI registration; board,
detail and create pages; full status machine through close; expense creation;
maintenance-history write-back; `MaintenanceHistoryWriter` extraction; rules
and indexes; policy fields and permission-service methods.

**Phase 2 — integration (1 day)**
Create-WO-from-alert on dashboard and maintenance screens; alert suppression
while a WO is open; notifications; policy editor section; variance guard;
`workOrderId` chip on expense list and detail.

**Phase 3 — polish (1 day)**
Public `/report-issue` form for drivers; Vehicle Detail work-order section;
CSV export; shop performance view (spend per shop, per vehicle, average
turnaround time).

## 8. Risks and open decisions

### 8.1 Duplicate expenses on double close
Mitigated by the fresh-read `expenseId` guard plus a confirmation dialog naming
the amount and the wallet. Worth an integration test — the existing
`test/features/finance/domain/usecases/approve_and_post_test.dart` is a good
model, and `test_finance_repository.dart` already provides a fake.

### 8.2 Alerts resetting twice
If someone closes a WO *and* logs the same service in the old dialog, history
gets two records. The `sourceWorkOrderId` dedupe key (6.3) plus a warning in
the dialog when an open WO exists for that vehicle+type covers it.

### 8.3 Work already paid by the driver in cash
Real and common: the driver pays the shop from a cash advance. Creating a fresh
expense would double-count. The `paidFromDriverAdvance` flag should route to
`settleCashAdvance` instead of `insertExpense`. **Recommend deferring to
phase 4** — but the flag belongs in the entity from day one so the data model
does not need migrating later.

### 8.4 Decisions I'd like confirmed

| Question | My recommendation |
|---|---|
| Should Shamnad approve, or only report? | **Report + issue, not approve.** He raises and manages the job; the money approval sits with manager/finance. Configurable via `workOrderApproval` if you disagree. |
| Auto-approve threshold | **300 SAR.** Oil changes and car washes flow without ceremony; anything meaningful gets a human. |
| Where does the board live in nav? | **Under Vehicles**, not Finance. Coordinators and Shamnad live in Vehicles; finance only needs the resulting expense. |
| Backfill existing history into WOs? | **No.** Work orders start from go-live; historical records display "No work order". Backfilling invents approvals that never happened. |
