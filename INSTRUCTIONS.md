# Developer Instructions

How to work on the **Property Manager** codebase (V1 operational).

---

## 1. Product goal

A practical **property + finance** operations app for small property businesses:

- Sell/track plots per site
- Record customer payments and documents
- Track informal lending/borrowing separately
- Role-based access for admin vs staff

---

## 2. Module map (implemented)

| Module | Screens | Services |
|--------|---------|----------|
| Auth | `login_screen`, `auth_gate` | `auth_service` |
| Dashboard | `dashboard_screen` | `dashboard_service` |
| Property | `site_list`, `plot_list`, `customer_detail`, `add_*` | `site_service`, `plot_service`, `customer_service`, `property_analytics_service`, `search_service` |
| Documents | `document_upload`, `document_preview` | `document_service`, `storage_service` |
| Ledger | `ledger/*` | `ledger_service`, `backup_service`, `pdf_service` |
| Insights | `reports_screen` | `dashboard_service`, `property_analytics_service` |
| System | — | `notification_service`, `emi_checker`, `inactivity_service` |

---

## 3. Canonical Firestore paths

Always use `lib/constants/firestore_paths.dart`:

```dart
sites / plots / customer / details / payments | documents
ledger / data / lending | borrowing / installments
users
```

**Never** introduce `ledger/master` in new code.

**Document storage ID:** `{siteId}_{plotId}` for Storage; Firestore docs under plot `documents` subcollection.

---

## 4. Coding rules

1. **Firebase logic in services** — avoid new direct Firestore calls in screens.  
2. **Transactions** for payment/loan writes that update aggregates.  
3. **Ledger math** — use `LedgerCalculator` only; do not duplicate interest logic.  
4. **Money display** — use `LedgerMoneyFormat.rupees()`.  
5. **Plot numbers** — use `PlotService.isPlotNumberTaken()` before create.  
6. **Overpayments** — do not clamp `remaining` to zero (property or ledger).  
7. **Web documents** — use `DocumentService.fetchDocumentBytes()` + `saveFile()`; no raw Dio to Storage URLs on web.  
8. **Paths** — update `DATABASE_SCHEMA.md` and `firestore_paths.dart` together if schema changes.

---

## 5. Adding a new feature (checklist)

- [ ] Model in `lib/models/` if new entity  
- [ ] Service methods in `lib/services/`  
- [ ] Screen in `lib/screens/`  
- [ ] Reuse widgets from `lib/widgets/`  
- [ ] Update `firestore.rules` if new collection  
- [ ] Update docs: README, ARCHITECTURE, DATABASE_SCHEMA, USER_MANUAL as needed  
- [ ] Add test if business logic (prefer calculator/service unit tests)

---

## 6. UI conventions

- **Property** UI: blue (`#1E3A8A`, `#2563EB`)  
- **Ledger** UI: teal (`#0F766E`)  
- **Insights** UI: purple (`#6D28D9`)  
- Use `RefreshIndicator` on lists loaded via `Future`  
- Use `EmptyState` for zero-data search results  
- Admin-only actions: check `role == 'admin'` in UI **and** enforce in rules

---

## 7. Local development

```bash
flutter pub get
flutter run -d chrome
flutter analyze lib
flutter test
```

Firebase project configured in `lib/firebase_options.dart` (FlutterFire CLI).

---

## 8. Deploy checklist

1. `flutter build web`  
2. `firebase deploy` (hosting)  
3. `firebase deploy --only firestore:rules,storage`  
4. Apply Storage CORS for web (`cors.json`) if document preview/download fails  
5. Verify `users/{adminUid}.role == "admin"` in Firestore

---

## 9. Completed V2 items (partial)

Already implemented (do not re-build from scratch):

- Three-zone admin dashboard  
- Property Hub / plot analytics / filters  
- Insights Hub with charts  
- Ledger replay + overpayment UI  
- Document preview/download web fixes  
- Unique plot numbers  
- Property payment overpayment  
- `firestore.rules` / `storage.rules` templates  
- Ledger + login tests  

---

## 10. Remaining V2 priorities

- Migrate remaining screen-level Firestore calls to services  
- Global search across sites  
- Plot edit screen  
- PDF receipt for plot payments  
- Riverpod state management  
- Expand widget/integration tests  
- Unify document paths (remove legacy `customers/` dependency)

See `PRODUCT_ROADMAP.md`.

---

## 11. Documentation to keep in sync

When changing behavior, update:

| File | When |
|------|------|
| `USER_MANUAL.md` | User-visible flow or rules |
| `DATABASE_SCHEMA.md` | Fields, paths, rules |
| `ARCHITECTURE.md` | Services, architecture, flows |
| `README.md` | Overview, setup, feature list |
| `AGENT.md` / `copilot-instructions.md` | AI assistant context |
