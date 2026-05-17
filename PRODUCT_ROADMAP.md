# Product Roadmap

**Property Manager App** — evolution plan aligned with the **current codebase** (May 2026).

**Maintainer:** Prasun Kumar Tripathi

---

## Vision

A reliable **property + finance operations** product that can grow into a multi-site SaaS platform for Indian property dealers and small developers.

---

## Version 1 — Operational (current)

**Status:** ✅ Implemented and in active use

### Property module ✅

- [x] Sites list with analytics banner, search  
- [x] Add / edit / delete site (admin, password for delete)  
- [x] Plots per site with filters (vacant, occupied, EMI due)  
- [x] Unique plot number validation per site  
- [x] Customer per plot with EMI tracking  
- [x] Payments with transactional totals  
- [x] **Overpayment** on plots (negative remaining)  
- [x] Documents upload, camera, preview, download, rename  
- [x] Site customer search  
- [x] Per-customer payment chart  

### Finance (ledger) module ✅

- [x] Lending & borrowing lists  
- [x] Loan detail with installment history  
- [x] Interest-first chronological replay  
- [x] Overpayment (negative balance) with UI warnings  
- [x] Live installment preview when adding payment  
- [x] Ledger dashboard with interactive monthly chart  
- [x] Ledger analytics screen  
- [x] CSV backup export  

### Insights & dashboard ✅

- [x] Admin three-zone dashboard (Property / Finance / Insights)  
- [x] Insights Hub with collection chart, top sites, ledger snapshot  
- [x] Property + ledger overview stats  

### Platform ✅

- [x] Firebase Auth + role routing (admin / staff)  
- [x] Firestore + Storage  
- [x] EMI local notifications (post-login check)  
- [x] Inactivity timer  
- [x] Security rules templates  
- [x] Web document handling (iframe fallback, blob download)  
- [x] Unit tests (ledger calculator, login smoke)  

### Known V1 limitations

- Some screens still use direct Firestore access  
- Document Storage uses `{siteId}_{plotId}` while metadata under plot path  
- No global search across all sites  
- No plot edit screen  
- No standardized PDF receipt for plot payments  
- Storage CORS must be configured manually for full web byte-fetch  
- Minimal automated test coverage  

---

## Version 2 — Stabilization (next)

**Goal:** Professional polish without breaking existing Firestore data.

### Data & models

- [ ] Typed models for all entities (ledger loans, installments)  
- [ ] Unify document Storage + Firestore paths  
- [ ] Migration script for any `ledger/master` legacy data  

### Architecture

- [ ] Riverpod or Provider for app state  
- [ ] All Firestore access through services/repositories  
- [ ] Standardized error/loading/empty states  

### Property experience

- [ ] Edit plot (number, price) with duplicate check  
- [ ] PDF payment receipt generation + share  
- [ ] Payment edit history / audit log  

### Search & reporting

- [x] Per-site customer search *(done)*  
- [ ] Global search (name, phone, plot, site)  
- [ ] Date-range filters on reports  
- [ ] Export property collection statement (PDF/CSV)  

### Security & ops

- [x] Firestore rules template *(done — deploy required)*  
- [x] Storage rules template *(done)*  
- [ ] Firestore composite indexes documented and deployed  
- [ ] CI: `flutter analyze` + `flutter test` on PR  

### Quality

- [x] Ledger calculator tests *(done)*  
- [ ] Widget tests for payment flow, plot duplicate validation  
- [ ] Integration test with Firebase emulator  

---

## Version 3 — Scale

- Multi-organization / multi-owner accounts  
- Fine-grained roles (admin, manager, viewer, accountant)  
- Customer portal (view balance, upload docs)  
- Payment gateway (Razorpay / UPI links)  
- Cloud Functions for heavy analytics and scheduled EMI SMS  

---

## Version 4 — Intelligence

- Cash-flow forecasting  
- Late-payment risk scoring  
- Anomaly detection (unusual payments, duplicate entries)  
- AI-assisted collections reminders and insights  

---

## Development principles

1. **Backward compatible** schema changes only with migration notes  
2. **Document** user-visible changes in `USER_MANUAL.md`  
3. **Single source** for paths: `firestore_paths.dart`  
4. **No duplicate** business logic outside `ledger_calculator.dart`  
5. **Web-first** testing for document and dashboard flows  

---

## How to use this roadmap

- Mark items `[x]` in PR descriptions when completing V2 tasks  
- Update **Version 1** section when shipping notable features  
- Do not promise V3/V4 dates until V2 stabilization is complete  
