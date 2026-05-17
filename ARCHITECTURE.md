# System Architecture

**Property Manager** — technical architecture (current V1 implementation)  
**Last updated:** reflects operational codebase with Property / Finance / Insights zones

---

## 1. Architectural style

**Screen-driven Flutter UI** + **service layer** for Firebase operations.

| Layer | Location | Responsibility |
|-------|----------|----------------|
| Presentation | `lib/screens/`, `lib/widgets/` | UI, navigation, user input |
| Application services | `lib/services/` | Firestore, Storage, auth, analytics, exports |
| Domain logic | `lib/utils/ledger_calculator.dart` | Ledger interest/principal math (pure Dart) |
| Models | `lib/models/` | Typed entities and `toMap`/`fromMap` |
| Constants | `lib/constants/firestore_paths.dart` | Canonical collection paths |
| Infrastructure | Firebase SDK, `dio`, file savers | External I/O |

**Not yet adopted:** Riverpod/Provider app-wide, repository interfaces, clean architecture folders.

---

## 2. Startup & runtime flow

```
main()
  ├─ WidgetsFlutterBinding.ensureInitialized()
  ├─ Firebase.initializeApp(options: DefaultFirebaseOptions)
  ├─ NotificationService.init()  [non-blocking on failure]
  └─ runApp(MyApp → ActivityWrapper → AuthGate)

AuthGate (StreamBuilder authStateChanges)
  ├─ waiting → loading spinner
  ├─ no user → LoginScreen
  └─ user → FutureBuilder users/{uid}
        ├─ role == admin → DashboardScreen
        └─ else → SiteListScreen(role)

On authenticated session:
  ├─ InactivityService.startTimer(context)
  └─ EmiChecker.checkEmiDue()  [once per app session]
```

`ActivityWrapper` resets inactivity timer on tap/pan/scale anywhere in the app.

---

## 3. Navigation map

### Admin

```
DashboardScreen
  ├─ Property zone → SiteListScreen
  │     ├─ AddSiteScreen
  │     ├─ SiteCustomerSearchScreen
  │     └─ PlotListScreen
  │           ├─ AddPlotScreen
  │           └─ CustomerDetailScreen
  │                 ├─ AddCustomerScreen
  │                 ├─ AddPaymentScreen
  │                 └─ DocumentUploadScreen → DocumentPreviewScreen
  ├─ Finance zone → LedgerDashboard
  │     ├─ LendingListScreen → LendingDetailScreen (LedgerDetailScreen)
  │     ├─ BorrowingListScreen → BorrowingDetailScreen
  │     ├─ AddLendingScreen / AddBorrowingScreen
  │     └─ AddInstallmentScreen
  └─ Insights zone → ReportsScreen
        └─ LedgerAnalyticsScreen (link)
```

### Staff

```
SiteListScreen → (same property subtree as above, no admin dashboard)
```

---

## 4. Service catalog

| Service | Purpose |
|---------|---------|
| `AuthService` | Login/sign-up helpers |
| `SiteService` | Sites stream, save, cascade delete + storage cleanup |
| `PlotService` | Add plot, stream plots, **unique plot number** validation |
| `CustomerService` | Customer CRUD, payments (transactions), delete payment |
| `DocumentService` | Upload/download bytes, documents CRUD, legacy path fallback |
| `StorageService` | Aadhaar upload helper |
| `DashboardService` | Property stats, ledger overview, monthly ledger buckets |
| `PropertyAnalyticsService` | Global/site/plot summaries, property monthly chart |
| `SearchService` | Customer search within a site |
| `LedgerService` | Loans, installments, replay recalculation |
| `BackupService` | Ledger CSV export |
| `PdfService` | PDF generation for ledger |
| `NotificationService` | Local notifications init |
| `EmiChecker` | Scan plots for overdue EMI, notify |
| `InactivityService` | Session timeout handling |

### Shared utilities

| Utility | Purpose |
|---------|---------|
| `ledger_calculator.dart` | `LedgerCalculator`, `LedgerMoneyFormat`, replay types |
| `storage_path_parser.dart` | Parse Storage URL → object path |
| `storage_bytes_fetcher.dart` | Web authenticated Storage download |
| `file_saver/` | Platform save (web blob / mobile file) |

---

## 5. Data domains

### 5.1 Property domain

```
Site (1) ──► Plot (N) ──► Customer (0..1 per plot)
                              ├─ Payment (N)
                              └─ Document (N)
```

- Customer document id is always `details` under `customer/`.
- Legacy customer id for Storage: `{siteId}_{plotId}`.

### 5.2 Ledger domain

```
ledger/data
  ├─ lending/{loanId}
  │     └─ installments/{id}
  └─ borrowing/{borrowId}
        └─ installments/{id}
```

Balance fields on loan docs are updated when installments are added/deleted via replay in `LedgerService`.

### 5.3 Cross-domain

- Dashboard/Insights combine property collection stats + ledger stats.
- No automatic link between a plot customer and a ledger loan (manual separate entries).

---

## 6. Ledger calculation engine

Implemented in `lib/utils/ledger_calculator.dart` and applied via `LedgerService`:

1. Load all installments for a loan.
2. Sort by `date` ascending.
3. For each payment:
   - `interestDue = remainingPrincipal × rate% / 100` (if principal > 0)
   - Pay interest first, then principal.
   - `remainingPrincipal` may become **negative** (overpaid).
4. Persist `interestPaid`, `principalPaid`, `remainingPrincipal` on loan doc.

UI: `LedgerDetailScreen`, `ProgressSummaryCard`, overpayment banners.

---

## 7. Property payment engine

`CustomerService.addPayment` (Firestore transaction):

- `newTotalPaid = totalPaid + amount`
- `remaining = totalPrice - newTotalPaid` (**no clamp** — overpayment allowed)
- Updates `nextEmiDate` from payment date + `emiDay`

---

## 8. Document pipeline (web-aware)

```
Upload → Storage: customers/{customerId}/{fileName}
        → Firestore: sites/.../customer/details/documents/{docId}

Preview/Download:
  1. Firebase Storage getData (path or parsed URL)
  2. Web: authenticated REST + Bearer token
  3. Web fallback preview: iframe embed of signed URL
  4. Web download: blob URL + anchor download
```

Requires Storage **CORS** for in-app byte fetch on web (`cors.json`).

---

## 9. UI patterns

| Pattern | Usage |
|---------|--------|
| `DashboardZone` | Three-color admin dashboard panels |
| `PropertyCollectionsChart` | fl_chart bar chart for property payments |
| `ProgressSummaryCard` | Plot/loan repayment progress |
| `StatCard` / `ZoneStatTile` | Metric display |
| `RefreshIndicator` + service reload | List screens |
| `StreamBuilder` | Real-time documents, some legacy streams |
| `FutureBuilder` | Customer detail, initial loads |

**Theme:** Primary `#1E3A8A`, Finance teal `#0F766E`, Insights purple `#6D28D9`.

---

## 10. Security architecture

| File | Scope |
|------|--------|
| `firestore.rules` | Role-based: admin writes sites/plots; staff+admin writes customers/payments/docs/ledger |
| `storage.rules` | Authenticated read/write under `customers/{customerId}/**` |

App-level gating (e.g. delete site, admin-only buttons) is **in addition to** rules — rules must be deployed to Firebase.

---

## 11. Testing strategy (current)

| Test | File |
|------|------|
| Ledger interest-first + overpayment | `test/ledger_calculator_test.dart` |
| Login UI smoke | `test/widget_test.dart` |

Run: `flutter test`, `flutter analyze lib`

---

## 12. Known gaps & V2 direction

| Gap | Target |
|-----|--------|
| Some screens still call Firestore directly | Migrate to services |
| Document Storage path vs Firestore path duality | Unify under plot `documents` only |
| No plot edit screen | Add edit plot + change number with validation |
| Global search | Search across all sites |
| State management | Riverpod/Provider |
| Receipt PDF for plot payments | PdfService extension |
| Firestore indexes | Document composite indexes for scale |

See `PRODUCT_ROADMAP.md` for phased plan.

---

## 13. Dependency graph (simplified)

```
screens → services → Firebase (Auth, Firestore, Storage)
         → utils (calculator, file_saver)
         → models
widgets → (standalone or used by screens)
auth_gate → screens + services (emi, inactivity)
```

Avoid circular imports: services should not import screens.
