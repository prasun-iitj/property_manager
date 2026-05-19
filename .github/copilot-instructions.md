# Copilot / GitHub Copilot Instructions

Repository: **Property Manager** — Flutter + Firebase property, finance, and admin platform.

**Version:** 1.2 · **Web:** https://propertymanagerapp-c4961.web.app

---

## Architecture

```
lib/
  models/       # Typed data objects (incl. team_member)
  services/     # Firestore, Storage, analytics, app_cache, team_service
  screens/      # UI + navigation
  screens/admin/  # manage_team, backup_settings
  screens/ledger/
  widgets/      # dashboard_zone, admin_otp_dialog, role_access_banner
  utils/        # ledger_calculator, file_saver, whatsapp, external_url
  constants/    # firestore_paths.dart
functions/
  index.js      # Callable + scheduled (asia-south1)
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
8. **Team/backup/OTP** — implement in `functions/index.js`; Flutter calls via `TeamService` callables only.  
9. Use **AppCache** for list/dashboard reads; refresh after writes.  
10. Web build: `flutter build web --release --no-web-resources-cdn`.

---

## Active Firestore paths (v1.2)

```
sites/{siteId}/plots/{plotId}/customer/details
  payments/{paymentId}
  documents/{documentId}

ledger/data/lending/{loanId}/installments/{installmentId}
ledger/data/borrowing/{borrowId}/installments/{installmentId}

users/{uid}   → role: admin | staff
config/system
backupHistory/{id}
systemOtp/{id}   (server only)
```

**Do not use:** `ledger/master/...` (deprecated)

**Storage files:** `customers/{siteId}_{plotId}/{fileName}`  
**Backups:** `backups/{timestamp}/firestore-export.json`

---

## Roles

| Role | Entry screen |
|------|----------------|
| admin | DashboardScreen (Property / Finance / Insights + team + backup) |
| staff | SiteListScreen |

---

## Cloud Functions (summary)

- Region: `asia-south1`  
- Team: `createTeamMember`, `createAdminTeamMember`, `updateTeamMemberRole`, enable/disable  
- OTP: `requestAdminOtp` (email via nodemailer; `SMTP_USER`, `SMTP_PASS`)  
- Backup: `runBackupNow`, `scheduledFirestoreBackup` (2 AM IST), `updateBackupSettings`  

---

## Docs to update when changing behavior

- `USER_MANUAL.md` — user-visible  
- `DATABASE_SCHEMA.md` — schema  
- `ARCHITECTURE.md` — design  
- `README.md`, `CHANGELOG.md`  
- `INTERVIEW_PREP.md` — if stack/flow narrative changes  

See `AGENT.md` and `INSTRUCTIONS.md` for full guidelines.
