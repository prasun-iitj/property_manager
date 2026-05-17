# Property Manager App

Flutter + Firebase application for **property sales operations**, **customer payment tracking**, **document management**, and **personal lending/borrowing ledger**.

**Maintainer:** Prasun Kumar Tripathi  
**Version:** 1.1.0 (`v1.1.0-cursor`)  
**Status:** V1 operational with V2 hardening in progress

> **🤖 Latest release (v1.1.0):** Features, fixes, and documentation in branch `feature/v2-upgrade` were built with **[Cursor](https://cursor.com)** AI-assisted development. See [CHANGELOG.md](CHANGELOG.md).

---

## What this app is about

Property Manager helps **property businesses** (land/colony dealers, small developers) run day-to-day operations:

1. **Property module** — Sites → Plots → Customers → Payments → Documents  
2. **Finance module** — Personal lending & borrowing ledger (separate from plot sales)  
3. **Insights** — Dashboards, charts, and cross-business summaries  

It is **not** a full accounting ERP; it is an operational tool focused on collections, outstanding balances, customer files, and informal loan tracking.

---

## Documentation index

| Document | Audience | Contents |
|----------|----------|----------|
| **[USER_MANUAL.md](USER_MANUAL.md)** | End users | Step-by-step features, navigation, business rules, troubleshooting |
| **[ARCHITECTURE.md](ARCHITECTURE.md)** | Developers | Layers, services, screens, data flow, technical design |
| **[DATABASE_SCHEMA.md](DATABASE_SCHEMA.md)** | Developers / DB admins | Firestore paths, fields, indexes, security |
| **[INSTRUCTIONS.md](INSTRUCTIONS.md)** | Developers | Conventions, modules, how to extend safely |
| **[PRODUCT_ROADMAP.md](PRODUCT_ROADMAP.md)** | Product / dev | V1–V4 evolution plan |
| **[AGENT.md](AGENT.md)** | AI assistants | Safe-change guidelines |

---

## Feature summary (current)

### Authentication & roles

- Firebase Auth (email/password)
- Roles: `admin` | `staff` via `users/{uid}.role`
- Admin → three-zone dashboard; Staff → Property Hub
- Inactivity session handling; EMI check on login

### Property module

- Sites CRUD (admin), cascade delete with password
- Plots per site with **unique plot numbers** per site
- One customer per plot (`customer/details`)
- Payments with transactional updates; **overpayment** (negative balance)
- Documents: upload, camera, preview, download, rename
- Property Hub & plot list with search, filters, analytics banners
- Per-customer payment chart; site customer search

### Finance (ledger) module

- Lending & borrowing loans with monthly interest %
- Installments with **interest-first** chronological replay
- Overpayment support (negative remaining principal)
- Unified loan detail UI; live installment preview
- Ledger dashboard with interactive monthly cash-flow chart
- Ledger analytics screen; CSV backup export

### Insights module

- Insights Hub: property + ledger snapshots, collection chart, top sites
- Admin dashboard: Property / Finance / Insights zones

### Supporting

- Local EMI notifications
- PDF generation utilities (ledger)
- Firebase security rules templates (`firestore.rules`, `storage.rules`)
- Unit tests: ledger calculator, login smoke test

---

## Application flow (high level)

```
main.dart → AuthGate
              ├─ not signed in → LoginScreen
              └─ signed in → read users/{uid}.role
                    ├─ admin → DashboardScreen (3 zones)
                    └─ staff → SiteListScreen (Property Hub)
```

**Property:** SiteList → PlotList → CustomerDetail → (Payment / Documents)  
**Ledger:** LedgerDashboard → LendingList | BorrowingList → LedgerDetail → AddInstallment  
**Insights:** ReportsScreen (from dashboard Insights zone)

---

## Tech stack

| Layer | Technology |
|-------|------------|
| UI | Flutter 3.x (Material 3 seed theme) |
| Auth | Firebase Auth |
| Database | Cloud Firestore |
| Files | Firebase Storage |
| Charts | fl_chart |
| PDF | syncfusion_flutter_pdfviewer, pdf, printing |
| Files pick/upload | file_picker, image_picker |
| HTTP | dio (mobile fallback for storage) |
| Notifications | flutter_local_notifications |
| Deploy | Firebase Hosting (web) |

**Platforms in repo:** Web, Android, iOS, Windows, macOS

---

## Firestore structure (canonical)

See `lib/constants/firestore_paths.dart`.

### Property

```
sites/{siteId}
  plots/{plotId}
    customer/details
      payments/{paymentId}
      documents/{documentId}
```

### Ledger

```
ledger/data/lending/{loanId}/installments/{installmentId}
ledger/data/borrowing/{borrowId}/installments/{installmentId}
```

### Users

```
users/{uid}  →  { role: "admin" | "staff", ... }
```

### Legacy

- `customers/{legacyId}/documents` — read for old uploads  
- Storage files: `customers/{siteId}_{plotId}/{fileName}`

---

## Key business rules

| Domain | Rule |
|--------|------|
| Ledger | Monthly interest on remaining principal; interest paid first; payments sorted by date; balance may be negative |
| Property payments | `remaining = totalPrice - totalPaid`; overpayment allowed |
| Plot numbers | Unique per site (normalized trim + lowercase) |
| Documents | Metadata in Firestore; bytes in Storage |

---

## Project layout

```
lib/
  main.dart                 # Firebase + notifications init
  auth_gate.dart            # Auth + role routing
  constants/
    firestore_paths.dart    # Canonical paths
  models/                   # site, plot, customer, document
  services/                 # Firebase business logic
  screens/                  # UI
  screens/ledger/           # Ledger module
  utils/                    # ledger_calculator, file_saver, storage fetch
  widgets/                  # dashboard_zone, charts, stat_card, ...
firestore.rules
storage.rules
cors.json                   # Storage CORS template for web
```

---

## Run locally

```bash
flutter pub get
flutter run -d chrome    # web
flutter run -d android   # device/emulator
```

**Hot restart:** press `R` in the terminal running `flutter run`.

---

## Build & deploy

```bash
flutter build web
firebase deploy
```

Deploy security rules before production:

```bash
firebase deploy --only firestore:rules,storage
```

**Web document preview/download** may require Storage CORS:

```powershell
gsutil cors set cors.json gs://propertymanagerapp-c4961.firebasestorage.app
# or: .\scripts\apply_storage_cors.ps1
```

---

## Tests

```bash
flutter analyze lib
flutter test
```

---

## Version history (summary)

- **v1.1.0-cursor (2026-05-18):** Dashboard zones, analytics, ledger replay UI, web documents, docs overhaul — **developed with Cursor**  
- **V1 baseline:** Full property + ledger modules on Firebase  
- **V2 (in progress):** Riverpod, global search, receipt PDFs (see PRODUCT_ROADMAP.md)

---

## Development attribution

| Tool | Role |
|------|------|
| **[Cursor](https://cursor.com)** | Primary IDE for v1.1.0 feature work, refactors, debugging, and documentation |
| **Flutter / Firebase** | Application stack |
| **Maintainer** | Prasun Kumar Tripathi — product direction and review |

To identify this release in git: `git tag -l "*cursor*"` or `git log --grep="Cursor"`.
