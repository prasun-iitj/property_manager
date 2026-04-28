# Property Manager App

A Flutter + Firebase application for property/customer management,
payment tracking, document handling, and lending/borrowing ledger
operations.

## Current Product Scope (V1)

This version is focused on practical daily operations for a single
business owner/team:

- Role-based login (admin and staff)
- Site and plot management
- Customer management under each plot
- Customer payment history
- Document upload and preview support
- Separate lending and borrowing ledger module
- Basic dashboard stats and finance analytics
- PDF generation and CSV backup/export helpers

## Tech Stack

- Flutter (project supports web, Android, iOS, desktop targets)
- Firebase Authentication
- Cloud Firestore
- Firebase Storage
- Firebase Hosting (for web deployment)
- Local notifications (`flutter_local_notifications`)

## Current Firestore Structure (as implemented)

Main property workflow:

- `sites/{siteId}`
  - `plots/{plotId}`
    - `customer/{customerId}`
      - `payments/{paymentId}`

Ledger workflow:

- `ledger/master`
  - `lending/{loanId}`
    - `installments/{installmentId}`
  - `borrowing/{borrowId}`
    - `installments/{installmentId}`

Auth/roles:

- `users/{uid}` with role fields used for access behavior

Documents:

- Customer documents are managed via Firestore + Firebase Storage through
  document services and upload screens.

## Core App Modules

- `lib/main.dart` - bootstrap, Firebase init, notification init
- `lib/auth_gate.dart` - auth state routing
- `lib/screens/` - UI modules and navigation
- `lib/screens/ledger/` - lending/borrowing flows and analytics
- `lib/services/` - reusable Firebase/storage/pdf/backup/notification logic
- `lib/models/` - data models
- `lib/widgets/` - shared UI widgets

## Run Locally

1. Install Flutter SDK
2. Clone repository
3. Run `flutter pub get`
4. Configure Firebase project and platform options
5. Run web: `flutter run -d chrome`

You can also run mobile/desktop targets if your environment is set up.

## Build and Deploy (Web)

- Build: `flutter build web`
- Deploy: `firebase deploy`
