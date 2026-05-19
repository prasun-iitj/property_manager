# Property Manager — Interview Prep (5–10 min revision)

**Use this before explaining the project in an interview.**  
Simple language first; technical terms in brackets where helpful.

---

## 1. Elevator pitch (30 seconds)

> **Property Manager** is a cross-platform business app I built with **Flutter** and **Firebase**. It helps small property dealers manage **plot sales** (sites, plots, customers, payments, documents) and a separate **money ledger** for informal lending/borrowing. Admins get a dashboard with analytics; staff get day-to-day property tools only. Data lives in the cloud, syncs when online, and runs as a **web app** (PWA) and on mobile.

**Live URL:** https://propertymanagerapp-c4961.web.app  
**Firebase project:** `propertymanagerapp-c4961`  
**Maintainer:** Prasun Kumar Tripathi

---

## 2. Tech stack — one line each

| Term | Simple explanation | In this project |
|------|-------------------|-----------------|
| **Dart** | Programming language used by Flutter (like Java for Android, but for Flutter apps) | All app logic in `lib/` |
| **Flutter** | Google’s UI toolkit — one codebase for web, Android, iOS, desktop | Screens, widgets, navigation |
| **Firebase** | Google’s backend-as-a-service (login, database, files, hosting, serverless) | Entire backend |
| **Firebase Auth** | User sign-in (email/password, Google) | Login screen, session |
| **Cloud Firestore** | NoSQL cloud database (documents in collections, real-time sync) | Sites, plots, customers, ledger, users |
| **Firebase Storage** | Cloud file storage (PDFs, images) | Customer documents, backups |
| **Firebase Hosting** | Hosts the built web app | `flutter build web` → deploy |
| **Cloud Functions** | Server code that runs in the cloud (Node.js) | Team users, email OTP, scheduled backup |
| **PWA** | Progressive Web App — installable website that feels like an app | Web build + `manifest.json` |

---

## 3. How the app is built (layers)

```
User taps screen (Flutter UI)
       ↓
Screen calls a Service (business logic)
       ↓
Service reads/writes Firestore or Storage (or calls Cloud Function)
       ↓
Firebase syncs data; UI updates (FutureBuilder / StreamBuilder / cache)
```

**Important folders:**

- `lib/screens/` — what the user sees  
- `lib/services/` — Firebase and business rules (keep logic here, not in UI)  
- `lib/models/` — data shapes (Site, Plot, Customer, TeamMember)  
- `lib/utils/` — pure logic (e.g. ledger interest calculator)  
- `lib/constants/firestore_paths.dart` — single source of truth for DB paths  
- `functions/` — admin-only server actions (team, OTP, backup)

---

## 4. Application flow (what happens after login)

```
App starts → Firebase init → AuthGate checks login
  ├─ Not logged in → Login screen
  └─ Logged in → Read users/{uid}.role from Firestore
        ├─ admin  → Dashboard (Property | Finance | Insights)
        └─ staff  → Property Hub only (sites list)
```

**Property path:** Sites → Plots → Customer → Payments / Documents  
**Ledger path:** Ledger dashboard → Lending or Borrowing → Loan detail → Add installment  
**Admin extras:** Manage team, Cloud backup (toolbar icons on dashboard)

Unregistered Google users are blocked until an admin adds them via **Manage team**.

---

## 5. Main features (what to mention)

### Property module
- Sites (colonies/projects) with plots  
- One customer per plot; track payments (Cash/UPI/Bank)  
- **Overpayment** allowed (balance can go negative = customer paid extra)  
- **Unique plot numbers** per site  
- Documents: upload, preview, download (web uses Storage SDK + blob, not raw URLs)  
- EMI reminders; WhatsApp message after payment (platform-specific launcher)  
- Search customers within a site; charts for collections  

### Finance (ledger) module
- Separate from plot sales — informal **lending** (you gave money) and **borrowing** (you took money)  
- Monthly interest %; payments sorted by **date**; **interest paid first**, then principal  
- **Overpayment** on loans too (negative remaining principal)  
- Ledger dashboard with monthly cash-flow chart; CSV export  

### Insights
- Combined property + ledger snapshots, charts, top sites by outstanding  

### Admin & platform (recent)
- **Team management:** create staff/admin via Cloud Functions (not direct Firestore writes)  
- **Email OTP:** adding/promoting admins sends 6-digit code to super-admin email (nodemailer/SMTP)  
- **Cloud backup:** scheduled daily 2 AM IST + manual run → JSON in Storage, history in `backupHistory`  
- **App cache:** ~60s in-memory cache for faster back/forward navigation (stale-while-revalidate)  
- **Redesigned login** screen; role banner for staff  

---

## 6. Data model (Firestore) — interview-friendly

**Property (hierarchy):**
```
sites/{siteId}
  plots/{plotId}
    customer/details          ← always this document id
      payments/{paymentId}
      documents/{documentId}
```

**Ledger:**
```
ledger/data/lending/{loanId}/installments/{id}
ledger/data/borrowing/{borrowId}/installments/{id}
```

**Users & system:**
```
users/{uid}           → role: admin | staff
config/system         → superAdminEmail, backup settings
backupHistory/{id}    → backup run metadata
systemOtp/{id}        → hashed OTP (server only)
```

**Files:** Storage path `customers/{siteId}_{plotId}/{fileName}`

---

## 7. Security & roles

| Role | Access |
|------|--------|
| **admin** | Full dashboard, sites CRUD, team, cloud backup, ledger, property |
| **staff** | Property Hub + customers/payments/docs/ledger; no site delete, no team/backup |

- **Firestore rules** enforce read/write by role  
- **Sensitive writes** (create user, change role, backup) go through **callable Cloud Functions** (region `asia-south1`)  
- Admin actions like delete site need **password re-auth** in UI  

---

## 8. Business rules (often asked)

1. **Ledger:** For each payment (by date): interest due = remaining × rate%; pay interest first, then principal; balance may go negative.  
2. **Plot payments:** `remaining = totalPrice - totalPaid` — no clamp at zero.  
3. **Plot numbers:** Unique per site (normalized string compare).  
4. **Payments to customer:** Firestore **transaction** updates customer totals + payment doc together.  

---

## 9. Performance & web specifics

- **AppCache** (`lib/services/app_cache.dart`): caches dashboard/site/plot/ledger results ~60 seconds; shows cached data immediately, refreshes in background.  
- **Parallel Firestore reads** where possible (`firestore_aggregate_helpers.dart`).  
- **Web build:** `flutter build web --release --no-web-resources-cdn` (avoids CanvasKit CDN issues / black screen on some devices).  
- **Documents on web:** fetch bytes via Firebase Storage API + CORS on bucket (`cors.json`), not Dio on public URLs.  

---

## 10. Deployment pipeline (how it goes live)

1. Develop in Flutter (`flutter run -d chrome`)  
2. `flutter build web --release --no-web-resources-cdn`  
3. `firebase deploy --only hosting` (web)  
4. `firebase deploy --only functions,firestore:rules,storage` (backend)  
5. Blaze plan needed for Cloud Functions + scheduled backup  

**Optional custom domain:** DuckDNS `mayurproperty.duckdns.org` — Firebase may require CNAME; DuckDNS often only supports A record (documented in INSTRUCTIONS.md).

---

## 11. Common interview Q&A

**Q: Why Flutter?**  
One codebase for web + mobile; fast UI; good for a small team/solo developer.

**Q: Why Firebase?**  
Auth, database, files, hosting, and serverless functions in one platform; no self-managed servers; real-time sync.

**Q: Why separate Property and Ledger?**  
Plot sales and informal loans are different business processes; same app, different data trees.

**Q: How do you prevent duplicate plot numbers?**  
`PlotService` checks normalized plot number before create; UI shows warning if duplicates exist.

**Q: How is ledger interest calculated?**  
Pure Dart `LedgerCalculator` — replay all installments in date order; interest-first allocation; used by `LedgerService` on save.

**Q: How do you add a new team member?**  
Admin opens Manage Team → Cloud Function `createTeamMember` creates Firebase Auth user + `users/{uid}` doc (client cannot write arbitrary user docs).

**Q: How does admin OTP work?**  
Function `requestAdminOtp` emails 6-digit code to `config/system.superAdminEmail`; user enters in `AdminOtpDialog`; hashed OTP in `systemOtp` with TTL.

**Q: What tests exist?**  
`ledger_calculator_test.dart` (business math), `widget_test.dart` (login smoke).

**Q: What would you improve next?**  
Riverpod state management, global search, plot edit screen, plot payment PDF receipts (see PRODUCT_ROADMAP.md).

---

## 12. Files to name-drop (shows you know the codebase)

| Area | File |
|------|------|
| Entry + routing | `main.dart`, `auth_gate.dart` |
| Paths | `firestore_paths.dart` |
| Ledger math | `ledger_calculator.dart` |
| Payments | `customer_service.dart` |
| Cache | `app_cache.dart` |
| Team | `team_service.dart`, `manage_team_screen.dart` |
| Backup UI | `backup_settings_screen.dart` |
| Server | `functions/index.js` |
| Rules | `firestore.rules`, `storage.rules` |

---

## 13. One-minute closing

“I built Property Manager as a **Flutter + Firebase** operations tool for property dealers: **Firestore** for structured data, **Storage** for documents, **Cloud Functions** for admin security (team, OTP, backups), and **role-based UI** so staff only see what they need. Core challenges I handled include **ledger interest replay**, **overpayment** semantics, **web document downloads** with CORS, and **performance** via caching — all documented in the repo’s README, ARCHITECTURE, and USER_MANUAL.”

---

**Related docs:** [README.md](README.md) · [ARCHITECTURE.md](ARCHITECTURE.md) · [USER_MANUAL.md](USER_MANUAL.md) · [INSTRUCTIONS.md](INSTRUCTIONS.md)
