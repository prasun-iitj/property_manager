# Changelog

All notable changes to **Property Manager** are documented here.

Format based on [Keep a Changelog](https://keepachangelog.com/).

---

## [1.2.0] — 2026-05-19

### Added

- **Team management** (admin): Manage Team screen, create staff/admin, enable/disable users, promote to admin with OTP
- **Email OTP** for sensitive admin actions (Cloud Functions + nodemailer/SMTP; replaces SMS/Twilio approach)
- **Cloud Firestore backup**: manual + scheduled daily 2:00 AM Asia/Kolkata → Storage `backups/{timestamp}/`; history in `backupHistory`
- **Cloud Functions** (`functions/`, region `asia-south1`): `createTeamMember`, `createAdminTeamMember`, `requestAdminOtp`, `updateTeamMemberRole`, `enableTeamMember`, `disableTeamMember`, `registerSuperAdminEmail`, `runBackupNow`, `scheduledFirestoreBackup`, `updateBackupSettings`
- **App-wide performance cache** (`AppCache`, ~60s TTL) with stale-while-revalidate on navigation
- **Firestore aggregate helpers** for parallel reads on dashboard/reports
- **Redesigned login screen** (gradient, animations, validation, feature chips)
- **Role access banner** for staff on Property Hub
- **Admin OTP dialog** widget; **Backup settings** screen
- Firestore: `config/system`, `backupHistory`, `systemOtp` collections
- **Interview prep doc**: `INTERVIEW_PREP.md` (layman + technical revision guide)
- Custom domain setup docs (DuckDNS `mayurproperty.duckdns.org`) in `INSTRUCTIONS.md`
- WhatsApp launcher utilities (web vs mobile); external URL helpers for web

### Changed

- `auth_gate.dart`: block unregistered Google users; route by `users/{uid}.role`
- `firestore.rules` / `storage.rules`: config, backup history, team-related restrictions
- `firebase.json`: functions + hosting configuration
- Web deploy uses `--no-web-resources-cdn` for reliable PWA loading
- Cupertino-style page transitions on supported platforms
- Documentation overhaul across all `.md` files

### Fixed

- Dashboard zeros (collectionGroup rules for `payments` / `installments`)
- Android/web black screen (CanvasKit CDN bypass, `index.html` / manifest updates)
- Mobile layout and back-navigation slowness (caching + background refresh)
- iPhone WhatsApp links (platform-specific URL launcher)
- Functions syntax and missing `firestore_paths` constants restored

---

## [1.1.0] — 2026-05-18

### 🤖 Built with Cursor

**This release was designed, implemented, and documented with [Cursor](https://cursor.com)** (AI-assisted IDE).  
Branch: `feature/v2-upgrade` · Tag: `v1.1.0-cursor`

Major work in this cycle was done through Cursor Agent sessions, including architecture hardening, UI upgrades, ledger math, document handling on web, and full documentation refresh.

### Added

- Three-zone **Admin Dashboard** (Property / Finance & Ledger / Insights)
- **Property Hub** with site analytics, search, and rich plot cards
- **Insights Hub** with collection charts and top-sites ranking
- **Ledger dashboard** interactive monthly cash-flow chart
- Unified **ledger detail** screen with installment replay and overpayment UI
- **Property analytics** service and per-customer payment charts
- Document preview/download fixes for web (Firebase SDK + blob download)
- Unique **plot number** validation per site
- **Payment overpayment** on plots (negative balance allowed)
- `firestore.rules`, `storage.rules`, `cors.json` templates
- Full documentation set (`USER_MANUAL.md`, updated README, ARCHITECTURE, etc.)
- Ledger calculator unit tests

### Changed

- Ledger path canonicalized to `ledger/data` (not `ledger/master`)
- Services layer expanded (`customer`, `plot`, `site`, `dashboard`, `ledger`, `search`, …)
- EMI check no longer blocks app startup
- Auth routing consolidated in `AuthGate`

### Fixed

- Ledger remaining balance no longer clamped to zero on overpayment
- Duplicate plot names blocked on create
- Web document CORS / Dio fallback issues addressed
- Stale widget test replaced with login smoke test

---

## [1.0.0] — Initial operational release

- Firebase Auth, sites/plots/customers, payments, documents
- Lending/borrowing ledger with installments
- Role-based admin/staff routing
