# Developer Instructions

How to work on the **Property Manager** codebase (v1.2 operational).

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
| Dashboard | `dashboard_screen` | `dashboard_service`, `app_cache` |
| Property | `site_list`, `plot_list`, `customer_detail`, `add_*` | `site_service`, `plot_service`, `customer_service`, `property_analytics_service`, `search_service` |
| Documents | `document_upload`, `document_preview` | `document_service`, `storage_service` |
| Ledger | `ledger/*` | `ledger_service`, `backup_service`, `pdf_service` |
| Insights | `reports_screen` | `dashboard_service`, `property_analytics_service` |
| Admin | `admin/manage_team`, `admin/backup_settings`, `admin/team_member_form` | `team_service` |
| System | — | `notification_service`, `emi_checker`, `inactivity_service`, `app_cache` |
| Server | — | `functions/index.js` (callable + scheduled) |

---

## 3. Canonical Firestore paths

Always use `lib/constants/firestore_paths.dart`:

```dart
sites / plots / customer / details / payments | documents
ledger / data / lending | borrowing / installments
users
config / system
backupHistory
```

---

## Free custom URL: `mayurproperty.duckdns.org`

### Step 1 — DuckDNS (IP)

1. Log in at [duckdns.org](https://www.duckdns.org).
2. Subdomain **mayurproperty** → set **current IP** to `199.36.158.100` → **update ip**.
3. Copy your **token** from the top of the DuckDNS page (you need it for TXT in step 3).

### Step 2 — Firebase Hosting

1. Open [Hosting](https://console.firebase.google.com/project/propertymanagerapp-c4961/hosting).
2. **Add custom domain** → enter `mayurproperty.duckdns.org` → Continue.
3. Firebase shows a **TXT** record (for verification) and **A** records. Keep this tab open.

### Step 3 — DuckDNS TXT (required)

DuckDNS does not have a TXT box in the UI. Set it with their API (replace `YOUR_TOKEN` and `TXT_VALUE_FROM_FIREBASE`):

```text
https://www.duckdns.org/update?domains=mayurproperty&token=YOUR_TOKEN&txt=TXT_VALUE_FROM_FIREBASE
```

Paste that URL in your browser; you should see `OK`. Wait 5–15 minutes, then click **Verify** in Firebase.

Reference: [DuckDNS TXT via API](https://pacbard.duckdns.org/articles/202310-txt-record-on-duckdns/)

### Step 4 — Firebase Auth (required for login)

1. [Authentication → Settings → Authorized domains](https://console.firebase.google.com/project/propertymanagerapp-c4961/authentication/settings).
2. **Add domain** → `mayurproperty.duckdns.org`.

Without this, email/Google login on the custom URL will be blocked.

### Step 5 — Wait for SSL

Status should change from **Needs setup** → **Connected** (often 15 minutes–24 hours). Then open:

**https://mayurproperty.duckdns.org**

### Optional — Make it primary

In Hosting → custom domain → set `mayurproperty.duckdns.org` as **primary** so the old `*.web.app` link redirects to DuckDNS.

---

## Team management & cloud backup (admin)

### One-time Cloud setup

1. Upgrade Firebase project to **Blaze** (required for Cloud Functions + scheduled jobs).
2. Install function dependencies:
   ```bash
   cd functions && npm install && cd ..
   ```
3. Configure **email OTP** (free with Gmail) — in [Google Cloud Console](https://console.cloud.google.com/functions/list?project=propertymanagerapp-c4961) → each function → **Environment variables** (or project defaults):
   - `SMTP_USER` — your Gmail address (e.g. `you@gmail.com`)
   - `SMTP_PASS` — [Gmail App Password](https://myaccount.google.com/apppasswords) (not your normal password)
   - Optional: `SMTP_HOST` (default `smtp.gmail.com`), `SMTP_PORT` (default `587`), `SMTP_FROM` (defaults to `SMTP_USER`)
4. Deploy:
   ```bash
   firebase deploy --only functions,firestore:rules,storage
   flutter build web --release --no-web-resources-cdn
   firebase deploy --only hosting
   ```

### In-app: super admin email (OTP)

1. Sign in as **admin** → dashboard toolbar → **Manage team** (people icon).
2. Enter the super admin **email** (or tap **Use my current login email**) and save.
3. All **new admin** accounts and **promote to admin** actions email a 6-digit code to that address (check spam if needed).

### Roles

| Role | Access |
|------|--------|
| `admin` | Full dashboard, team, backup, property, ledger |
| `staff` | Property Hub only |

User records live in `users/{uid}`; writes go through Cloud Functions only.

### Cloud backup

- **Cloud backup** screen (upload icon on dashboard): toggle daily backup, run manual backup.
- Scheduled job: **2:00 AM Asia/Kolkata** → JSON export to Storage under `backups/{timestamp}/firestore-export.json`.
- History in `backupHistory` collection.

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

## 8. Performance (AppCache)

- `lib/services/app_cache.dart` — default TTL ~60 seconds  
- Services should use cache keys per screen (site list, plot list, dashboard stats, etc.)  
- Pattern: return cached immediately → fetch in background → update cache  
- Invalidate or shorten TTL when user performs a write (payment, add plot, etc.)  
- Do not cache sensitive auth tokens — only Firestore aggregate results  

---

## 9. Deploy checklist

1. `flutter build web --release --no-web-resources-cdn`  
2. `firebase deploy --only hosting`  
3. `firebase deploy --only functions,firestore:rules,storage`  
4. Set `SMTP_USER` / `SMTP_PASS` on functions for email OTP  
5. Apply Storage CORS for web (`cors.json`) if document preview/download fails  
6. Verify `users/{adminUid}.role == "admin"` in Firestore  
7. Register super-admin email in app (Manage team) before creating new admins  

---

## 10. Completed V2 items (partial)

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
- Team management + email OTP + cloud backup (Cloud Functions)  
- AppCache + navigation performance  
- Redesigned login screen  
- `INTERVIEW_PREP.md` for project explanation  

---

## 11. Remaining V2 priorities

- Migrate remaining screen-level Firestore calls to services  
- Global search across sites  
- Plot edit screen  
- PDF receipt for plot payments  
- Riverpod state management  
- Expand widget/integration tests  
- Unify document paths (remove legacy `customers/` dependency)

See `PRODUCT_ROADMAP.md`.

---

## 12. Documentation to keep in sync

When changing behavior, update:

| File | When |
|------|------|
| `USER_MANUAL.md` | User-visible flow or rules |
| `DATABASE_SCHEMA.md` | Fields, paths, rules |
| `ARCHITECTURE.md` | Services, architecture, flows |
| `README.md` | Overview, setup, feature list |
| `CHANGELOG.md` | Every release |
| `INTERVIEW_PREP.md` | Stack/flow changes for interview narrative |
| `AGENT.md` / `copilot-instructions.md` | AI assistant context |
