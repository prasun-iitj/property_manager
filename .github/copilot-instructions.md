# Copilot / GitHub Copilot Instructions

Repository: **Property Manager** — Flutter + Firebase property & finance app.

---

## Architecture

```
lib/
  models/       # Typed data objects
  services/     # Firestore, Storage, analytics (prefer this over screens)
  screens/      # UI + navigation
  screens/ledger/
  widgets/      # Reusable UI
  utils/        # ledger_calculator, file_saver, storage helpers
  constants/    # firestore_paths.dart
```

---

## Rules

1. Put Firestore/Storage logic in **services**, not in screen `build()` methods.  
2. Use **`lib/constants/firestore_paths.dart`** for all collection paths.  
3. Use **`LedgerCalculator`** for any lending/borrowing interest math — do not duplicate.  
4. Allow **negative balances** for overpayments (property + ledger).  
5. Enforce **unique plot numbers** via `PlotService` before creating plots.  
6. Keep changes **backward-compatible** with existing V1 data unless migration is provided.  
7. On web, do not fetch Storage files with Dio from public URLs (CORS). Use `DocumentService.fetchDocumentBytes()`.

---

## Active Firestore paths (V1)

```
sites/{siteId}/plots/{plotId}/customer/details
  payments/{paymentId}
  documents/{documentId}

ledger/data/lending/{loanId}/installments/{installmentId}
ledger/data/borrowing/{borrowId}/installments/{installmentId}

users/{uid}   → role: admin | staff
```

**Do not use:** `ledger/master/...` (deprecated)

**Storage files:** `customers/{siteId}_{plotId}/{fileName}`

---

## Roles

| Role | Entry screen |
|------|----------------|
| admin | DashboardScreen (Property / Finance / Insights zones) |
| staff | SiteListScreen |

---

## UI color zones

- Property: blue `#1E3A8A`  
- Finance: teal `#0F766E`  
- Insights: purple `#6D28D9`

---

## When generating UI

- Reuse widgets: `DashboardZone`, `StatCard`, `ProgressSummaryCard`, `PropertyCollectionsChart`, `EmptyState`  
- Explicit loading and error states  
- `RefreshIndicator` on reloadable lists  
- Check `role == 'admin'` for destructive actions  

---

## Documentation

Update when behavior changes:

- `USER_MANUAL.md` — user-facing  
- `DATABASE_SCHEMA.md` — fields/paths  
- `ARCHITECTURE.md` — design  
- `README.md` — overview  

---

## Verify

```bash
flutter analyze lib
flutter test
```
