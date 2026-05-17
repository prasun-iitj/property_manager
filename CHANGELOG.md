# Changelog

All notable changes to **Property Manager** are documented here.

Format based on [Keep a Changelog](https://keepachangelog.com/).

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
