# AI Agent Development Guide

Guidance for AI coding assistants working on **Property Manager** (Flutter + Firebase).

---

## Project summary

| Item | Value |
|------|--------|
| Type | Flutter cross-platform app |
| Backend | Firebase Auth, Firestore, Storage, Cloud Functions |
| Domain | Property sales + personal lending/borrowing ledger + admin team/backup |
| Version | v1.2 operational |
| Primary user | Property dealer / small developer (India, ₹) |
| Live web | https://propertymanagerapp-c4961.web.app |

---

## Functional scope (current)

### Authentication

- Email/password via Firebase Auth  
- Google sign-in with **registration gate** (must exist in `users/{uid}`)  
- `users/{uid}.role`: `admin` | `staff`  
- Admin → `DashboardScreen` (3 zones + team + backup toolbar)  
- Staff → `SiteListScreen` (Property Hub + `RoleAccessBanner`)

### Admin platform

- **Manage team** — Cloud Functions create/update/disable users; email OTP for admin actions  
- **Cloud backup** — scheduled + manual Firestore JSON to Storage  
- `config/system`, `backupHistory`, `systemOtp` collections  
- Super-admin email in `config/system` for OTP delivery (nodemailer/SMTP)

### Property (`sites` → `plots` → `customer/details`)

- Sites, plots, customers, payments, documents  
- Unique plot numbers per site  
- Payment overpayment allowed (`remaining` can be negative)  
- EMI day + overdue notifications  
- Document upload/preview/download/rename (web-aware)  
- WhatsApp after payment (`whatsapp_launcher.dart`)

### Ledger (`ledger/data`)

- `lending` and `borrowing` with `installments`  
- Interest-first, date-sorted replay (`LedgerCalculator`)  
- Overpayment allowed on loans  
- Dashboard chart, analytics, CSV backup

### Insights

- `ReportsScreen` — property + ledger summaries, charts  
- `DashboardService`, `PropertyAnalyticsService`

### Performance

- `AppCache` (~60s TTL) — stale-while-revalidate  
- `firestore_aggregate_helpers.dart` — parallel reads  

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
config/system
backupHistory/{id}
systemOtp/{id}   (functions only)
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
| `TeamService` | Callable functions for team/OTP/backup settings |
| `AppCache` | Short-lived navigation cache |

**Server:** `functions/index.js` — never duplicate team/backup logic in Flutter client.

---

## Business rules (do not break)

1. **Ledger:** interest on remaining principal → interest first → principal; sort by date; allow negative balance.  
2. **Property payments:** allow `remaining < 0` (overpayment).  
3. **Plot numbers:** unique per site via `PlotService.normalizePlotNumber`.  
4. **Web downloads:** no `Dio.get(firebaseStorageUrl)` — use Storage SDK or authenticated fetch + blob save.  
5. **Team users:** provision via Cloud Functions only.  
6. **Admin OTP:** verify server-side; hash in `systemOtp`.

---

## File map (high signal)

```
lib/
  auth_gate.dart
  constants/firestore_paths.dart
  utils/ledger_calculator.dart      # ALL ledger math
  services/                         # Firebase layer + app_cache
  screens/admin/                    # team, backup
  screens/ledger/                   # Ledger UI
  widgets/admin_otp_dialog.dart
  widgets/role_access_banner.dart
functions/index.js                  # Team, OTP, backup
```

---

## Assistant priorities

1. Read `ARCHITECTURE.md` and `DATABASE_SCHEMA.md` before schema changes.  
2. Put Firebase logic in **services**, not large `build()` methods.  
3. Update **USER_MANUAL.md** when user-visible behavior changes.  
4. Run `flutter analyze lib` and `flutter test` after substantive changes.  
5. Do not remove overpayment support or re-clamp balances to zero.  
6. Do not use `refFromURL` for Storage when path + `customerId`/`fileName` available (query-param bugs on web).  
7. Web deploy: `flutter build web --release --no-web-resources-cdn`.  
8. Team/backup: change `functions/index.js` + deploy functions; update rules if new collections.

---

## Common tasks

| Task | Where to change |
|------|-----------------|
| Ledger formula | `lib/utils/ledger_calculator.dart` + tests |
| Plot payment rules | `lib/services/customer_service.dart` |
| New screen | `lib/screens/` + route from parent |
| Firestore path | `firestore_paths.dart` + rules + DATABASE_SCHEMA.md |
| Web document fix | `document_service.dart`, `file_saver/`, `storage_bytes_fetcher_*` |
| Team / OTP / backup | `functions/index.js`, `team_service.dart`, admin screens |
| Cache behavior | `app_cache.dart` + consuming service |

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
| `INTERVIEW_PREP.md` | Interview revision (simple language) |
| `ARCHITECTURE.md` | Technical design |
| `DATABASE_SCHEMA.md` | Schema reference |
| `INSTRUCTIONS.md` | Dev conventions, deploy |
| `CHANGELOG.md` | Releases |
| `PRODUCT_ROADMAP.md` | Future versions |

Keep these synchronized when shipping features.
