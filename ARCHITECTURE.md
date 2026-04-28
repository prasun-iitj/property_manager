# System Architecture (Current V1)

## High-Level Style

The app currently uses a screen-driven Flutter architecture with service
helpers for Firebase, storage, notifications, export, and document
handling.

Current structure:

- `lib/main.dart` and `lib/auth_gate.dart` for startup/auth routing
- `lib/screens/` for feature UIs and navigation
- `lib/screens/ledger/` for lending/borrowing module
- `lib/services/` for reusable backend/service logic
- `lib/models/` for typed data objects
- `lib/widgets/` for shared UI pieces

## Runtime Flow

1. App initializes Firebase and notification services.
2. Auth stream decides whether to show login or dashboard flow.
3. Logged-in users navigate through site/plot/customer modules.
4. Data is read/written to Firestore, documents to Firebase Storage.
5. Finance module handles lending/borrowing + installment tracking.

## Data Domains

- Property operations:
  - Sites
  - Plots
  - Customers
  - Customer payments
- Finance operations:
  - Lending
  - Borrowing
  - Installments
- Supporting domains:
  - User roles
  - Documents
  - Notifications
  - PDF/backup export

## Current Gaps vs Target Clean Architecture

- Some Firestore logic still exists directly inside screen classes.
- Service usage is not yet fully consistent across all modules.
- A duplicate backup service file exists in screens and services.

## Recommended V2 Architectural Direction

- Enforce UI -> service/repository -> Firebase layering consistently
- Introduce stronger domain models for each collection type
- Add predictable state management (Provider/Riverpod)
- Standardize error handling and loading states
