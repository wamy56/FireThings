# FireThings — Feature Gaps & Future Workflows

**Version:** 1.0
**Date:** April 2026
**Status:** Backlog — pick individual features to implement based on priority and customer demand

**Purpose:** Catalogue feature gaps identified by code review and competitive analysis (vs Uptick, Simpro, FieldEdge, Joblogic) that would meaningfully expand FireThings as a fire safety platform. These are NOT bugs — the existing app is functional without them. They are revenue-generating, retention-improving, or workflow-completing additions.

**How to use this document:** Each feature is **numbered and self-contained**. Pick whichever ones you want to implement, in any order. When you're ready to build one, hand off the relevant section (or the whole doc with a note saying which feature number) to Claude Code. Each feature includes its own data models, services, screens, and integration points.

**Prerequisites:**

- Bug fixes from `BUG_FIXES_AND_HARDENING_SPEC.md` should land first (or in parallel) — several features here assume `LifecycleService` and `AssetTestService` exist
- BS 5839 spec (`BS5839_COMPLIANCE_SPEC.md`) is independent — features below work whether BS 5839 mode is on or off, except where explicitly noted

---

## Feature Index — Highest Impact First

| # | Feature | Impact | Effort | Revenue Lever | Depends On |
|---|---|---|---|---|---|
| 1 | [Recurring & Scheduled Jobs](#1-recurring--scheduled-jobs) | ⭐⭐⭐⭐⭐ | 2 weeks | Service contracts | None |
| 2 | [Customer Portal (Read-Only)](#2-customer-portal-read-only) | ⭐⭐⭐⭐⭐ | 3 weeks | Differentiator | None |
| 3 | [Parts Catalog & Pricebook](#3-parts-catalog--pricebook) | ⭐⭐⭐⭐ | 1 week | Quote speed | None |
| 4 | [Service Contracts & Customer Pricing](#4-service-contracts--customer-pricing) | ⭐⭐⭐⭐ | 2 weeks | Recurring revenue | Feature 1 |
| 5 | [SLA / Response Time Tracking](#5-sla--response-time-tracking) | ⭐⭐⭐⭐ | 1 week | Premium support tier | None |
| 6 | [Site Access & Key Information](#6-site-access--key-information) | ⭐⭐⭐⭐ | 3 days | Time-saving | None |
| 7 | [False Alarm Log & Analysis](#7-false-alarm-log--analysis) | ⭐⭐⭐⭐ | 1 week | BS 5839 requirement | None |
| 8 | [Disablement Register](#8-disablement-register) | ⭐⭐⭐⭐ | 4 days | BS 5839 requirement | None |
| 9 | [Van Stock Management](#9-van-stock-management) | ⭐⭐⭐ | 2 weeks | Inventory tracking | Feature 3 |
| 10 | [Photo Annotation Tool](#10-photo-annotation-tool) | ⭐⭐⭐ | 4 days | UX | None |
| 11 | [Site Photos Beyond Defects](#11-site-photos-beyond-defects) | ⭐⭐⭐ | 3 days | Documentation | None |
| 12 | [Customer Signature on Job Completion](#12-customer-signature-on-job-completion) | ⭐⭐⭐ | 2 days | Proof of work | None |
| 13 | [Engineer Timesheets](#13-engineer-timesheets) | ⭐⭐⭐ | 1 week | Payroll | None |
| 14 | [Multi-Day Jobs](#14-multi-day-jobs) | ⭐⭐⭐ | 1 week | Commissioning support | None |
| 15 | [Install / Commissioning Certificate](#15-install--commissioning-certificate) | ⭐⭐⭐ | 1 week | New build market | BS 5839 spec |
| 16 | [Subcontractor Support](#16-subcontractor-support) | ⭐⭐ | 2 weeks | Specialist work | None |
| 17 | [Email Open Tracking on Quotes](#17-email-open-tracking-on-quotes) | ⭐⭐ | 3 days | Sales follow-up | None |
| 18 | [Equipment Calibration Tracking](#18-equipment-calibration-tracking) | ⭐⭐ | 4 days | Test instrument compliance | None |
| 19 | [Customer Self-Booking](#19-customer-self-booking) | ⭐⭐ | 2 weeks | Lead generation | Feature 2 |
| 20 | [Accounting Software Export](#20-accounting-software-export) | ⭐⭐ | 1-2 weeks per integration | Reduces friction | None |

**Total addressable scope: ~28 weeks if all features built. Pick what matters most to your customers.**

---

## 1. Recurring & Scheduled Jobs

**Why this is #1:** Fire safety is fundamentally a recurring service business. A customer on a quarterly contract should generate 4 visits per year automatically. Currently every visit must be manually created. This is table-stakes for any field service product and the single biggest gap vs. competitors.

The existing `DispatchedJob` model already has a `scheduledDate` field — recurrence builds on top.

### 1.1 Data Models

**File:** `lib/models/recurring_job.dart` (NEW)

```dart
enum RecurrenceFrequency {
  weekly, monthly, quarterly, biAnnual, annual, custom
}

enum RecurrenceEndCondition {
  never, afterCount, untilDate
}

class RecurringJob {
  final String id;
  final String companyId;
  final String? siteId;
  final String? customerId;

  // Job template
  final String title;
  final String description;
  final String jobType;
  final String? systemCategory;
  final int estimatedDurationMinutes;
  final String? defaultEngineerId;
  final String? defaultEngineerName;
  final String priority;

  // Recurrence
  final RecurrenceFrequency frequency;
  final int? customIntervalDays;
  final DateTime startDate;
  final DateTime? nextOccurrenceDate;
  final RecurrenceEndCondition endCondition;
  final int? endAfterCount;
  final DateTime? endUntilDate;
  final int generatedCount;

  // Window for auto-generation (e.g. generate the next visit 30 days before due)
  final int leadTimeDays;

  // Status
  final bool active;
  final DateTime? pausedAt;
  final String? pausedReason;

  final String createdBy;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime lastModifiedAt;
}
```

**Modify:** `lib/models/dispatched_job.dart` — add field:

```dart
final String? recurringJobId;  // points back to the parent recurrence
```

### 1.2 Firestore Structure

`companies/{companyId}/recurring_jobs/{recurringJobId}` — only company users get recurring jobs (solo engineers can use the existing single-shot scheduling).

Indexes:
- `recurring_jobs: companyId + active + nextOccurrenceDate asc`

### 1.3 Service

**File:** `lib/services/recurring_job_service.dart` (NEW)

```dart
class RecurringJobService {
  // CRUD
  Future<RecurringJob> create(RecurringJob job);
  Future<void> update(RecurringJob job);
  Future<void> pause(String id, String reason);
  Future<void> resume(String id);
  Future<void> delete(String id);
  Stream<List<RecurringJob>> getForCompany(String companyId);

  // Generation
  DateTime calculateNextOccurrence(RecurringJob job, DateTime fromDate);
  Future<DispatchedJob?> generateNextOccurrence(RecurringJob job);
  Future<int> generateAllDue();  // Cloud Function calls this
}
```

### 1.4 Cloud Function

**File:** `functions/recurring_job_generator.js` (NEW)

Scheduled to run daily at 02:00:

```js
exports.generateRecurringJobs = functions.pubsub
  .schedule('0 2 * * *')
  .timeZone('Europe/London')
  .onRun(async (context) => {
    const now = admin.firestore.Timestamp.now();
    const cutoff = new Date(Date.now() + 30 * 86400000); // 30 days ahead

    const due = await admin.firestore()
      .collectionGroup('recurring_jobs')
      .where('active', '==', true)
      .where('nextOccurrenceDate', '<=', cutoff)
      .get();

    for (const doc of due.docs) {
      try {
        await generateOccurrence(doc);
      } catch (e) {
        console.error(`Failed to generate occurrence for ${doc.id}:`, e);
      }
    }
  });
```

### 1.5 Screens

**File:** `lib/screens/dispatch/recurring_jobs_screen.dart` (NEW)

List of all recurring jobs. Each card shows:
- Title, site, customer
- Frequency badge (e.g. "Quarterly")
- Next occurrence date
- Engineer assignment
- Active/paused status
- Generated count

Actions: pause/resume, edit, delete (with confirmation showing how many future occurrences will be cancelled).

**File:** `lib/screens/dispatch/create_recurring_job_screen.dart` (NEW)

Form mirrors `create_job_screen.dart` but adds:
- Frequency selector (with "Custom interval in days" option)
- Start date
- End condition (Never / After N occurrences / Until date)
- Lead time slider (1-90 days — how far ahead to generate the visit)

### 1.6 Integration Points

- **Dispatch Dashboard** — add "Recurring" tab alongside "All Jobs" / "Today" / "This Week"
- **Site Detail** — show "Recurring services for this site" section
- **Generated jobs** — when an engineer completes a visit linked to a recurring job, show "Next visit auto-scheduled for [date]" toast

### 1.7 Edge Cases

- Site deleted while recurrence active → pause the recurrence with reason "Site removed", notify dispatcher
- Engineer removed from company → unassign from future occurrences (keep the recurrence active)
- Date math edge cases — use `LifecycleService._addMonthsSafely` from the bug fix spec
- Don't generate duplicates: store the `generatedCount` and `lastGeneratedDate`; check before creating

### 1.8 Testing

- Quarterly recurrence generates 4 jobs per year on the right dates
- Pausing prevents future generation
- Editing frequency rebases the next occurrence
- Cloud Function idempotent (safe to retry)

### 1.9 Remote Config Flag

`recurring_jobs_enabled` (default false)

---

## 2. Customer Portal (Read-Only)

**Why this is #2:** For BS 5839 specifically, the responsible person needs to receive, view, and acknowledge inspection reports. Email-with-PDF works but isn't a moat — every competitor has a customer portal. This also unlocks self-service workflows (booking, viewing history) without burdening dispatchers.

Build read-only first. Self-service booking is feature 19.

### 2.1 Architecture

Customer portal is a **separate route** within the existing web codebase, not a new app. Lives at `customers.firethings.app/...` (or a subpath like `/portal/`). Uses the same Firestore, no new backend.

Customers authenticate via:
- **Magic link** (preferred) — emailed link with signed token, valid 24h
- **Email + password** (optional, for repeat visitors)

No mobile app for customers — the portal is responsive web, works on phone browsers.

### 2.2 Data Models

**File:** `lib/models/customer_portal_user.dart` (NEW)

```dart
class CustomerPortalUser {
  final String id;
  final String email;
  final String? name;
  final String companyId;            // the FireThings company they're a customer of
  final String customerId;            // their CompanyCustomer record
  final List<String> accessibleSiteIds;
  final bool active;
  final DateTime createdAt;
  final DateTime? lastLoginAt;
}

class MagicLinkToken {
  final String token;                 // unguessable random string
  final String customerPortalUserId;
  final DateTime expiresAt;
  final DateTime createdAt;
  final bool used;
}
```

### 2.3 Firestore Structure

`companies/{companyId}/customer_portal_users/{userId}` — read by Cloud Functions only (never directly by client).
`magic_link_tokens/{token}` — short-TTL collection, cleaned up by janitor function.

### 2.4 Cloud Functions

**File:** `functions/customer_portal.js` (NEW)

```js
// Send magic link
exports.requestMagicLink = functions.https.onCall(async (data, context) => {
  const { email, companyId } = data;
  const user = await findCustomerPortalUser(email, companyId);
  if (!user) throw new HttpsError('not-found', 'No portal access for this email');

  const token = generateSecureToken();
  await admin.firestore().collection('magic_link_tokens').doc(token).set({
    customerPortalUserId: user.id,
    expiresAt: new Date(Date.now() + 24 * 3600000),
    createdAt: admin.firestore.FieldValue.serverTimestamp(),
    used: false,
  });

  await sendMagicLinkEmail(email, `https://customers.firethings.app/login?token=${token}`);
  return { sent: true };
});

// Exchange magic link for session
exports.exchangeMagicLink = functions.https.onCall(async (data, context) => {
  const { token } = data;
  const tokenDoc = await admin.firestore()
    .doc(`magic_link_tokens/${token}`).get();
  if (!tokenDoc.exists) throw new HttpsError('invalid-argument', 'Invalid token');
  const tokenData = tokenDoc.data();
  if (tokenData.used) throw new HttpsError('invalid-argument', 'Token already used');
  if (tokenData.expiresAt.toMillis() < Date.now()) throw new HttpsError('deadline-exceeded', 'Token expired');

  // Mark as used
  await tokenDoc.ref.update({ used: true });

  // Create custom Firebase Auth token for the customer
  const customToken = await admin.auth().createCustomToken(
    `customer:${tokenData.customerPortalUserId}`,
    { customerPortal: true, companyId: tokenData.companyId }
  );

  return { customToken };
});
```

### 2.5 Firestore Security

Add rules for customer portal users — they have `customerPortal: true` custom claim:

```
match /companies/{companyId}/sites/{siteId} {
  allow read: if request.auth.token.customerPortal == true
                && siteId in customerAccessibleSites(companyId, request.auth.uid);
}

match /companies/{companyId}/sites/{siteId}/asset_service_history/{recordId} {
  allow read: if request.auth.token.customerPortal == true && /* same site check */;
}

match /companies/{companyId}/sites/{siteId}/inspection_visits/{visitId} {
  allow read: if request.auth.token.customerPortal == true && /* same site check */;
}
```

Customers can READ their accessible sites' assets, service history, visits, and reports. They cannot WRITE anything in this phase.

### 2.6 Screens (Web Only)

**File:** `lib/screens/customer_portal/portal_login_screen.dart` (NEW)

Email input → "Send me a sign-in link" → confirmation message.

**File:** `lib/screens/customer_portal/portal_dashboard_screen.dart` (NEW)

Sections:
- Sites overview (compliance status badge per site)
- Recent activity feed (latest visits, completed jobs)
- Open quotes pending approval
- Documents section (recent reports)

**File:** `lib/screens/customer_portal/portal_site_detail_screen.dart` (NEW)

Per site:
- Compliance summary (X assets, Y pass, Z untested)
- Last visit declaration and date
- Next service window
- "View Full Report" → opens PDF in browser
- Visit history (chronological)
- Active variations (if BS 5839 mode)

**File:** `lib/screens/customer_portal/portal_quote_detail_screen.dart` (NEW)

For approved-pending-action quotes:
- Quote PDF preview
- Total breakdown
- "Approve" button → updates `Quote.status` to `approved` + records timestamp
- "Decline" with reason

### 2.7 Sending Magic Links from FireThings App

**Modify:** `lib/screens/company/customer_detail_screen.dart` — add "Grant Portal Access" button:

- Engineer/dispatcher enters email + selects accessible sites
- Creates `CustomerPortalUser` record
- Sends initial magic link

### 2.8 Web Routing

```
/portal/login
/portal/dashboard
/portal/sites/:siteId
/portal/quotes/:quoteId
/portal/reports/:visitId
```

Hosted on the same Firebase Hosting deployment, gated by route prefix.

### 2.9 Notifications to Customers

When events happen, optionally email the customer portal user:
- New report issued for a site they have access to
- New quote awaiting their approval
- Visit completed

User-configurable preferences (email frequency: instant / daily digest / off).

### 2.10 Edge Cases

- Customer email changes → admin re-grants access with new email
- Customer leaves the responsible person role → admin revokes access
- Multiple customers per site (e.g. building manager + facilities) → each has their own `CustomerPortalUser`
- Customer accessing during a visit in progress → show "Inspection in progress" placeholder, not the half-complete report

### 2.11 Testing

- Magic link expires after 24h
- Token can only be used once
- Customer can only see sites they're explicitly granted
- Portal works on mobile browsers (responsive)
- Quote approval updates the right Firestore doc and triggers convert-to-job

### 2.12 Remote Config Flag

`customer_portal_enabled` (default false)

### 2.13 Analytics Events

`portal_magic_link_requested`, `portal_login`, `portal_site_viewed`, `portal_report_viewed`, `portal_quote_approved`, `portal_quote_declined`

---

## 3. Parts Catalog & Pricebook

**Why this matters:** Quote line items are currently free text. Engineers retype the same descriptions and prices for every quote. A parts catalog with prices, supplier links, and "last quoted at £X" history transforms quote creation from minutes to seconds.

Also feeds into van stock (feature 9) and accounting export (feature 20).

### 3.1 Data Models

**File:** `lib/models/catalog_part.dart` (NEW)

```dart
enum CatalogPartCategory {
  detector, panel, callPoint, sounder, beacon, cable, battery,
  extinguisher, blanket, signage, mounting, labour, other
}

class CatalogPart {
  final String id;
  final String code;                  // SKU / part number (unique within catalog)
  final String name;
  final String? description;
  final CatalogPartCategory category;
  final String? manufacturer;
  final String? supplierName;
  final String? supplierUrl;
  final String? supplierPartNumber;

  // Pricing
  final double costPrice;             // what we pay
  final double sellPrice;             // standard customer price
  final String currency;              // 'GBP' default
  final bool taxable;                 // for VAT calc

  // Inventory hint (full van stock = feature 9)
  final int? typicalVanStockQty;

  // Time on labour items
  final double? labourHours;          // for labour line items
  final double? labourRate;

  // Audit
  final bool active;
  final String createdBy;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime lastModifiedAt;
}
```

### 3.2 Firestore Structure

- Solo: `users/{uid}/catalog_parts/{partId}`
- Company: `companies/{companyId}/catalog_parts/{partId}` — shared across team

Indexes:
- `catalog_parts: active + category + name`
- `catalog_parts: code` (uniqueness check)

### 3.3 Service

**File:** `lib/services/catalog_service.dart` (NEW)

```dart
class CatalogService {
  Future<CatalogPart> create(String basePath, CatalogPart part);
  Future<void> update(String basePath, CatalogPart part);
  Future<void> archive(String basePath, String id);
  Stream<List<CatalogPart>> getActive(String basePath, {CatalogPartCategory? category});
  Future<List<CatalogPart>> search(String basePath, String query);
  Future<CatalogPart?> findByCode(String basePath, String code);

  // Bulk operations
  Future<void> importFromCsv(String basePath, List<List<String>> rows);
  Future<List<List<String>>> exportToCsv(String basePath);
}
```

### 3.4 Screens

**File:** `lib/screens/catalog/catalog_screen.dart` (NEW)

List with category filter chips, search, "Add part" FAB. Each row shows code, name, sell price, category badge.

**File:** `lib/screens/catalog/catalog_part_screen.dart` (NEW)

Add/edit form. Validation: code uniqueness, prices ≥ 0.

**File:** `lib/screens/catalog/catalog_import_screen.dart` (NEW)

CSV import wizard:
1. Upload CSV
2. Map columns (header → field)
3. Preview with validation errors highlighted
4. Confirm import

### 3.5 Integration with Quotes

**Modify:** `lib/screens/quoting/quote_screen.dart` — replace free-text line item entry with a picker:

- "Add line item" button opens `catalog_picker_sheet.dart`
- Picker shows search bar + recent picks + category browse
- Selected part populates description, qty (default 1), unit price (sell price)
- Engineer can still override description or price per line

**Modify:** `lib/models/quote.dart` — add to `QuoteItem`:

```dart
final String? catalogPartId;        // nullable — preserves manual entries
final double? overriddenPrice;      // if engineer changed from catalog default
```

### 3.6 Integration with Service Records

When a defect requires a part replacement, record the part used:

**Modify:** `lib/models/service_record.dart` — add:

```dart
final List<PartUsed> partsUsed;

class PartUsed {
  final String catalogPartId;
  final String partName;
  final int quantity;
  final double unitCostAtTime;
}
```

This becomes the data feed for van stock (feature 9) and for billable parts on jobsheets.

### 3.7 Default catalog seed

Ship with a baseline catalog of common UK fire safety items as a JSON file in assets, importable on first run:

```
assets/seed_data/uk_fire_catalog.json
```

Items: common BS 5839 detectors, MCPs, sounders, batteries by Apollo/Hochiki/System Sensor, common extinguisher refills, etc. ~100 items to start.

### 3.8 Edge Cases

- Part deleted (archived) but referenced by old quotes → quotes still display the historical name and price (no FK enforcement)
- Currency change → mark all parts with `currency` field, never assume GBP
- Bulk import duplicate codes → reject with error showing conflicting rows

### 3.9 Testing

- CSV import with 500 parts in under 30s
- Search returns relevant results within 200ms on 1000-part catalog
- Picker keyboard-friendly on mobile
- Archived parts hidden from picker but visible in part history

### 3.10 Remote Config Flag

`catalog_enabled` (default false)

### 3.11 Analytics Events

`catalog_part_created`, `catalog_part_used_in_quote`, `catalog_csv_imported`

---

## 4. Service Contracts & Customer Pricing

**Why this matters:** Lets you tell at a glance "this customer is on a £1,200/year contract for 4 visits + parts at 10% discount". Without contracts, you can't tell which visits are billable extras vs covered, and you can't apply customer-specific pricing in quotes.

Builds on Recurring Jobs (feature 1).

### 4.1 Data Models

**File:** `lib/models/service_contract.dart` (NEW)

```dart
enum ContractStatus {
  active, suspended, expired, cancelled, draft
}

enum ContractBillingFrequency {
  oneOff, monthly, quarterly, annually
}

class ServiceContract {
  final String id;
  final String companyId;
  final String customerId;
  final List<String> coveredSiteIds;

  // Term
  final DateTime startDate;
  final DateTime endDate;
  final bool autoRenew;
  final int? autoRenewMonths;

  // Coverage
  final List<String> recurringJobIds;     // visits that fulfil this contract
  final int? coveredVisitsPerYear;
  final List<String> coveredAssetTypeIds; // which asset types are covered
  final bool coversParts;
  final double partsDiscountPercent;
  final double labourDiscountPercent;
  final bool coversCallouts;
  final int? coveredCalloutsPerYear;
  final double calloutChargeAfterIncluded;

  // Billing
  final double annualValue;
  final ContractBillingFrequency billingFrequency;
  final String? notes;

  // Status
  final ContractStatus status;

  // Audit
  final String createdBy;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime lastModifiedAt;
}
```

### 4.2 Service

**File:** `lib/services/contract_service.dart` (NEW)

```dart
class ContractService {
  Future<ServiceContract> create(ServiceContract contract);
  Future<void> update(ServiceContract contract);
  Future<void> renew(String id);
  Future<void> cancel(String id, String reason);

  Future<List<ServiceContract>> getActiveForCustomer(String customerId);
  Future<ServiceContract?> getContractCoveringSite(String siteId);

  // Logic
  bool isVisitCoveredByContract(String siteId, DateTime visitDate);
  double applyContractPricing(double basePrice, ServiceContract contract);
  Future<int> getRemainingCoveredVisits(String contractId);
  Future<int> getRemainingCoveredCallouts(String contractId);
}
```

### 4.3 Screens

**File:** `lib/screens/contracts/contracts_screen.dart` (NEW)

List of all contracts. Filter by status, customer. Each card shows customer name, sites covered count, annual value, status badge, expiry date with warning if within 60 days.

**File:** `lib/screens/contracts/contract_detail_screen.dart` (NEW)

Sections:
- Customer & sites
- Term & renewal
- Coverage details
- Visit usage (X of Y used this period)
- Callout usage
- Linked recurring jobs
- Billing schedule

**File:** `lib/screens/contracts/create_contract_screen.dart` (NEW)

Wizard:
1. Customer selection (from saved customers)
2. Sites covered (multi-select)
3. Visit frequency → auto-creates RecurringJobs (feature 1)
4. Pricing terms (annual value, discounts)
5. Billing schedule
6. Review and activate

### 4.4 Integration with Quotes

When creating a quote for a customer with an active contract:

- Auto-apply parts and labour discounts
- Show "Contract pricing applied: 10% off parts" callout on the quote
- If quote is for work covered by contract → flag as "Covered by contract — no charge" with reduced or zero total

### 4.5 Integration with Dispatch

On the dispatch dashboard, when creating a job for a contract customer:

- Show contract status badge
- Show "Covered by contract — non-billable" toggle
- Track callout count if it's an emergency callout

### 4.6 Reporting

**File:** `lib/screens/contracts/contract_renewal_dashboard.dart` (NEW)

Admin dashboard showing:
- Contracts expiring in next 30 / 60 / 90 days
- Auto-renewal forecast (revenue + count)
- Cancelled contracts last quarter (churn)
- Contract value by customer

### 4.7 Edge Cases

- Contract covers some sites but not others → quote/job needs to know per-site coverage
- Contract expires mid-year → recurring jobs continue but flag as "out of contract" until renewed
- Customer changes business name → contract preserved with original name, customer record updates separately

### 4.8 Remote Config Flag

`service_contracts_enabled` (default false)

---

## 5. SLA / Response Time Tracking

**Why this matters:** Emergency callouts have a "Emergency" priority but no SLA timer. Many fire safety contracts include a "must arrive within 4 hours" clause. Without tracking, you can't prove compliance and can't charge premium rates for guaranteed response.

### 5.1 Data Models

**File:** `lib/models/sla_policy.dart` (NEW)

```dart
class SlaPolicy {
  final String id;
  final String companyId;
  final String name;                  // "Standard", "Premium 4hr", "Critical 1hr"
  final Map<String, int> responseTargetMinutesByPriority;
                                      // { 'normal': 1440, 'urgent': 240, 'emergency': 60 }
  final bool businessHoursOnly;
  final List<int> businessHoursDays;  // 1-7, Mon-Sun
  final int businessHoursStart;       // minutes from midnight
  final int businessHoursEnd;
  final bool active;
  final String createdBy;
  final DateTime createdAt;
}
```

**Modify:** `lib/models/dispatched_job.dart` — add:

```dart
final String? slaPolicyId;
final DateTime? slaTargetResponseBy;     // computed at creation
final DateTime? firstResponseAt;          // when engineer accepted
final DateTime? onSiteAt;                 // when engineer arrived
final bool slaResponseMet;
final bool slaArrivalMet;
```

**Modify:** `lib/models/service_contract.dart` (if feature 4 implemented) — add:

```dart
final String? slaPolicyId;          // contract-tied SLA
```

### 5.2 Service

**File:** `lib/services/sla_service.dart` (NEW)

```dart
class SlaService {
  Future<SlaPolicy> create(SlaPolicy policy);
  Stream<List<SlaPolicy>> getForCompany(String companyId);

  DateTime calculateTargetResponseTime(SlaPolicy policy, String priority, DateTime jobCreatedAt);
  bool isResponseInBreach(DispatchedJob job);
  Duration timeRemainingToTarget(DispatchedJob job);

  // Reporting
  Future<SlaReport> getReport({DateTime? from, DateTime? to});
}

class SlaReport {
  final int totalJobs;
  final int responseMet;
  final int responseBreached;
  final int arrivalMet;
  final int arrivalBreached;
  final double averageResponseMinutes;
  final double averageArrivalMinutes;
  final Map<String, int> breachesByEngineer;
}
```

### 5.3 Cloud Function

```js
exports.checkSlaBreaches = functions.pubsub
  .schedule('every 5 minutes')
  .onRun(async (context) => {
    const now = admin.firestore.Timestamp.now();
    const atRiskJobs = await admin.firestore()
      .collectionGroup('dispatched_jobs')
      .where('status', 'in', ['created', 'assigned'])
      .where('slaTargetResponseBy', '<=', addMinutes(now, 30))
      .get();

    for (const job of atRiskJobs.docs) {
      await sendSlaWarningNotification(job);
    }
  });
```

### 5.4 Screens

**File:** `lib/screens/dispatch/sla_dashboard_screen.dart` (NEW)

- Active jobs with countdown timers (red if breached, amber if <30min, green otherwise)
- Today's SLA performance summary
- Engineer leaderboard (% on-time)

**File:** `lib/screens/settings/sla_policies_screen.dart` (NEW)

CRUD for SLA policies (admin only).

### 5.5 Integration

- **Create Job screen** — auto-applies the right SLA policy based on customer/contract
- **Engineer Job Detail** — shows live countdown to SLA target
- **Dispatch Dashboard** — sort/filter by SLA risk
- **Push notifications** — alert engineer + dispatcher 30 min before breach
- **Compliance report** — quarterly SLA performance report PDF

### 5.6 Edge Cases

- Job marked "Emergency" outside business hours but policy is business-hours-only → policy doesn't apply, log warning
- Customer cancels job after engineer accepts → SLA met (response was made)
- Engineer goes "On Site" before "Accepted" → infer Accepted at the same moment

### 5.7 Remote Config Flag

`sla_tracking_enabled` (default false)

---

## 6. Site Access & Key Information

**Why this matters:** Engineers waste time on every visit hunting for: alarm code, key safe combo, parking instructions, asbestos register location, out-of-hours contact. Currently this lives in unstructured `notes` or in the engineer's head.

Quick win — small data model, big productivity gain.

### 6.1 Data Models

**File:** `lib/models/site_access_info.dart` (NEW)

```dart
class SiteAccessInfo {
  final String id;                    // 'current', one per site
  final String siteId;

  // Access
  final String? alarmCode;
  final String? keySafeCombo;
  final String? keySafeLocation;
  final String? accessInstructions;
  final String? parkingInstructions;
  final bool requiresEscort;
  final String? escortContactName;
  final String? escortContactPhone;

  // Hours
  final String? siteHours;            // "Mon-Fri 8am-6pm"
  final String? outOfHoursContactName;
  final String? outOfHoursContactPhone;

  // Safety
  final bool asbestosPresent;
  final String? asbestosRegisterLocation;
  final List<String> hazardWarnings;  // ["High voltage in plant room", "Confined spaces"]
  final bool ppeRequired;
  final List<String> requiredPpe;     // ["Hard hat", "Safety glasses"]

  // Permits
  final bool requiresPermitToWork;
  final String? permitContactName;
  final String? permitContactPhone;
  final String? permitProcess;

  // Emergency
  final String? emergencyAssemblyPoint;
  final String? nearestHospital;

  // Audit
  final String? lastUpdatedBy;
  final DateTime updatedAt;
  final DateTime lastModifiedAt;
}
```

### 6.2 Firestore Structure

`{basePath}/sites/{siteId}/access_info/current` — single doc per site

**SECURITY:** Mark as sensitive — `alarmCode`, `keySafeCombo` should require explicit "Reveal" tap (not displayed by default in lists). Audit log every reveal action.

### 6.3 Service

**File:** `lib/services/site_access_service.dart` (NEW)

```dart
class SiteAccessService {
  Future<SiteAccessInfo?> getForSite(String basePath, String siteId);
  Future<void> save(String basePath, String siteId, SiteAccessInfo info);

  // Audit
  Future<void> logCodeReveal(String siteId, String fieldName);
}
```

### 6.4 Screens

**File:** `lib/screens/sites/site_access_screen.dart` (NEW)

View/edit screen with sections:
- Access (with reveal-on-tap for sensitive fields)
- Hours & contacts
- Safety & hazards (prominent warning banner if `asbestosPresent` or `ppeRequired`)
- Permits
- Emergency

### 6.5 Integration

- **Engineer Job Detail** — show "Site Access" card prominently above asset details
- **Pre-job briefing** — when engineer accepts a job, show one-screen summary of access info if available
- **Dispatch dashboard** — flag jobs at sites with `requiresPermitToWork` or `requiresEscort` so dispatcher can plan

### 6.6 Edge Cases

- Customer changes alarm code → engineer must update; show "Last updated by [engineer] on [date]" prominently
- Code reveal logged → audit trail accessible to admins (who's seen the codes)
- Site without access info → show "Add access info" prompt prominently

### 6.7 Remote Config Flag

`site_access_info_enabled` (default false)

---

## 7. False Alarm Log & Analysis

**Why this matters:** BS 5839-1 explicitly requires false alarm management. Customers care because false alarms cost money (fire brigade callout charges, evacuation disruption). The app already has the data structure for it — defects can be tagged — but no aggregation or analysis.

If BS 5839 spec is implemented, this is a logbook entry type. If not, it's standalone.

### 7.1 Data Models

**File:** `lib/models/false_alarm.dart` (NEW)

```dart
enum FalseAlarmCategory {
  cooking,                  // burnt toast, cooking fumes
  steam,                    // shower/kettle steam
  dust,                     // building work, drilling
  insects,                  // moths, flies in detector
  smokingMaterials,         // cigarettes near detector
  contractorActivity,       // hot works, dust
  malicious,                // deliberately set off
  detectorFault,
  systemFault,
  unknown,
  other,
}

enum FalseAlarmAction {
  noAction, detectorReplaced, detectorRelocated, sensitivityAdjusted,
  panelProgrammingChanged, deviceTypeChanged, customerEducation,
  signageAdded, other,
}

class FalseAlarm {
  final String id;
  final String siteId;
  final DateTime occurredAt;
  final String? zone;
  final String? triggeredAssetId;
  final String? triggeredAssetReference;
  final FalseAlarmCategory category;
  final String? customCategoryNote;
  final String description;
  final bool fireServiceAttended;
  final bool buildingEvacuated;
  final FalseAlarmAction actionTaken;
  final String? actionNotes;
  final String? loggedByName;
  final String? loggedByRole;
  final String? visitId;              // if logged during a visit
  final DateTime createdAt;
  final DateTime lastModifiedAt;
}
```

### 7.2 Firestore Structure

`{basePath}/sites/{siteId}/false_alarms/{id}`

Indexes:
- `false_alarms: siteId + occurredAt desc`
- `false_alarms: siteId + category + occurredAt desc`

### 7.3 Service

**File:** `lib/services/false_alarm_service.dart` (NEW)

```dart
class FalseAlarmService {
  Future<FalseAlarm> create(String basePath, FalseAlarm alarm);
  Future<void> update(String basePath, FalseAlarm alarm);
  Stream<List<FalseAlarm>> getForSite(String basePath, String siteId);

  // Analysis
  Future<FalseAlarmReport> getReport({
    required String siteId,
    required DateTime from,
    required DateTime to,
  });
}

class FalseAlarmReport {
  final int total;
  final int last90Days;
  final int last12Months;
  final Map<FalseAlarmCategory, int> byCategory;
  final Map<String, int> byZone;
  final Map<String, int> byAsset;          // asset reference → count
  final List<String> repeatOffenders;       // assets with >3 alarms in 12mo
  final int fireServiceAttendances;
  final int evacuations;
}
```

### 7.4 Screens

**File:** `lib/screens/false_alarms/false_alarm_log_screen.dart` (NEW)

Per-site list with filter chips by category. Each card shows date, category badge, zone, brief description, asset reference if any.

**File:** `lib/screens/false_alarms/log_false_alarm_screen.dart` (NEW)

Form covering all FalseAlarm fields. Triggered from:
- Site detail "Log false alarm" action
- During an inspection visit
- From the dispatch dashboard for completed jobs that were callouts

**File:** `lib/screens/false_alarms/false_alarm_analysis_screen.dart` (NEW)

Per-site analysis dashboard:
- Summary stats (total, 90 days, 12 months)
- Category breakdown chart
- Top 5 problem assets (heatmap on floor plan if available)
- Trend graph (alarms per month over last 12)
- Recommendations (e.g. "Detector SD-007 has 5 false alarms — consider relocating or changing type")

### 7.5 PDF Section

Add to BS 5839 compliance report (if BS 5839 spec implemented) — "False Alarm Summary" section with the analysis data.

### 7.6 Integration

- **Inspection visit** — checklist item "Review false alarm history" prompts engineer to view the analysis
- **Defect logging** — when an asset has >3 false alarms in 12 months, suggest "Replace or relocate" as the recommended action
- **Customer portal** — visible to customers (transparency)

### 7.7 Edge Cases

- False alarm logged with no asset reference → still useful, count it for the zone
- Multiple alarms at the same time on the same site → log as one event, list affected detectors
- Migration from existing free-text "false alarm" defect notes → admin tool to convert

### 7.8 Remote Config Flag

`false_alarm_log_enabled` (default false)

---

## 8. Disablement Register

**Why this matters:** When an engineer disables a zone (e.g. for hot work, building maintenance, or because of a fault), this MUST be logged with a re-enable reminder. BS 5839 requires it. Without an audit trail, you can't prove a zone was reinstated, which is a serious safety/liability issue.

### 8.1 Data Models

**File:** `lib/models/disablement.dart` (NEW)

```dart
enum DisablementReason {
  hotWork, maintenance, fault, modification, falseAlarmInvestigation,
  systemUpgrade, partsAwaited, other,
}

enum DisablementScope {
  singleDevice, zone, multipleZones, entireSystem,
}

class Disablement {
  final String id;
  final String siteId;
  final DisablementScope scope;
  final List<String>? affectedAssetIds;
  final List<String>? affectedZones;
  final DisablementReason reason;
  final String? reasonNotes;

  // Lifecycle
  final DateTime disabledAt;
  final String disabledByEngineerId;
  final String disabledByEngineerName;
  final DateTime? expectedReinstatementAt;
  final DateTime? actualReinstatementAt;
  final String? reinstatedByEngineerId;
  final String? reinstatedByEngineerName;
  final String? reinstatementNotes;

  // Mitigations during disablement
  final bool fireWatchInPlace;
  final String? fireWatchProvider;
  final bool customerNotified;

  // Status
  final bool active;
  final DateTime createdAt;
  final DateTime lastModifiedAt;
}
```

### 8.2 Firestore Structure

`{basePath}/sites/{siteId}/disablements/{id}`

Indexes:
- `disablements: siteId + active + disabledAt desc`

### 8.3 Service

**File:** `lib/services/disablement_service.dart` (NEW)

```dart
class DisablementService {
  Future<Disablement> create(String basePath, Disablement d);
  Future<void> reinstate(String basePath, String id, {
    required String reinstatedByEngineerId,
    required String reinstatedByEngineerName,
    String? notes,
  });
  Stream<List<Disablement>> getActiveForSite(String basePath, String siteId);
  Stream<List<Disablement>> getAllForSite(String basePath, String siteId);

  Future<List<Disablement>> getOverdue();    // expectedReinstatementAt passed
}
```

### 8.4 Cloud Function

```js
exports.disablementReminders = functions.pubsub
  .schedule('every 60 minutes')
  .onRun(async (context) => {
    const overdue = await admin.firestore()
      .collectionGroup('disablements')
      .where('active', '==', true)
      .where('expectedReinstatementAt', '<=', admin.firestore.Timestamp.now())
      .get();

    for (const d of overdue.docs) {
      await sendDisablementOverdueNotification(d);
    }
  });
```

### 8.5 Screens

**File:** `lib/screens/disablements/disablement_register_screen.dart` (NEW)

Per-site list with active/historical tabs. Active disablements shown prominently with red banner "X devices/zones currently disabled".

**File:** `lib/screens/disablements/log_disablement_screen.dart` (NEW)

Form with fields covering all Disablement model properties. Asset selector if scope = single device. Zone selector if scope = zone.

**File:** `lib/screens/disablements/reinstate_disablement_screen.dart` (NEW)

Confirmation screen with optional notes, captures reinstating engineer.

### 8.6 Integration

- **Site detail** — banner at top if any active disablements
- **Asset detail** — if asset is in an active disablement, show "DISABLED" badge with link to disablement record
- **Floor plan** — disabled assets shown with hatched overlay
- **Inspection visit** — checklist item "Review active disablements" prompts engineer
- **Compliance report** — section for active disablements
- **Push notifications** — alert engineer + dispatcher when expected reinstatement passes

### 8.7 Edge Cases

- Asset deleted while in active disablement → mark disablement as "Asset removed" with timestamp
- Engineer who disabled is removed from company → reinstatement can be done by anyone
- Disablement reinstated but the same fault recurs → new disablement record, link as "Related"

### 8.8 Remote Config Flag

`disablement_register_enabled` (default false)

---

## 9. Van Stock Management

**Why this matters:** Engineers carry replacement parts in their vans. When a defect needs replacement, the app could match against current van stock and offer "Swap from van + log usage" instead of "Quote required". Speeds up resolution dramatically.

Depends on Parts Catalog (feature 3).

### 9.1 Data Models

**File:** `lib/models/van_stock.dart` (NEW)

```dart
class VanStockItem {
  final String id;
  final String engineerId;            // owns the van
  final String catalogPartId;
  final String partName;              // denormalised for offline display
  final int currentQuantity;
  final int? targetQuantity;          // restock alert threshold
  final DateTime? lastRestockedAt;
  final DateTime updatedAt;
  final DateTime lastModifiedAt;
}

enum StockMovementType {
  restock,                            // adding to van
  usedOnJob,
  damaged,
  returned,                           // returned to depot
  transferToEngineer,                 // moved to another engineer
  audit,                              // adjustment from physical count
}

class StockMovement {
  final String id;
  final String engineerId;
  final String catalogPartId;
  final int quantityChange;           // positive or negative
  final StockMovementType type;
  final String? jobsheetId;
  final String? serviceRecordId;
  final String? toEngineerId;         // for transfers
  final String? notes;
  final DateTime occurredAt;
  final String createdBy;
}
```

### 9.2 Firestore Structure

- `companies/{companyId}/van_stock/{engineerId}_{catalogPartId}` — composite key for upsert efficiency
- `companies/{companyId}/stock_movements/{id}` — full audit log

### 9.3 Service

**File:** `lib/services/van_stock_service.dart` (NEW)

```dart
class VanStockService {
  Future<List<VanStockItem>> getMyStock();
  Future<List<VanStockItem>> getEngineerStock(String engineerId);

  Future<void> recordMovement(StockMovement movement);
  Future<void> usePartOnJob({
    required String catalogPartId,
    required int quantity,
    required String jobsheetId,
    String? serviceRecordId,
  });

  Future<void> restock(List<({String catalogPartId, int quantity})> items);
  Future<void> transferToEngineer(String catalogPartId, int quantity, String toEngineerId);

  Future<List<VanStockItem>> getLowStockItems();    // qty < target
}
```

### 9.4 Screens

**File:** `lib/screens/stock/my_van_stock_screen.dart` (NEW)

Engineer's stock list with low-stock warnings. Filter by category. Search.

**File:** `lib/screens/stock/restock_screen.dart` (NEW)

Quick restock workflow: select part, enter quantity, confirm. Bulk restock supported.

**File:** `lib/screens/stock/stock_movements_screen.dart` (NEW)

Audit history per engineer or per part.

**File:** `lib/screens/stock/team_stock_overview_screen.dart` (NEW — admin/dispatcher)

Matrix view: engineers × parts with current quantities. Useful for "who has a spare smoke detector right now".

### 9.5 Integration

- **Defect bottom sheet** — when defect action = "Replace", check van stock; if available, "Swap now (deducts from van)" button
- **Asset test** — if part swapped, log via `usePartOnJob`
- **Jobsheet PDF** — auto-include "Parts used" table from stock movements
- **Quote** — if engineer has the part in van, label "In stock — can fit on next visit"

### 9.6 Edge Cases

- Part used but not in van stock → log as negative quantity, prompt to restock
- Engineer transfers all stock to another (e.g. holiday cover) → bulk transfer screen
- Van break-in / theft → "Adjust" workflow with reason

### 9.7 Remote Config Flag

`van_stock_enabled` (default false)

---

## 10. Photo Annotation Tool

**Why this matters:** Defect photos are raw. "This terminal is loose" is much clearer with an arrow drawn on it. Common in competitor apps, easy win.

### 10.1 Approach

Use Flutter's existing canvas APIs or the `image_painter` / `signature` package to overlay drawing on captured photos.

### 10.2 Workflow

1. Engineer captures defect photo (existing flow)
2. After capture, "Annotate" button opens annotation screen
3. Drawing tools: pen (multiple colours), arrow, rectangle, circle, text label, undo/redo
4. Save → flattens annotation into the image, replaces original

### 10.3 Screens

**File:** `lib/screens/common/photo_annotation_screen.dart` (NEW)

Full-screen photo with toolbar at bottom. Save returns annotated bytes to caller.

### 10.4 Integration

Wherever photos are captured: defect bottom sheet, asset photos, floor plan upload, jobsheet attachments.

### 10.5 Edge Cases

- Original photo preserved? Either yes (`{path}_original.jpg`) or no (saves space). Decision: keep original behind a setting toggle "Preserve unannotated photos".
- Annotation on PDF → out of scope for v1
- Web support: same canvas API works

### 10.6 Remote Config Flag

`photo_annotation_enabled` (default false)

---

## 11. Site Photos Beyond Defects

**Why this matters:** Engineers want to capture photos that aren't tied to a defect: before/after work, panel status, access route, parking, key safe location, fire door condition. Currently there's no place for these.

### 11.1 Data Model

**File:** `lib/models/site_photo.dart` (NEW)

```dart
enum SitePhotoCategory {
  beforeWork, afterWork, accessRoute, parking, keySafe, panel,
  signage, fireDoor, hazard, generalDocumentation, other,
}

class SitePhoto {
  final String id;
  final String siteId;
  final String? assetId;              // optional — can be site-level
  final String? visitId;              // optional — can be standalone
  final SitePhotoCategory category;
  final String? caption;
  final String url;
  final String? thumbnailUrl;
  final String capturedByEngineerId;
  final String capturedByEngineerName;
  final DateTime capturedAt;
  final DateTime createdAt;
}
```

### 11.2 Firestore + Storage

- `{basePath}/sites/{siteId}/photos/{id}` — metadata
- Storage: `{basePath}/sites/{siteId}/photos/{id}.jpg`

### 11.3 Service

**File:** `lib/services/site_photo_service.dart` (NEW)

CRUD + photo upload (mirroring `AssetService.uploadAssetPhoto` pattern).

### 11.4 Screens

**File:** `lib/screens/sites/site_photos_screen.dart` (NEW)

Grid view with category filter. Tap to view full-screen with caption.

**File:** `lib/screens/sites/capture_site_photo_screen.dart` (NEW)

Simple capture flow with category selector, optional caption, optional asset link.

### 11.5 Integration

- Site detail screen — photo count badge
- Inspection visit — capture photos during the visit, auto-tagged with visitId
- Compliance report — optional "Site Photos" section at end

### 11.6 Remote Config Flag

`site_photos_enabled` (default false)

---

## 12. Customer Signature on Job Completion

**Why this matters:** The compliance report has signatures, but the dispatched-job completion only captures the engineer's signature. The customer should sign-off that work was completed satisfactorily — proof of delivery for billing disputes.

### 12.1 Data Model Update

**Modify:** `lib/models/dispatched_job.dart` — add:

```dart
final String? customerSignatureBase64;
final String? customerSignedName;
final String? customerSignedRole;
final DateTime? customerSignedAt;
final String? customerCompletionNotes;
final bool customerDeclinedToSign;
final String? customerDeclinedReason;
```

### 12.2 Workflow

When engineer marks job as Completed:

1. Show "Customer Sign-Off" screen
2. Customer enters name, role
3. Captures signature
4. Optional satisfaction notes
5. OR: "Customer not available" toggle with reason
6. Save → completes job

### 12.3 Screen

**File:** `lib/screens/dispatch/customer_sign_off_screen.dart` (NEW)

Standard signature capture pattern (already used in jobsheet flow).

### 12.4 Integration

- Jobsheet PDF — include customer sign-off section
- Compliance report — if linked to a job with sign-off, include
- Disputes — if customer denies work was done, signature is proof

### 12.5 Edge Cases

- Customer not on site (e.g. unattended visit) → "Customer not available" with photo evidence of completed work
- Multiple jobs same day same customer → one signature per job (not consolidated)

### 12.6 Remote Config Flag

`customer_signoff_enabled` (default true) — low risk to enable widely

---

## 13. Engineer Timesheets

**Why this matters:** Engineers tap "On Site" / "Completed" on dispatched jobs but this isn't aggregated for payroll. With timesheets, you get weekly totals, billable hours per customer, overtime calculation.

### 13.1 Data Model

Most data already exists in `DispatchedJob`. Add optional time-tracking enrichment:

**File:** `lib/models/timesheet_entry.dart` (NEW)

```dart
enum TimesheetEntryType {
  onSiteWork, travel, breakTime, training, adminTime,
  vehicleMaintenance, sickLeave, holiday, other,
}

class TimesheetEntry {
  final String id;
  final String engineerId;
  final String? dispatchedJobId;
  final TimesheetEntryType type;
  final DateTime startTime;
  final DateTime? endTime;
  final int? durationMinutes;         // computed if endTime set
  final String? notes;
  final bool billable;
  final String? customerId;           // if billable, who's it billed to
  final DateTime createdAt;
  final DateTime lastModifiedAt;
}
```

### 13.2 Service

**File:** `lib/services/timesheet_service.dart` (NEW)

```dart
class TimesheetService {
  Future<TimesheetEntry> startEntry({...});
  Future<void> stopEntry(String id);
  Future<TimesheetEntry> create(TimesheetEntry entry);

  Future<TimesheetReport> getWeeklyReport(String engineerId, DateTime weekStarting);
  Future<TimesheetReport> getMonthlyReport(String engineerId, int year, int month);

  Future<TimesheetReport> getTeamReport(String companyId, DateTime from, DateTime to);
}

class TimesheetReport {
  final String engineerId;
  final DateTime periodStart;
  final DateTime periodEnd;
  final int totalMinutes;
  final int billableMinutes;
  final int travelMinutes;
  final Map<TimesheetEntryType, int> byType;
  final Map<String, int> byCustomer;
  final List<TimesheetEntry> entries;
}
```

### 13.3 Screens

**File:** `lib/screens/timesheets/my_timesheet_screen.dart` (NEW)

Calendar view with day-by-day breakdown. Add manual entries for non-job time (training, sick).

**File:** `lib/screens/timesheets/team_timesheets_screen.dart` (NEW — admin)

Approval workflow: engineers submit weekly, admins approve.

### 13.4 Integration

- **Job status changes** — auto-create TimesheetEntry on "On Site" → end on "Completed"
- **Dispatched job completion** — prompt for travel time if not auto-tracked
- **Export** — CSV for payroll software, PDF for printing

### 13.5 Remote Config Flag

`timesheets_enabled` (default false)

---

## 14. Multi-Day Jobs

**Why this matters:** Commissioning a system or large maintenance work spans multiple days. The current dispatch model assumes single-visit jobs. Engineers have to create separate jobs and lose context.

### 14.1 Data Model Update

**Modify:** `lib/models/dispatched_job.dart` — add:

```dart
final String? parentJobId;          // for child visits in a multi-day series
final List<String> childJobIds;     // for parent jobs
final int? totalEstimatedDays;
final int? dayNumber;               // "Day 2 of 5"
```

### 14.2 Service Methods

```dart
class DispatchService {
  // Existing methods...

  Future<List<DispatchedJob>> createMultiDayJob({
    required DispatchedJob template,
    required List<DateTime> visitDates,
    required String engineerId,
  });

  Future<List<DispatchedJob>> getChildJobs(String parentJobId);
}
```

### 14.3 Screens

**File:** `lib/screens/dispatch/create_multi_day_job_screen.dart` (NEW)

Wizard:
1. Standard job details (as parent)
2. Number of days estimate
3. Visit date picker (multi-select dates)
4. Same engineer or split between engineers
5. Confirm → creates parent + N child jobs

**File:** `lib/screens/dispatch/multi_day_job_overview_screen.dart` (NEW)

Parent job view showing all child visits, completion status, cumulative time spent.

### 14.4 Integration

- Engineer Job Detail → "Day X of Y" badge
- Dispatch dashboard → option to expand multi-day jobs
- Compliance report — multi-day commissioning visit aggregates child visit data

### 14.5 Edge Cases

- Customer reschedules day 3 → can move single child without affecting siblings
- Engineer sick on day 2 → reassign just the affected child
- Cancel multi-day → confirm dialog with child count

### 14.6 Remote Config Flag

`multi_day_jobs_enabled` (default false)

---

## 15. Install / Commissioning Certificate

**Why this matters:** BS 5839 requires a formal install/commissioning certificate for new systems. Different format from the inspection report. This is what a building inspector or insurer wants for sign-off on a new build or major modification.

Depends on BS 5839 spec being implemented.

### 15.1 Data Model

**File:** `lib/models/install_certificate.dart` (NEW)

```dart
class InstallCertificate {
  final String id;
  final String siteId;
  final String visitId;               // commissioning visit
  final String certificateNumber;     // sequential per company

  // Installation details
  final String installerCompany;
  final DateTime installationStartDate;
  final DateTime installationEndDate;
  final String? designedBy;
  final String? installedBy;
  final String? commissionedBy;

  // System scope
  final String systemDescription;
  final List<String> conformsToStandards;     // ["BS 5839-1:2025", "BS 7671"]

  // Compliance statements
  final bool designConformsToStandard;
  final bool installationConformsToStandard;
  final bool commissioningTestsCompleted;
  final List<String> variations;              // permitted departures

  // Sign-offs
  final String designerName;
  final String designerSignatureBase64;
  final DateTime designerSignedAt;
  final String installerName;
  final String installerSignatureBase64;
  final DateTime installerSignedAt;
  final String commissionerName;
  final String commissionerSignatureBase64;
  final DateTime commissionerSignedAt;

  // Customer acceptance
  final String? customerAcceptanceName;
  final String? customerAcceptanceSignatureBase64;
  final DateTime? customerAcceptanceAt;

  final DateTime createdAt;
  final String? pdfUrl;
}
```

### 15.2 PDF Service

**File:** `lib/services/install_certificate_pdf_service.dart` (NEW)

Generates the certificate using existing `pdf_widgets/` library. Format follows BS 5839-1:2025 Annex G example certificate.

### 15.3 Screen

**File:** `lib/screens/bs5839/install_certificate_screen.dart` (NEW)

Form for completing the certificate at end of commissioning visit. Three signature pads (designer, installer, commissioner) plus customer acceptance.

### 15.4 Integration

- Triggered from BS 5839 visit completion when `visitType == commissioning`
- Stored alongside the visit's inspection report
- Customer portal — visible to customers
- Counts as part of mandatory documentation for BS 5839

### 15.5 Remote Config Flag

`install_certificate_enabled` (default false)

---

## 16. Subcontractor Support

**Why this matters:** Some specialist work (e.g. lift homing testing, sprinkler servicing) is subcontracted. Currently a job can only be assigned to one engineer in one company. Subcontractor support lets you bring in external expertise without breaking the audit trail.

### 16.1 Data Models

**File:** `lib/models/subcontractor.dart` (NEW)

```dart
class Subcontractor {
  final String id;
  final String companyId;
  final String name;
  final String? contactName;
  final String? contactEmail;
  final String? contactPhone;
  final List<String> specialties;     // ["Sprinklers", "Voice Alarm"]
  final String? insuranceCertUrl;
  final DateTime? insuranceExpiry;
  final bool active;
  final DateTime createdAt;
}
```

**Modify:** `DispatchedJob` — add:

```dart
final String? subcontractorId;       // nullable — null = own engineer
final String? subcontractorContactName;
final String? subcontractorReference;
```

### 16.2 Workflow

- Job created normally, then "Assign to subcontractor" instead of internal engineer
- Subcontractor receives job details by email (no app login)
- Subcontractor returns work via email/upload
- Office staff close out job with subcontractor's report attached

### 16.3 Screens

**File:** `lib/screens/subcontractors/subcontractors_screen.dart` (NEW)
**File:** `lib/screens/subcontractors/subcontractor_detail_screen.dart` (NEW)
**File:** `lib/screens/subcontractors/subcontractor_assignment_screen.dart` (NEW)

### 16.4 Edge Cases

- Insurance certificate expired → block assignment with warning
- Subcontractor never returns work → flag overdue, escalate to admin

### 16.5 Remote Config Flag

`subcontractors_enabled` (default false)

---

## 17. Email Open Tracking on Quotes

**Why this matters:** Quote sent → silence. Was it opened? Did the customer ignore it or never receive it? Open tracking is standard in any sales tool.

### 17.1 Implementation

#### Option A: Tracking pixel (simple)

Add 1x1 transparent image to quote emails:
```html
<img src="https://us-central1-firethings.cloudfunctions.net/trackOpen?token=ABC123" />
```

Cloud Function logs the open and updates the Quote with `firstOpenedAt`, `openCount`.

#### Option B: SendGrid integration (richer)

If using SendGrid for email, use their built-in event webhooks for opens, clicks, bounces.

### 17.2 Data Model Update

**Modify:** `lib/models/quote.dart` — add:

```dart
final DateTime? firstOpenedAt;
final DateTime? lastOpenedAt;
final int openCount;
final bool deliveryConfirmed;
final bool deliveryFailed;
final String? deliveryFailureReason;
```

### 17.3 Cloud Function

**File:** `functions/email_tracking.js` (NEW)

```js
exports.trackOpen = functions.https.onRequest(async (req, res) => {
  const { token } = req.query;
  const tokenDoc = await admin.firestore().doc(`email_tracking_tokens/${token}`).get();
  if (tokenDoc.exists) {
    const { quoteId, basePath } = tokenDoc.data();
    await admin.firestore().doc(`${basePath}/quotes/${quoteId}`).update({
      firstOpenedAt: admin.firestore.FieldValue.serverTimestamp(),  // or use update logic to keep first
      lastOpenedAt: admin.firestore.FieldValue.serverTimestamp(),
      openCount: admin.firestore.FieldValue.increment(1),
    });
  }
  // Return 1x1 transparent GIF
  res.set('Content-Type', 'image/gif');
  res.send(Buffer.from('R0lGODlhAQABAIAAAAAAAP///yH5BAEAAAAALAAAAAABAAEAAAIBRAA7', 'base64'));
});
```

### 17.4 UI

- Quote list: badge showing "Opened 3×" or "Not opened"
- Quote detail: "Last opened by customer 2 days ago" subtext

### 17.5 Privacy

- Disclose tracking in your email signature / privacy policy
- Image-blocking by customer email client = false negative; warn dispatcher not to over-rely

### 17.6 Remote Config Flag

`email_open_tracking_enabled` (default false)

---

## 18. Equipment Calibration Tracking

**Why this matters:** Test instruments (smoke detector test cans, sound level meters, multimeters, anemometers) need calibration. If a sound meter reading is challenged, you need calibration certificate to prove validity. BS 5839 visits using uncalibrated instruments are technically non-compliant.

### 18.1 Data Models

**File:** `lib/models/test_instrument.dart` (NEW)

```dart
enum InstrumentType {
  smokeTestCan, heatTestKit, soundLevelMeter, multimeter,
  earthFaultTester, batteryLoadTester, lightMeter, anemometer, other,
}

class TestInstrument {
  final String id;
  final String engineerId;            // owns it (or 'company' for shared)
  final InstrumentType type;
  final String? customTypeName;
  final String? manufacturer;
  final String? model;
  final String? serialNumber;
  final DateTime? purchaseDate;

  // Calibration
  final DateTime? lastCalibrationDate;
  final DateTime? nextCalibrationDue;
  final String? calibrationProvider;
  final String? lastCalibrationCertUrl;
  final int calibrationIntervalMonths;

  // Status
  final bool active;
  final DateTime createdAt;
  final DateTime lastModifiedAt;
}
```

### 18.2 Service

```dart
class TestInstrumentService {
  Future<TestInstrument> create(TestInstrument instrument);
  Future<List<TestInstrument>> getMyInstruments();
  Future<List<TestInstrument>> getOverdueCalibrations();
  Future<List<TestInstrument>> getInstrumentsForType(InstrumentType type);
}
```

### 18.3 Screens

**File:** `lib/screens/instruments/my_instruments_screen.dart` (NEW)
**File:** `lib/screens/instruments/instrument_detail_screen.dart` (NEW) — including certificate upload

### 18.4 Integration

- ServiceRecord → optional `instrumentIdsUsed` field (which instruments contributed to this test)
- Push notification 30 days before calibration due
- Block test save if instrument is overdue (warn, allow override with reason)
- Compliance report includes "Test Instruments Used" section with calibration status

### 18.5 Remote Config Flag

`equipment_calibration_enabled` (default false)

---

## 19. Customer Self-Booking

**Why this matters:** Customer logs in, sees their service is due, books a slot themselves. Reduces dispatcher workload and gives customers immediate gratification.

Depends on Customer Portal (feature 2).

### 19.1 Data Models

**File:** `lib/models/booking_window.dart` (NEW)

```dart
class BookingWindow {
  final String id;
  final String companyId;
  final DateTime date;
  final int slotMinutesEach;          // e.g. 240 (4-hour windows)
  final int startMinute;              // 480 = 8am
  final int endMinute;                // 1080 = 6pm
  final List<BookingSlot> slots;
}

class BookingSlot {
  final String id;
  final DateTime startTime;
  final DateTime endTime;
  final int capacity;                 // how many bookings allowed
  final int currentBookings;
  final List<String> assignableEngineerIds;
  final bool available;
}

class CustomerBooking {
  final String id;
  final String customerPortalUserId;
  final String slotId;
  final String? siteId;
  final String requestedJobType;
  final String? notes;
  final String status;                // 'pending', 'confirmed', 'cancelled'
  final DateTime createdAt;
}
```

### 19.2 Workflow

1. Admin defines booking calendar (which days, slots, capacities)
2. Customer logs into portal, sees "Book a service" button
3. Customer selects date, slot, site, optional notes
4. Booking created in pending state
5. Dispatcher receives notification → confirms or proposes alternative
6. Confirmed → DispatchedJob created automatically

### 19.3 Screens (Customer Portal)

**File:** `lib/screens/customer_portal/portal_book_service_screen.dart` (NEW)

### 19.4 Screens (Admin)

**File:** `lib/screens/dispatch/booking_calendar_screen.dart` (NEW) — define availability
**File:** `lib/screens/dispatch/booking_requests_screen.dart` (NEW) — review pending bookings

### 19.5 Edge Cases

- Customer books then cancels at last minute → fee policy?
- Customer books for a site they don't have access to → blocked
- Slot fully booked → real-time availability check on confirm

### 19.6 Remote Config Flag

`customer_self_booking_enabled` (default false)

---

## 20. Accounting Software Export

**Why this matters:** Manual reconciliation between FireThings invoices and accounting software (Xero, QuickBooks, FreeAgent, Sage) is the #1 customer complaint about competing apps. Export reduces friction.

### 20.1 Approach

Each integration is its own ~1-2 week project. Build them one at a time based on customer demand.

### 20.2 Priority Order (UK market)

1. **Xero** — most popular UK SME accounting platform; rich API
2. **QuickBooks Online** — second most popular
3. **FreeAgent** — popular with sole traders
4. **Sage Business Cloud** — enterprise

### 20.3 Per-Integration Implementation

For each:

#### OAuth flow

User connects FireThings to their accounting account via OAuth. Tokens stored in `companies/{companyId}/integrations/{provider}` (encrypted).

#### Mapping

- FireThings Customer → Accounting Contact
- FireThings Invoice → Accounting Invoice
- FireThings Quote → Accounting Quote (if supported)
- Catalog Parts → Accounting Items

UI to map these on first connection (e.g. "Map FireThings 'Battery Replacement' to Xero account 'Sales — Maintenance'").

#### Sync

- Manual: "Push to Xero" button on each invoice
- Automatic: Background sync every X minutes for new invoices
- Bidirectional payment status: when invoice marked paid in accounting, mirror to FireThings

#### Reporting

- Sync log (success/failure per item)
- Reconciliation report (invoices in FireThings vs accounting, mismatches)

### 20.4 Service

**File:** `lib/services/accounting_export_service.dart` (NEW)

Abstract base + per-provider implementations.

### 20.5 Screens

**File:** `lib/screens/integrations/integrations_screen.dart` (NEW)
**File:** `lib/screens/integrations/connect_xero_screen.dart` (NEW)
etc.

### 20.6 Cloud Function

OAuth callback handlers (cannot be done client-side).

### 20.7 Remote Config Flags

`xero_integration_enabled`, `quickbooks_integration_enabled`, etc.

---

## Appendix — Cross-Cutting Concerns

These apply to every feature you implement:

### A. Remote Config Gating

Every new feature ships behind a `_enabled` flag, default false. Tester rollout via existing `dispatch_tester` user property pattern.

### B. Permissions

Every new feature with company-side data needs an entry in the permission matrix and the `CompanyMember` model.

### C. Analytics

Every new feature adds events to `AnalyticsService` following the existing naming pattern.

### D. Web Portal

Every feature should consider whether it needs a web equivalent — most do. Web routes in `lib/screens/web/`.

### E. SQLite Schema

Solo engineer features need SQLite tables in `database_helper.dart` with migrations. Bump DB version per release.

### F. Documentation

Each feature lands with:
- Update to `FEATURES.md`
- Entry in `CHANGELOG.md`
- Optional: standalone help doc in marketing site

### G. Testing

Each feature should have:
- Unit tests for service logic
- Integration test for the primary workflow
- Visual regression test for any new PDF
- Cross-platform smoke test (Android, iOS, Web)

---

## How to Pick Your Next Feature

If you're optimising for **revenue retention**, pick #1 and #4 (recurring jobs + contracts).
If you're optimising for **differentiation vs Uptick**, pick #2 (customer portal).
If you're optimising for **engineer productivity**, pick #3 then #6 then #9 (catalog → site access → van stock).
If you're optimising for **BS 5839 compliance completeness**, pick #7 and #8 (false alarm log + disablement register).
If you're optimising for **fastest wins**, pick #6, #11, #12 (each <1 week, big quality-of-life impact).

Hand off the relevant section to Claude Code with a note like:

> "Implement feature 1 (Recurring Jobs) from FEATURE_GAPS_SPEC.md. Apply the same conventions as ASSET_REGISTER_SPEC.md and BS5839_COMPLIANCE_SPEC.md. Don't break any existing features."

---

*End of feature gaps specification.*
