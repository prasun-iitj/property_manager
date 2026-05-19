# Firestore & Storage Schema

**Property Manager App** — canonical data model (v1.2)  
**Maintainer:** Prasun Kumar Tripathi  
**Source of truth for paths:** `lib/constants/firestore_paths.dart`

---

## 1. Overview

| Store | Used for |
|-------|----------|
| **Cloud Firestore** | Structured data: sites, plots, customers, payments, documents metadata, ledger, users |
| **Firebase Storage** | Binary files: customer documents (PDF, images) |
| **Firebase Auth** | User identity (UID links to `users` collection) |

---

## 2. Property hierarchy

### 2.1 Sites

**Path:** `sites/{siteId}`

| Field | Type | Description |
|-------|------|-------------|
| `name` | string | Site / project name |
| `location` | string | Location label |
| `createdAt` | timestamp | Server timestamp on create |

### 2.2 Plots

**Path:** `sites/{siteId}/plots/{plotId}`

| Field | Type | Description |
|-------|------|-------------|
| `plotNumber` | string | **Unique per site** (app-enforced) |
| `totalPrice` | number | Plot sale price (₹) |
| `status` | string | e.g. `available` |
| `createdAt` | timestamp | Optional |

**Business rule:** `PlotService.normalizePlotNumber()` prevents duplicates.

### 2.3 Customer (one per plot)

**Path:** `sites/{siteId}/plots/{plotId}/customer/details`  
**Document ID:** always `details` (constant `FirestorePaths.customerDetailsId`)

| Field | Type | Description |
|-------|------|-------------|
| `name` | string | Customer name |
| `phone` | string | Mobile (WhatsApp link after payment) |
| `totalPrice` | number | Agreed plot price |
| `totalPaid` | number | Sum of all payments |
| `remaining` | number | `totalPrice - totalPaid` (may be **negative** = overpaid) |
| `emiDay` | number | Day of month for EMI (1–28, default 5) |
| `nextEmiDate` | timestamp | Next EMI due date |
| `aadharUrl` | string | Optional Storage URL |
| `updatedAt` | timestamp | On save |

### 2.4 Payments

**Path:** `sites/{siteId}/plots/{plotId}/customer/details/payments/{paymentId}`

| Field | Type | Description |
|-------|------|-------------|
| `amount` | number | Payment amount (₹) |
| `date` | timestamp | Payment date |
| `mode` | string | `Cash`, `UPI`, `Bank` |
| `createdAt` | timestamp | Server timestamp |

**Writes:** `CustomerService.addPayment` / `deletePayment` use **Firestore transactions** to update customer totals atomically.

### 2.5 Documents (metadata)

**Path:** `sites/{siteId}/plots/{plotId}/customer/details/documents/{documentId}`

| Field | Type | Description |
|-------|------|-------------|
| `name` | string | Display name (user-renamable) |
| `type` | string | `aadhar`, `pan`, `registry`, `other` |
| `fileUrl` | string | Firebase Storage download URL |
| `fileName` | string | Storage object name (includes extension) |
| `uploadedAt` | string (ISO) | Upload time |

**Storage path:** `customers/{customerId}/{fileName}` where `customerId = {siteId}_{plotId}`.

**Legacy read path:** `customers/{legacyCustomerId}/documents` if v2 collection empty.

---

## 3. Ledger hierarchy

**Container:** `ledger/data` (document id: `data`)

### 3.1 Lending loan

**Path:** `ledger/data/lending/{loanId}`

| Field | Type | Description |
|-------|------|-------------|
| `name` | string | Borrower name (person who owes you) |
| `principal` | number | Original loan amount |
| `rate` | number | Monthly interest rate (percent) |
| `remainingPrincipal` | number | After replay (may be negative) |
| `createdAt` | timestamp | Optional |

### 3.2 Borrowing loan

**Path:** `ledger/data/borrowing/{borrowId}`  
Same field pattern as lending (money you borrowed).

### 3.3 Installments

**Paths:**

- `ledger/data/lending/{loanId}/installments/{installmentId}`
- `ledger/data/borrowing/{borrowId}/installments/{installmentId}`

| Field | Type | Description |
|-------|------|-------------|
| `amount` | number | Payment amount |
| `date` | timestamp | Payment date |
| `interestPaid` | number | Portion to interest (computed on save) |
| `principalPaid` | number | Portion to principal |
| `createdAt` | timestamp | Optional |

**Recalculation:** `LedgerService` replays all installments by date and updates loan `remainingPrincipal`.

> **Deprecated path in old docs:** `ledger/master/...` — not used by current app.

---

## 4. Users & access control

**Path:** `users/{uid}` (Firebase Auth UID)

| Field | Type | Description |
|-------|------|-------------|
| `role` | string | `admin` or `staff` |
| `email` | string | Login email |
| `displayName` | string | Optional display name |
| `disabled` | boolean | `true` if account disabled by admin |
| `createdAt` | timestamp | When user was provisioned |
| `createdBy` | string | Admin UID who created (optional) |

**Writes:** Create/update/disable users via **Cloud Functions** only (not direct client writes except own profile read).

**Routing:**

- `admin` → `DashboardScreen`
- `staff` → `SiteListScreen`

---

## 4.1 System configuration

**Path:** `config/system` (single document)

| Field | Type | Description |
|-------|------|-------------|
| `superAdminEmail` | string | Email that receives OTP for new admin / promote |
| `backupEnabled` | boolean | Daily scheduled backup on/off |
| `updatedAt` | timestamp | Last settings change |

**Writes:** Admin via `updateBackupSettings` / `registerSuperAdminEmail` callable functions.

---

## 4.2 Backup history

**Path:** `backupHistory/{backupId}`

| Field | Type | Description |
|-------|------|-------------|
| `createdAt` | timestamp | Run time |
| `storagePath` | string | e.g. `backups/{timestamp}/firestore-export.json` |
| `status` | string | `success` / `failed` |
| `sizeBytes` | number | Optional export size |
| `triggeredBy` | string | `scheduled` / `manual` / admin uid |

**Storage:** Full JSON export under `backups/{timestamp}/` in default bucket.

---

## 4.3 OTP (server-only)

**Path:** `systemOtp/{otpId}`

| Field | Type | Description |
|-------|------|-------------|
| `hash` | string | SHA-256 of 6-digit code |
| `purpose` | string | e.g. `create_admin`, `promote_admin` |
| `expiresAt` | timestamp | ~10 minute TTL |
| `used` | boolean | Invalid after use |

**Client:** Never reads/writes directly; verified in Cloud Functions.

---

## 5. Collection group queries

| Query | Used by |
|-------|---------|
| `collectionGroup('payments')` | `DashboardService`, `PropertyAnalyticsService` — monthly collections |
| All payments across sites for stats/charts | |

**Index:** May require composite indexes as data grows (Firebase console prompts).

---

## 6. Firebase Storage layout

```
customers/
  {siteId}_{plotId}/
    {type}_{timestamp}.pdf
    {type}_{timestamp}.jpg
    ...

backups/
  {timestamp}/
    firestore-export.json
```

**Content-Type** set from extension: `application/pdf`, `image/jpeg`, `image/png`.

**Security:** `storage.rules` — authenticated users only.

**Web CORS:** Apply `cors.json` to bucket for `getData()` / XHR from localhost.

---

## 7. Security rules summary

See `firestore.rules`:

| Collection | Read | Write |
|------------|------|-------|
| `users/{uid}` | Self | Admin only |
| `sites`, `plots` | Staff+Admin | Admin only |
| `customer`, `payments`, `documents` | Staff+Admin | Staff+Admin |
| `ledger/**` | Staff+Admin | Staff+Admin |
| `customers/**` (legacy) | Staff+Admin | Staff+Admin |
| `config/system` | Admin | Functions / admin callable only |
| `backupHistory` | Admin | Functions write; admin read |
| `systemOtp` | Deny client | Functions only |

Deploy: `firebase deploy --only firestore:rules,storage,functions`

---

## 8. Data consistency rules

| Operation | Consistency |
|-----------|-------------|
| Add/delete plot payment | Transaction on customer + payment doc |
| Add/delete ledger installment | Transaction + full replay |
| Delete site | Batch delete plots, customer subcollections, Storage files |
| Document delete | Firestore doc + Storage file (best effort) |

---

## 9. Migration & legacy notes

| Item | Status |
|------|--------|
| `customers/{id}/documents` | Legacy read only |
| `ledger/master` | Do not use; migrate to `ledger/data` if old data exists |
| Tenant-based schema in old README | Replaced by sites/plots/customer |

---

## 10. Recommended Firestore indexes

Create when Firebase console requests them:

- `documents` ordered by `uploadedAt` descending (per customer)
- `payments` ordered by `date` descending (per customer)
- `collectionGroup(payments)` filtered by `date` range (analytics at scale)

---

## 11. Example document tree

```
sites/abc123
  name: "Green Valley"
  plots/plot456
    plotNumber: "12"
    totalPrice: 1000000
    customer/details
      name: "Ravi"
      totalPrice: 1000000
      totalPaid: 300000
      remaining: 700000
      payments/pay001
        amount: 100000
        date: 2026-03-01
      documents/doc001
        name: "Aadhar Card"
        type: "aadhar"
        fileUrl: "https://firebasestorage.googleapis.com/..."

ledger/data
  lending/loan001
    name: "Amit"
    principal: 20000
    rate: 2
    remainingPrincipal: -80000
    installments/inst001
      amount: 10000
      date: 2026-01-15
      interestPaid: ...
      principalPaid: ...
```
