# AI Agent Development Guide

This file helps AI coding assistants understand the current system and
how to safely extend it.

## Project Type

Flutter + Firebase property management application (V1 operational
version).

## Current Functional Scope

- Authentication with role-based behavior (admin/staff)
- Site -> Plot -> Customer management flow
- Customer payment tracking under plot customers
- Customer document handling (upload, storage, preview)
- Finance module for lending and borrowing with installments
- Basic analytics, PDF export, and backup utilities

## Current Data Reality

Primary hierarchy:

- `sites/{siteId}/plots/{plotId}/customer/{customerId}/payments/{paymentId}`

Ledger hierarchy:

- `ledger/master/lending/{loanId}/installments/{installmentId}`
- `ledger/master/borrowing/{borrowId}/installments/{installmentId}`

Auth/user roles:

- `users/{uid}` (role is used in app routing and permissions behavior)

## Assistant Priorities

- Keep architecture maintainable and modular
- Prefer service-layer logic over direct Firebase calls in screens
- Preserve backward compatibility with existing Firestore collections
- Avoid destructive schema changes without migration plan
- Keep queries scalable (indexes, pagination where needed)

## V2 Direction

- Stronger domain model and cleaner layering
- Unified customer/tenant profile with full transaction history
- Better search, receipts, analytics, and notifications
- SaaS-readiness with role and multi-property improvements
