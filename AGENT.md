# AI Agent Development Guide

Guidance for AI coding assistants working on **Property Manager** (Flutter + Firebase).

---

## Project summary

| Item | Value |
|------|--------|
| Type | Flutter cross-platform app |
| Backend | Firebase Auth, Firestore, Storage |
| Domain | Property sales + personal lending/borrowing ledger |
| Version | V1 operational |
| Primary user | Property dealer / small developer (India, ₹) |

---

## Functional scope (current)

### Authentication

- Email/password via Firebase Auth  
- `users/{uid}.role`: `admin` | `staff`  
- Admin → `DashboardScreen` (3 zones)  
- Staff → `SiteListScreen` (Property Hub)

### Property (`sites` → `plots` → `customer/details`)

- Sites, plots, customers, payments, documents  
- Unique plot numbers per site  
- Payment overpayment allowed (`remaining` can be negative)  
- EMI day + overdue notifications  
- Document upload/preview/download/rename (web-aware)

### Ledger (`ledger/data`)

- `lending` and `borrowing` with `installments`  
- Interest-first, date-sorted replay (`LedgerCalculator`)  
- Overpayment allowed on loans  
- Dashboard chart, analytics, CSV backup

### Insights

- `ReportsScreen` — property + ledger summaries, charts  
- `DashboardService`, `PropertyAnalyticsService`

---

## Canonical Firestore paths

**Use `lib/constants/firestore_paths.dart` — not outdated docs.**

```
sites/{siteId}/plots/{plotId}/customer/details
  payments/{paymentId}
  documents/{documentId}

ledger/data/lending/{loanId}/installments/{installmentId}
ledger/data/borrowing/{borrowId}/installments/{installmentId}

users/{uid}
```

**Legacy (read-only fallback):**

- `customers/{id}/documents`  
- Storage: `customers/{siteId}_{plotId}/{fileName}`

**Wrong (do not use in new code):** `ledger/master/...`

---

## Key services (prefer over inline Firestore)

| Service | Use for |
|---------|---------|
| `CustomerService` | Customer, payments (transactions) |
| `PlotService` | Plots, duplicate check |
| `SiteService` | Sites, cascade delete |
| `DocumentService` | Docs + `fetchDocumentBytes` |
| `LedgerService` | Loans, installments, replay |
| `DashboardService` | Stats, ledger monthly buckets |
| `PropertyAnalyticsService` | Site/plot summaries, property charts |
| `SearchService` | Site customer search |

---

## Business rules (do not break)

1. **Ledger:** interest on remaining principal → interest first → principal; sort by date; allow negative balance.  
2. **Property payments:** allow `remaining < 0` (overpayment).  
3. **Plot numbers:** unique per site via `PlotService.normalizePlotNumber`.  
4. **Web downloads:** no `Dio.get(firebaseStorageUrl)` — use Storage SDK or authenticated fetch + blob save.

---

## File map (high signal)

```
lib/
  auth_gate.dart
  constants/firestore_paths.dart
  utils/ledger_calculator.dart      # ALL ledger math
  services/                         # Firebase layer
  screens/                          # UI
  screens/ledger/                   # Ledger UI
  widgets/                          # dashboard_zone, property_chart, ...
```

---

## Assistant priorities

1. Read `ARCHITECTURE.md` and `DATABASE_SCHEMA.md` before schema changes.  
2. Put Firebase logic in **services**, not large `build()` methods.  
3. Update **USER_MANUAL.md** when user-visible behavior changes.  
4. Run `flutter analyze lib` and `flutter test` after substantive changes.  
5. Do not remove overpayment support or re-clamp balances to zero.  
6. Do not use `refFromURL` for Storage when path + `customerId`/`fileName` available (query-param bugs on web).

---

## Common tasks

| Task | Where to change |
|------|-----------------|
| Ledger formula | `lib/utils/ledger_calculator.dart` + tests |
| Plot payment rules | `lib/services/customer_service.dart` |
| New screen | `lib/screens/` + route from parent |
| Firestore path | `firestore_paths.dart` + rules + DATABASE_SCHEMA.md |
| Web document fix | `document_service.dart`, `file_saver/`, `storage_bytes_fetcher_*` |

---

## Testing

```bash
flutter test
flutter analyze lib
```

Existing: `test/ledger_calculator_test.dart`, `test/widget_test.dart`

---

## Documentation set

| File | Purpose |
|------|---------|
| `README.md` | Overview, setup, index |
| `USER_MANUAL.md` | End-user guide |
| `ARCHITECTURE.md` | Technical design |
| `DATABASE_SCHEMA.md` | Schema reference |
| `INSTRUCTIONS.md` | Dev conventions |
| `PRODUCT_ROADMAP.md` | Future versions |

Keep these synchronized when shipping features.
