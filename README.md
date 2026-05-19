# Property Manager App

Flutter + Firebase application for **property sales operations**, **customer payment tracking**, **document management**, **personal lending/borrowing ledger**, **team management**, and **cloud backups**.

**Maintainer:** Prasun Kumar Tripathi  
**Version:** 1.2.0 (`feature/v2-upgrade`)  
**Status:** V1 operational with V2 admin platform features deployed  
**Live (web):** https://propertymanagerapp-c4961.web.app  
**Firebase project:** `propertymanagerapp-c4961`

> **🤖 Development:** v1.1+ features built with **[Cursor](https://cursor.com)** AI-assisted development. See [CHANGELOG.md](CHANGELOG.md).

---

## What this app is about

Property Manager helps **property businesses** (land/colony dealers, small developers) run day-to-day operations:

1. **Property module** — Sites → Plots → Customers → Payments → Documents  
2. **Finance module** — Personal lending & borrowing ledger (separate from plot sales)  
3. **Insights** — Dashboards, charts, and cross-business summaries  
4. **Admin platform** — Team users, email OTP for admin actions, scheduled Firestore backups  

It is **not** a full accounting ERP; it is an operational tool focused on collections, outstanding balances, customer files, and informal loan tracking.

---

## Documentation index

| Document | Audience | Contents |
|----------|----------|----------|
| **[USER_MANUAL.md](USER_MANUAL.md)** | End users | Step-by-step features, navigation, business rules, troubleshooting |
| **[INTERVIEW_PREP.md](INTERVIEW_PREP.md)** | You (interviews) | Simple explanations of stack + flow; 5–10 min revision |
| **[ARCHITECTURE.md](ARCHITECTURE.md)** | Developers | Layers, services, screens, data flow, Cloud Functions |
| **[DATABASE_SCHEMA.md](DATABASE_SCHEMA.md)** | Developers / DB admins | Firestore paths, fields, indexes, security |
| **[INSTRUCTIONS.md](INSTRUCTIONS.md)** | Developers | Conventions, modules, team/backup deploy, custom domain |
| **[PRODUCT_ROADMAP.md](PRODUCT_ROADMAP.md)** | Product / dev | V1–V4 evolution plan |
| **[AGENT.md](AGENT.md)** | AI assistants | Safe-change guidelines |
| **[CHANGELOG.md](CHANGELOG.md)** | Everyone | Release history |

---

## Feature summary (current)

### Authentication & roles

- Firebase Auth (email/password; Google sign-in with registration gate)
- Roles: `admin` | `staff` via `users/{uid}.role`
- Admin → three-zone dashboard + team + cloud backup
- Staff → Property Hub only (`RoleAccessBanner`)
- Inactivity session handling; EMI check on login
- Redesigned **login screen** (modern UI, validation)

### Admin platform (v1.2)

- **Manage team** — create staff/admin, enable/disable, promote to admin
- **Email OTP** — 6-digit code to super-admin email for new admin / promote (Cloud Functions + nodemailer)
- **Cloud backup** — manual run + daily 2:00 AM IST schedule → Storage JSON export; history in `backupHistory`
- Super-admin email stored in `config/system`

### Property module

- Sites CRUD (admin), cascade delete with password
- Plots per site with **unique plot numbers** per site
- One customer per plot (`customer/details`)
- Payments with transactional updates; **overpayment** (negative balance)
- Documents: upload, camera, preview, download, rename
- Property Hub & plot list with search, filters, analytics banners
- Per-customer payment chart; site customer search
- WhatsApp message after payment (web/mobile launchers)

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

### Performance & web

- **AppCache** (~60s TTL) — stale-while-revalidate for faster navigation
- Parallel Firestore reads via aggregate helpers
- Web build: `--no-web-resources-cdn` for reliable PWA
- Storage CORS for in-app document fetch on web

### Supporting

- Local EMI notifications
- PDF generation utilities (ledger)
- Firebase security rules (`firestore.rules`, `storage.rules`)
- Cloud Functions (`functions/index.js`, `asia-south1`)
- Unit tests: ledger calculator, login smoke test

---

## Application flow (high level)

```
main.dart → AuthGate
              ├─ not signed in → LoginScreen
              └─ signed in → read users/{uid}.role
                    ├─ admin → DashboardScreen (3 zones + team + backup icons)
                    └─ staff → SiteListScreen (Property Hub)
```

**Property:** SiteList → PlotList → CustomerDetail → (Payment / Documents)  
**Ledger:** LedgerDashboard → LendingList | BorrowingList → LedgerDetail → AddInstallment  
**Insights:** ReportsScreen (from dashboard Insights zone)  
**Admin:** ManageTeamScreen · BackupSettingsScreen (callable functions)

---

## Tech stack

| Layer | Technology |
|-------|------------|
| UI | Flutter 3.x (Material 3 seed theme) |
| Auth | Firebase Auth |
| Database | Cloud Firestore |
| Files | Firebase Storage |
| Serverless | Cloud Functions v2 (Node.js, `asia-south1`) |
| Email OTP | nodemailer (SMTP / Gmail app password) |
| Charts | fl_chart |
| PDF | syncfusion_flutter_pdfviewer, pdf, printing |
| Files pick/upload | file_picker, image_picker |
| HTTP | dio (mobile fallback for storage) |
| Notifications | flutter_local_notifications |
| Deploy | Firebase Hosting (web) + Functions deploy |

**Platforms in repo:** Web (primary), Android, iOS, Windows, macOS

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

### Users & system

```
users/{uid}  →  { role: "admin" | "staff", email, disabled, ... }
config/system  →  superAdminEmail, backupEnabled, ...
backupHistory/{id}
systemOtp/{id}  (server-managed, hashed OTP)
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
| Team users | Created/updated only via Cloud Functions (not direct client writes to Auth) |

---

## Project layout

```
lib/
  main.dart                 # Firebase + notifications init
  auth_gate.dart            # Auth + role routing
  constants/
    firestore_paths.dart    # Canonical paths
  models/                   # site, plot, customer, document, team_member
  services/                 # Firebase business logic + app_cache
  screens/                  # UI
  screens/admin/            # manage_team, backup_settings, team_member_form
  screens/ledger/           # Ledger module
  utils/                    # ledger_calculator, file_saver, whatsapp, external_url
  widgets/                  # dashboard_zone, admin_otp_dialog, role_access_banner, ...
functions/
  index.js                  # Team, OTP, backup Cloud Functions
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
flutter build web --release --no-web-resources-cdn
firebase deploy --only hosting
firebase deploy --only functions,firestore:rules,storage
```

**Email OTP:** set `SMTP_USER` and `SMTP_PASS` on Cloud Functions (Gmail app password). See [INSTRUCTIONS.md](INSTRUCTIONS.md).

**Web document preview/download** may require Storage CORS:

```powershell
gsutil cors set cors.json gs://propertymanagerapp-c4961.firebasestorage.app
```

---

## Tests

```bash
flutter analyze lib
flutter test
```

---

## Version history (summary)

- **v1.2.0 (2026-05-19):** Team management, email OTP, cloud backup, AppCache, login redesign, docs + `INTERVIEW_PREP.md`  
- **v1.1.0-cursor (2026-05-18):** Dashboard zones, analytics, ledger replay UI, web documents — **developed with Cursor**  
- **V1 baseline:** Full property + ledger modules on Firebase  
- **V2 (ongoing):** Riverpod, global search, receipt PDFs (see PRODUCT_ROADMAP.md)

---

## Development attribution

| Tool | Role |
|------|------|
| **[Cursor](https://cursor.com)** | Primary IDE for v1.1+ feature work, refactors, debugging, and documentation |
| **Flutter / Firebase** | Application stack |
| **Maintainer** | Prasun Kumar Tripathi — product direction and review |
