# Firestore Database Schema (Current V1 Reality)

Property Manager App - implemented Firestore structure

Maintainer: Prasun Kumar Tripathi

This document reflects the schema currently used by the running codebase.
It replaces older tenant-only examples that no longer match the app flow.

## General Rules

- Use document IDs as primary identifiers.
- Store timestamps with `FieldValue.serverTimestamp()` wherever possible.
- Keep naming consistent before introducing V2 migrations.
- Do not rename existing collections in-place without migration scripts.

## Core Operational Hierarchy (Implemented)

### Sites

- Collection: `sites`
- Document: `{siteId}`
- Typical fields (from UI flows): site metadata such as name/location and
  creation timestamp.

### Plots Under Site

- Subcollection: `sites/{siteId}/plots`
- Document: `{plotId}`
- Typical fields: plot number/name, size, status, and context used by
  plot/customer screens.

### Customers Under Plot

- Subcollection: `sites/{siteId}/plots/{plotId}/customer`
- Document: `{customerId}`
- Typical fields used in screens: customer identity/contact and deal or
  installment context.

### Payments Under Customer

- Subcollection:
  `sites/{siteId}/plots/{plotId}/customer/{customerId}/payments`
- Document: `{paymentId}`
- Typical fields: amount, date, mode/notes, and calculated remaining
  details shown in customer/payment screens.

## Ledger Domain (Implemented)

Top-level container used in code:

- `ledger/master`

Subcollections:

- `ledger/master/lending/{loanId}`
- `ledger/master/borrowing/{borrowId}`

Installments:

- `ledger/master/lending/{loanId}/installments/{installmentId}`
- `ledger/master/borrowing/{borrowId}/installments/{installmentId}`

Typical fields include principal/amount, interest, dates, paid amount,
and status metadata used by dashboard, detail, and analytics screens.

## User and Access Data

- Collection: `users`
- Document: `{uid}`
- Important field: `role` (for example `admin` or `staff`) used for app
  routing and action-level access behavior.

## Documents

Document features are implemented through document and storage services.
Current code references a customer-document path under `customers` for the
document module, while customer profile data also exists under nested
`sites/.../customer/...` paths. This is a known area to unify in V2.

## Known Schema Inconsistencies to Fix in V2

- `customer` (singular) is used in site/plot flow; document service uses
  `customers` (plural) path conventions.
- Data definitions are implied by forms/screens but not fully centralized
  as typed models for every entity.
- Legacy docs referenced `tenants` as the main root collection, which is
  not the primary active structure in current code.

## Query Guidelines

- Use pagination and limits for list pages.
- Add indexes for frequent filters/sorts (site, plot, date, role, status).
- Avoid scanning full subcollections for analytics once data grows.

## Security Guidelines (Current + Target)

Current behavior is role-aware at app level. V2 should align Firestore
rules with the same role model:

- Admin: full operational access
- Staff/Manager: limited write scope
- Viewer (future): read-only access
