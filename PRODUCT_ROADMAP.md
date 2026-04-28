# Product Roadmap

Property Manager App - Product evolution plan

Maintainer: Prasun Kumar Tripathi

This roadmap is aligned to the real current implementation and defines
what should be improved in V2+.

## Vision

Build a reliable property and finance operations product that can evolve
into a multi-property SaaS platform.

## Version 1 (Current Implemented System)

Status: implemented and usable

### What exists today

- Auth with role-based routing (`users` role check)
- Site list and plot management
- Customer records under plots
- Payment entries under each customer
- Customer-focused document workflows
- Separate lending/borrowing ledger with installments
- Ledger analytics, PDF and backup/export utilities
- Notification utilities and EMI reminder checks

### Current technical base

- Flutter app targeting web first (also includes Android/iOS/desktop
  project setup)
- Firebase Auth, Firestore, Storage
- Local notification support
- PDF creation/printing and file sharing helpers

### Current limitations

- Architecture layering is inconsistent in some modules
- Schema naming inconsistency (`customer` vs `customers`) in document flow
- Search is limited and not global
- Receipt and statement flows are not fully standardized
- Test coverage is minimal

## Version 2 (Next Upgrade - Target)

Goal: stabilize and professionalize the product without breaking existing
data.

### 1) Data and model standardization

- Finalize canonical entity naming and field contracts
- Unify customer/document references
- Add migration-safe adapters where old paths exist

### 2) Architecture hardening

- Move Firebase logic from screens into service/repository layers
- Introduce clear state management approach (Provider or Riverpod)
- Standardize error handling, loading, and validation patterns

### 3) Customer and payment experience

- Rich customer profile page (details + payment timeline + docs)
- Standardized outstanding balance and installment logic
- Better payment entry UX with receipt-first workflow

### 4) Search and reporting

- Global search by customer name, phone, site, plot, and ledger
- Better dashboards for collected vs outstanding amounts
- Date-range filters and downloadable statements

### 5) Security and reliability

- Align Firestore rules with app roles
- Index planning and query optimization
- Introduce meaningful unit/widget/service tests

## Version 3 (Scale Phase)

- Multi-property account support
- Strong role matrix (admin/manager/viewer)
- Tenant/customer self-service portal concepts
- Online payment gateway integrations (Razorpay/Stripe/UPI)

## Version 4 (Intelligence Phase)

- AI-assisted cash flow prediction
- Late payment risk scoring
- Smart anomaly detection in transactions
- Recommendation-based operational insights

## Development Guidelines

- Keep UI modular and reusable
- Keep data logic centralized in services/repositories
- Document any schema change before implementation
- Prefer backward-compatible releases with migration notes
