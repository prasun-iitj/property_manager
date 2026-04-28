# Copilot Instructions

This repository uses Flutter + Firebase.

Copilot should follow:

Architecture:

- models
- services
- screens
- widgets

Rules:

- Prefer service/repository layer for Firestore operations.
- Minimize direct Firestore calls inside screen widgets.
- Write modular and reusable code.
- Keep changes backward-compatible with existing V1 schema unless a
  migration is explicitly provided.

Current active Firestore paths in V1:

- `sites/{siteId}/plots/{plotId}/customer/{customerId}/payments/{paymentId}`
- `ledger/master/lending/{loanId}/installments/{installmentId}`
- `ledger/master/borrowing/{borrowId}/installments/{installmentId}`
- `users/{uid}` for role-based behavior

Preferred state management for new features:

- Provider or Riverpod

When generating UI:

- Use reusable widgets
- Avoid long deeply nested widget trees
- Keep validation and async error states explicit
