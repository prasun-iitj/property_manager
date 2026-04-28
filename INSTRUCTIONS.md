# Developer Instructions

This document describes how to continue development against the current
implemented V1 codebase.

## Product Goal (Current)

Provide a practical property and finance management app for small
landlords/property teams, with role-based access and Firebase-backed data.

## Current Modules

- Authentication and role-based routing
- Dashboard and navigation hub
- Site management
- Plot management under sites
- Customer management under plots
- Customer payment tracking
- Document upload/preview/download
- Lending/Borrowing ledger with installments
- Ledger analytics and export utilities

## Active Firestore Collections

Primary workflow:

- `sites/{siteId}/plots/{plotId}/customer/{customerId}/payments/{paymentId}`

Ledger workflow:

- `ledger/master/lending/{loanId}/installments/{installmentId}`
- `ledger/master/borrowing/{borrowId}/installments/{installmentId}`

Access control:

- `users/{uid}` with role values consumed by the app.

## Coding Rules

- Keep Firebase/data logic out of large UI widgets where possible.
- Prefer service classes for reusable operations.
- Reuse widgets for repeated UI patterns.
- Preserve existing data paths unless migration is explicitly planned.
- Avoid introducing breaking schema changes without documentation updates.

## Immediate Cleanup Priorities

- Remove/merge duplicate backup service placement.
- Standardize naming (`customer` vs `customers`) for document integration.
- Increase typed model coverage to reduce map-based field errors.

## Version 2 Implementation Goals

- Unified domain model for properties, units, customers, and transactions
- Better separation of presentation, domain, and data layers
- Tenant/customer profile page with full payment + document timeline
- Search across customer, phone, site, plot, and ledger records
- Reliable PDF receipt generation and storage
- Scalable analytics and notification workflows
