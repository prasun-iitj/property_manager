# Property Manager — User Manual

**Version:** 1.1.0 (operational)  
**Maintainer:** Prasun Kumar Tripathi  
**Platforms:** Web (Chrome recommended), Android, iOS, Windows, macOS  

> **Note:** This version of the app and its user manual were updated with **[Cursor](https://cursor.com)** AI-assisted development (release tag `v1.1.0-cursor`).

---

## 1. What this application is

**Property Manager** is a business operations app for property dealers and small land developers. It helps you:

- Manage **sites** (projects/colonies) and **plots** within each site
- Track **customers** who buy plots, their **payments**, and **documents**
- Run a separate **money ledger** for personal **lending** and **borrowing** (outside plot sales)
- View **dashboards**, **reports**, and **analytics** in one place

The app uses **Firebase** (cloud login + database). Your data syncs when you are online and signed in.

---

## 2. Who can use the app

| Role | After login you see | Typical permissions |
|------|---------------------|---------------------|
| **admin** | Three-zone **Admin Dashboard** | Full access: sites, plots, customers, payments, documents, ledger, delete site (with password), backup |
| **staff** | **Property Hub** (site list) directly | Operational access: customers, payments, documents, ledger; cannot delete sites |

Roles are stored in Firestore `users/{your-uid}.role`. Ask an admin to set your role.

---

## 3. Application flow (navigation map)

```
Login
  │
  ├─ admin ──► Admin Dashboard (3 workspaces)
  │              ├─ Property (blue) ──► Property Hub ──► Plots ──► Customer
  │              ├─ Finance & Ledger (teal) ──► Ledger Dashboard / Lending / Borrowing
  │              └─ Insights (purple) ──► Insights Hub (reports & charts)
  │
  └─ staff ──► Property Hub ──► Plots ──► Customer
```

### Property path (plot sales)

1. **Property Hub** — list all sites with occupancy and outstanding totals  
2. Tap a **site** → **Plot list** with filters (All / With customer / Vacant / EMI due)  
3. Tap a **plot** → **Customer detail** (or add customer if vacant)  
4. From customer: **Add Payment**, **Documents**, call customer  

### Finance path (ledger)

1. From dashboard **Finance & Ledger** zone or **Ledger Dashboard**  
2. **Lending** — money you gave out (collecting back)  
3. **Borrowing** — money you took in (paying back)  
4. Open a loan → view installments, add payment, see balance (can go **negative** if overpaid)

### Insights path

1. **Insights Hub** — property collections chart, top sites by outstanding, ledger snapshot  
2. Links to ledger dashboard, analytics, and property hub  

---

## 4. Module guide (features)

### 4.1 Login & security

- Sign in with email/password (Firebase Auth)
- **Inactivity timer** — session attention on user activity (tap/scroll resets)
- **Logout** — top-right on dashboard or app bar where available
- **EMI check** runs once after login (background reminder for overdue plot EMIs)

### 4.2 Admin Dashboard

Three color-coded workspaces on one screen (desktop: side by side; mobile: stacked):

| Zone | Color | Shows | Actions |
|------|-------|-------|---------|
| Property | Blue | Today/month collection, plot outstanding, payment count | Property Hub |
| Finance & Ledger | Teal | Lent/owed balances, interest earned/paid | Ledger dashboard, Lending, Borrowing lists |
| Insights | Purple | Cross-summary metrics | Open reports |

Tap a zone header or its buttons to navigate.

### 4.3 Property Hub (sites)

- **Overview banner**: sites count, plots, occupancy %, outstanding, EMI due count  
- **Search** sites by name or location  
- **Site card**: plots sold, progress bar, outstanding  
- **Menu**: Search customers, Edit site, Delete site (admin + password re-auth)  
- **+** Add new site  

### 4.4 Plot list (per site)

- **Stats strip**: total plots, sold, vacant, EMI due, site outstanding  
- **Search** by plot number or customer name  
- **Filters**: All, With customer, Vacant, EMI due  
- **Duplicate plot numbers** are blocked when adding; existing duplicates show an orange warning  
- Tap plot → customer screen  

### 4.5 Add plot

- Enter **plot number** (must be **unique** within the site)  
- Enter **total price**  
- Cannot save if the same plot number already exists  

### 4.6 Customer (plot buyer)

- Profile: name, phone, call button  
- **Payment progress** card: % repaid, paid vs balance vs total price  
- **Overpayment**: if paid more than price, shows **“Overpaid ₹ …”** (negative balance allowed)  
- **Plot collections chart** — monthly payments for this customer (tap months for detail)  
- **EMI day** and **next EMI**; red alert if EMI overdue  
- **Documents** button  
- **Add Payment** (FAB)  
- Admin: edit customer, delete customer  

### 4.7 Add payment (plot)

- Shows current **plot balance** (price, paid, due or overpaid)  
- Enter amount — **overpayment allowed** (balance can go negative)  
- Live preview: remaining or overpaid after this payment  
- Date and mode: Cash / UPI / Bank  
- Optional **WhatsApp** message to customer after save  

### 4.8 Documents

Upload types: **Aadhar**, **PAN**, **Registry**, **Other**

- **Upload file** — pick PDF/image from device  
- **Camera** — capture image (mobile); on web uses file/gallery if camera blocked  
- **Uploaded list**: tap to **preview**, purple **rename**, blue **download**, red **delete**  
- **Other document**: after upload, prompted to **name** the document  
- **Preview**: in-app PDF/image viewer; on web may use embedded viewer or “Open in browser”  
- **Download**: saves file to device/downloads (web: browser download)  

### 4.9 Customer search (per site)

- Search by name or phone (live after 2 characters)  
- Shows plot, outstanding, payment progress bar  
- Tap result → customer detail  

### 4.10 Money ledger

**Separate from plot sales** — tracks informal loans.

#### Lending (money you lent)

- Add loan: person name, principal, monthly interest %  
- Add **installments** (payments received)  
- Balance = remaining principal after all payments (chronological replay)  
- **Overpayment** allowed → negative balance shown as overpaid  

#### Borrowing (money you borrowed)

- Same structure; you record repayments you make  

#### Ledger dashboard

- Overview cards: lent, borrowed, net, interest  
- **Interactive chart**: monthly cash flow by year; modes Combined / Lending in / Borrowing out / Net  
- Tap a month for interest vs principal breakdown  
- Links to lending/borrowing lists and **backup export**  

#### Ledger payment rules

1. Sort installments by **date** (oldest first)  
2. Each period: interest due = remaining principal × monthly rate %  
3. Payment applies to **interest first**, then **principal**  
4. Balance may go **negative** (overpaid)  

### 4.11 Insights Hub (reports)

- Business snapshot: property due vs ledger net  
- Property metrics panel  
- **Collection trend chart** (by year, tap months)  
- Top sites by outstanding  
- Ledger snapshot panel  
- Quick links to ledger and property hub  

### 4.12 Backup (ledger)

- From Ledger Dashboard → **Backup**  
- Exports ledger data (CSV-style) for offline records  

### 4.13 Notifications

- Local notifications for **EMI due** on plot customers (checked after login)  
- Requires notification permission on mobile/desktop  

---

## 5. Business rules summary

| Area | Rule |
|------|------|
| Plot numbers | Unique per site (case-insensitive) |
| Plot payments | Overpayment allowed; negative `remaining` = credit/overpaid |
| Ledger installments | Interest-first; chronological replay; overpayment allowed |
| Documents | Stored in Firebase Storage; metadata in Firestore |
| Site delete | Admin only; requires password re-entry; deletes all plots/customers |

---

## 6. Tips & troubleshooting

| Issue | What to try |
|-------|-------------|
| Document preview fails on web | Use **Open in browser**; apply Storage CORS (`cors.json` + `gsutil`) |
| Download opens instead of saving | Hot restart app; latest build uses blob download |
| Cannot add duplicate plot | Rename or delete the other plot with same number |
| Payment blocked | Fixed — overpayments now allowed |
| Staff sees no dashboard | Expected — staff goes to Property Hub |
| Ledger balance looks wrong | Open loan detail — balances recalculate from all installments by date |

---

## 7. Keyboard / web shortcuts

- **Hot restart** (dev): press `R` in terminal where `flutter run` is running  
- **Refresh** stats: refresh icon on dashboard and list screens  

---

## 8. Related documentation

- `README.md` — technical overview and setup  
- `ARCHITECTURE.md` — code structure and services  
- `DATABASE_SCHEMA.md` — Firestore fields and paths  
- `INSTRUCTIONS.md` — developer conventions  
