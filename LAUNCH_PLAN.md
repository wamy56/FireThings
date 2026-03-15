# FireThings — Complete Launch Plan

**Updated:** 15 March 2026  
**Status:** Pre-beta — external setup nearly complete, approaching tester rollout

---

## Table of Contents

1. [Executive Summary & Strategic Options](#1-executive-summary--strategic-options)
2. [Phase Overview & Timeline](#2-phase-overview--timeline)
3. [Current Progress — What's Done](#3-current-progress--whats-done)
4. [Pre-Testing Technical Setup (Code)](#4-pre-testing-technical-setup-code)
5. [External Configuration — Firebase Console](#5-external-configuration--firebase-console)
6. [External Configuration — App Store Connect](#6-external-configuration--app-store-connect)
7. [External Configuration — Android Distribution](#7-external-configuration--android-distribution)
8. [External Configuration — Codemagic & Keystore](#8-external-configuration--codemagic--keystore)
9. [Legal & Compliance Requirements](#9-legal--compliance-requirements)
10. [Cloud Sync Architecture & Security](#10-cloud-sync-architecture--security)
11. [Phase 1: Closed Beta (Months 1–3)](#11-phase-1-closed-beta-months-13)
12. [Phase 2: Soft Launch with Pricing (Months 3–6)](#12-phase-2-soft-launch-with-pricing-months-36)
13. [Phase 3: Wider Launch (Months 6–12)](#13-phase-3-wider-launch-months-612)
14. [Phase 4: Scale or Sell (12+ Months)](#14-phase-4-scale-or-sell-12-months)
15. [Pricing Strategy](#15-pricing-strategy)
16. [Future Feature: Job Dispatch System](#16-future-feature-job-dispatch-system)
17. [Master Checklist — All Items by Status](#17-master-checklist--all-items-by-status)
18. [Ordered Action List — Every Remaining Step](#18-ordered-action-list--every-remaining-step)

---

## 1. Executive Summary & Strategic Options

FireThings is a cross-platform Flutter application built specifically for fire alarm engineers. It combines jobsheet creation, invoicing, PDF certificate generation, and a suite of field tools into a single offline-first app backed by Firebase Auth and local SQLite storage. It targets Android, iOS, Windows, macOS, Linux, and web.

This document is the single consolidated plan for taking FireThings from development through internal testing with colleagues, to a priced product, and eventually to a wider market launch or potential sale.

### Strategic Options

- Build a subscription business serving fire alarm engineers across the UK
- Keep it as a profitable side project generating steady recurring revenue
- Develop to a point of proven traction and sell to a larger fire safety software company
- License specific components (PDF certificates, jobsheet engine) to other companies

These options are not mutually exclusive. The plan is structured so that each phase builds value regardless of which exit you ultimately choose. The recommendation is to focus on building for your users and let traction guide the decision.

### Future Direction: Job Dispatch

A job dispatch system (similar to Jobber) is planned as a Phase 3/4 feature addition. This would allow office staff to assign jobs to engineers, with push notifications, real-time status tracking, and seamless integration into the existing jobsheet workflow. A full technical specification exists in `DISPATCH_FEATURE_SPEC.md`. This feature is not part of the initial launch — it will be pre-built but only launched after the core app is validated and generating revenue. See Section 16 for a summary.

---

## 2. Phase Overview & Timeline

| Phase | Timeline | Focus | Revenue |
|-------|----------|-------|---------|
| Phase 1 | Months 1–3 | Closed beta with colleagues, bug fixing, analytics | None |
| Phase 2 | Months 3–6 | Introduce pricing, expand via word of mouth | First subscribers |
| Phase 3 | Months 6–12 | Wider launch, marketing, industry presence | Growing MRR |
| Phase 4 | 12+ months | Scale the business, add dispatch feature, or explore acquisition | Established ARR |

Each phase has specific entry criteria and deliverables. Do not skip phases — the feedback and data from each stage directly informs the decisions in the next.

---

## 3. Current Progress — What's Done

### 3.1 Technical Setup (Code — All Complete)

| Status | Task | Details |
|--------|------|---------|
| ✅ DONE | Firestore cloud sync | SQLite primary, Firestore backup — Session 1 |
| ✅ DONE | Firestore security rules | Per-user isolation, deployed — Sessions 1 & 7 |
| ✅ DONE | Firebase Crashlytics | runZonedGuarded, FlutterError, PlatformDispatcher — Session 7 |
| ✅ DONE | Firebase Analytics (22 events) | Feature usage, screen tracking — Session 2 |
| ✅ DONE | In-app feedback mechanism | Pre-filled email with device info — Session 3 |
| ✅ DONE | Remote Config (10 feature flags) | Server-side toggling — Session 4 |
| ✅ DONE | Account deletion (GDPR) | Full Firestore + Auth data wipe — Session 5 |
| ✅ DONE | In-app privacy policy | 8-section policy screen — Session 6 |
| ✅ DONE | Info.plist permission strings | All 6 permissions with clear descriptions |
| ✅ DONE | Export compliance flag | ITSAppUsesNonExemptEncryption = false |

**All code-side pre-testing work is complete.**

### 3.2 External Setup Progress

| Status | Task | Details |
|--------|------|---------|
| ✅ DONE | Firebase: Analytics verified | Events confirmed — photos, tools, features appearing |
| ✅ DONE | Firebase: Remote Config working | 10 boolean params created, published, and tested — toggling works |
| ✅ DONE | Firebase: Crashlytics working | Test crash triggered and confirmed appearing in dashboard |
| ✅ DONE | Firebase: security rules verified | Per-user isolation confirmed in Rules tab |
| ✅ DONE | Firebase: Auth provider verified | Email/Password sign-in confirmed enabled |
| ✅ DONE | ASC: App Privacy form | All collected data types declared |
| ✅ DONE | ASC: public TestFlight link | External testers can use public link to install |
| ✅ DONE | ICO registration | Registered, paid, registration number received and added to privacy policy |
| ✅ DONE | Codemagic pipeline verified | Builds and uploads to TestFlight successfully |
| ✅ DONE | Privacy policy public URL | Uploaded to GitHub — public URL available |
| ✅ DONE | IS_ANALYTICS_ENABLED fixed | Changed from false to true in GoogleService-Info.plist |
| ⬜ TODO | Firebase: App Distribution | Create Beta Testers group for Android — do when ready for Android |
| ⬜ TODO | Google DPA | Could not find signing page — Firebase Console doesn't show it clearly, and the Google link shows information only with nothing to sign. May already be covered by Firebase ToS. Low priority. |
| ⬜ TODO | Back up Android keystore | Not urgent — starting with iOS first. Do before any Android distribution. |

### 3.3 Important Note: Firestore Console Data Visibility

You can see all users' data (invoice amounts, engineer IDs, etc.) in the Firebase Console. **This is expected and not a security flaw.** The Firebase Console gives the project owner full read access regardless of security rules. Security rules only apply to client-side access through the app. Testers cannot see each other's data through the app. You, as the admin, can see everything through the console. This is useful for debugging and support.

---

## 4. Pre-Testing Technical Setup (Code)

This section documents the full technical architecture that has been built. It serves as a reference for what exists in the codebase.

### 4.1 Cloud Sync with Firestore

**Architecture:**
- SQLite remains the primary local data source (preserves offline-first capability)
- Firestore acts as a sync/backup layer — writes fire-and-forget when connectivity is available
- Each user's data stored under their Firebase Auth UID: `users/{uid}/`
- Collections synced: jobsheets, invoices, saved_customers, saved_sites, job_templates, filled_templates, pdf_config

**Sync Strategy:**
- On data change: write to local SQLite first, then queue a Firestore write
- On app launch: bidirectional merge (performFullSync) pulls remote changes and pushes local changes
- Conflict resolution: last-write-wins via lastModifiedAt timestamps on all synced models
- Firestore persistence enabled with unlimited cache — SDK handles offline queuing

**Security Rules:**
- Per-user data isolation enforced via `firestore.rules` at project root
- All data under `users/{userId}/**` requires `request.auth.uid == userId`
- Rules deployed via `firebase deploy --only firestore:rules`

### 4.2 Firebase Crashlytics

- `firebase_crashlytics: ^5.0.7` in pubspec.yaml
- `runZonedGuarded` wraps entire app bootstrap to catch async errors
- `FlutterError.onError` captures Flutter framework errors
- `PlatformDispatcher.instance.onError` captures platform-level errors
- iOS auto-registered via FlutterFire generated plugin registrant
- **Verified working** — test crash confirmed appearing in Firebase Console dashboard for both iOS and Android

### 4.3 Firebase Analytics

- `firebase_analytics: ^12.1.2` in pubspec.yaml
- `AnalyticsService` singleton wrapping `FirebaseAnalytics.instance`
- `FirebaseAnalyticsObserver` added to `MaterialApp.navigatorObservers` for automatic screen tracking
- 22 custom events instrumented across 14 files (tool opens, jobsheet lifecycle, invoice lifecycle, PDF forms, photo/video capture, login/sign_up)
- **Verified working** — events confirmed appearing in Firebase Console

### 4.4 In-App Feedback Mechanism

- Send Feedback button in Settings opens native email client
- Pre-filled with app version, device info (OS, model) via device_info_plus
- Recipient: cscott93@hotmail.co.uk
- Subject format: `FireThings Feedback — v{version}`

### 4.5 Remote Config & Feature Flags

- `firebase_remote_config: ^6.1.4` in pubspec.yaml
- `RemoteConfigService` singleton with 10 feature flags (all default to true)
- 12-hour fetch interval in release, 1-minute in debug
- Home screen tool tiles conditionally rendered based on flag values
- **Verified working** — toggling flags in Firebase Console correctly shows/hides features
- All 10 parameters created and published in Firebase Console

Flags: `timestamp_camera_enabled`, `decibel_meter_enabled`, `dip_switch_calculator_enabled`, `detector_spacing_enabled`, `battery_load_tester_enabled`, `bs5839_reference_enabled`, `invoicing_enabled`, `pdf_forms_enabled`, `cloud_sync_enabled`, `custom_templates_enabled`

### 4.6 Account Deletion (GDPR)

- `deleteAllUserData()` method on `FirestoreSyncService`
- Batch-deletes all documents in 7 subcollections under `users/{uid}/`
- Deletion sequence: re-authenticate → delete Firestore data → delete local SQLite → delete SharedPreferences → delete Firebase Auth account
- Throws on failure (not fire-and-forget) — critical privacy operation

### 4.7 In-App Privacy Policy

- StatelessWidget with ResponsiveListView, no web dependency
- 8 sections: data collected, purpose, storage location, retention, access rights, user rights, third-party services, contact info
- ICO registration number added
- Accessible from Settings between Permissions and About

### 4.8 Info.plist & Export Compliance

- All 6 permission strings present with specific, context-aware descriptions
- `ITSAppUsesNonExemptEncryption` set to false (standard HTTPS/TLS only)
- `IS_ANALYTICS_ENABLED` set to true in GoogleService-Info.plist

---

## 5. External Configuration — Firebase Console

### Completed Items

| Item | Status | Notes |
|------|--------|-------|
| Firestore database active | ✅ | Data visible, rules deployed |
| Security rules deployed | ✅ | Per-user isolation confirmed |
| Firebase Auth (Email/Password) | ✅ | Enabled and working |
| Crashlytics | ✅ | Test crash confirmed on both iOS and Android |
| Analytics | ✅ | Events appearing, Realtime working |
| Remote Config (10 params) | ✅ | All created, published, and tested |

### Remaining Items

**Firebase App Distribution (Android)** — set up when ready for Android testers:
- Firebase Console → Release & Monitor → App Distribution
- Create a "Beta Testers" group
- Add colleagues' email addresses
- Configure Codemagic to upload Android builds to App Distribution

**Google DPA** — the standard Google link (privacy.google.com/businesses/processorterms/) shows information but no clear signing mechanism. The Firebase Console doesn't have an obvious Privacy/Data Processing section. This may already be covered by the Firebase Terms of Service accepted when creating the project. Low priority — revisit if a specific legal need arises.

---

## 6. External Configuration — App Store Connect

### Completed Items

| Item | Status |
|------|--------|
| App Privacy details declared | ✅ All 7 data categories |
| Public TestFlight link | ✅ External testers can use public link |
| Info.plist permissions | ✅ Already done in code |
| Export compliance | ✅ Already done in code |

### Adding Testers

You now have a public TestFlight link, which means external testers can join without being manually added as internal testers. Share this link with your 3–5 colleagues. They'll need to:
1. Install the TestFlight app from the App Store (if not already installed)
2. Open your public link on their iPhone
3. Accept the invitation and install FireThings

Note: the first build sent to external testers via a public link requires Beta App Review from Apple. This usually takes 1–2 days. If you haven't triggered this yet, submit a build for review before sharing the link.

### Google Play Console (Phase 2 — Not Yet)

Not needed for beta testing — Firebase App Distribution handles Android. When ready for public launch:
- Create a Google Play Developer account (£20 one-time)
- Complete app content declarations
- Set up closed testing track, then production

---

## 7. External Configuration — Android Distribution

### Firebase App Distribution (When Ready)

Set up when you're ready to include Android testers:
- Firebase Console → Release & Monitor → App Distribution
- Create a "Beta Testers" group and add colleagues' emails
- Configure Codemagic to upload Android builds to App Distribution automatically

### Android Keystore Backup

Do this before any Android distribution. Takes 2 minutes, prevents catastrophic data loss:
- Locate your `.jks` or `.keystore` file
- Copy to at least 2 secure locations (encrypted cloud storage, password manager)
- Save key alias, keystore password, and key password alongside it

---

## 8. External Configuration — Codemagic & CI/CD

**Status: ✅ Working.** Codemagic builds and uploads to TestFlight successfully. When ready for Android distribution, add the Firebase App Distribution upload step to `codemagic.yaml`.

---

## 9. Legal & Compliance Requirements

### 9.1 UK GDPR & Data Protection Act 2018

Since you are UK-based and users store customer names, site addresses, job details, and financial information, you fall under UK GDPR with cloud sync active.

**ICO Registration — ✅ DONE**
- Registered, paid, registration number received
- Registration number added to in-app privacy policy

**Privacy Policy — ✅ DONE**
- In-app privacy policy built (Session 6) with 8 sections
- Public URL version uploaded to GitHub
- ICO registration number included

**Lawful Basis for Processing:** Contract — users agree to terms that include cloud storage, you process data to deliver the service.

**Data Processing Agreement:** Google DPA signing page was not accessible via the provided links. May be covered by Firebase ToS. Low priority.

**Right to Erasure — ✅ DONE:** Full account deletion implemented (Session 5).

### 9.2 Terms of Service (Needed Before Charging)

Write clear terms covering:
- What the app does and doesn't guarantee
- Limitation of liability (especially for BS 5839 reference data and calculator outputs)
- Subscription terms, renewal, and cancellation
- Account termination conditions
- Intellectual property (you own the app, users own their data)

### 9.3 Business Entity (Needed Before Charging)

Sole trader registration sufficient initially. Register with HMRC for self-assessment. Consider Ltd once revenue justifies admin overhead.

### 9.4 Professional Indemnity Insurance (Consider for Phase 2+)

Your app references BS 5839 compliance standards. Engineers may rely on calculator outputs. PI insurance protects against claims if a calculation were wrong.

### 9.5 Financial Data Considerations

Invoice amounts are not "special category data" under GDPR. Per-user Firestore isolation ensures privacy architecturally. Consider end-to-end encryption as a future enhancement.

---

## 10. Cloud Sync Architecture & Security

### 10.1 Data Flow (Implemented)

1. User creates or edits data in the app
2. Data writes to local SQLite immediately (app works offline)
3. Fire-and-forget Firestore write queued for when connectivity is available
4. On app launch: bidirectional merge pulls remote changes, pushes local changes
5. Conflict resolution: last-write-wins using lastModifiedAt timestamps

### 10.2 Security Rules (Implemented & Deployed)

- Per-user isolation: `users/{userId}/**` only accessible when `request.auth.uid == userId`
- Authentication required for all reads and writes
- Verified in Firebase Console Rules tab
- Note: Firebase Console gives project owner full access regardless of rules — this is normal admin behaviour, not a security flaw

### 10.3 Encryption

- **In transit:** TLS/HTTPS for all API calls (Firebase handles by default)
- **At rest:** Firestore encrypts stored data by default
- **Optional E2E:** Future enhancement — encrypt on-device before upload

### 10.4 Account Deletion Flow (Implemented)

1. User requests deletion from Settings
2. Re-authentication required
3. All Firestore documents deleted (7 subcollections, batch-delete in groups of 500)
4. User document deleted
5. Local SQLite database cleared
6. SharedPreferences and branding assets cleared
7. Firebase Auth account deleted
8. User returned to login screen

---

## 11. Phase 1: Closed Beta (Months 1–3)

Timeline: Months 1–3 | Revenue: None | Goal: Validate the product with real users

### 11.1 Tester Selection

Pick 3–5 engineers you trust to use the app on real jobs. Prioritise colleagues who:
- Do a variety of job types (installations, maintenance, inspections, fault-finding)
- Are comfortable giving honest feedback, including negative feedback
- Use different devices (mix of iOS and Android if possible)
- Will use it regularly, not just try it once

### 11.2 Feedback Infrastructure

- Create a WhatsApp or Signal group for the testing team
- Set expectations: you want bug reports, feature requests, and honest opinions
- Check in weekly — don't wait for testers to come to you
- The in-app Send Feedback button supplements but does not replace direct communication

### 11.3 What to Observe

Analytics data and direct observation will inform pricing and development decisions:
- Which of the six pre-built templates actually get used on real jobs?
- Do testers use the helpful tools (DIP switch, decibel meter, etc.) regularly or try them once?
- Is the timestamp camera a must-have or a nice-to-have?
- Are testers creating custom templates or sticking with pre-built ones?
- How often is PDF generation triggered? Are PDFs being shared/emailed?
- Is anyone using invoicing, or is it secondary to jobsheets?

### 11.4 Daily & Weekly Routines

**Daily:**
- Check Crashlytics for new crashes — fix recurring ones immediately
- Respond to bug reports from the tester group

**Weekly:**
- Review Firebase Analytics: which features are used, which are ignored?
- Check in with testers directly — ask what's working and what's frustrating
- Push bug fixes via Codemagic → TestFlight / App Distribution

### 11.5 Feature Request Management

Categorise every request as:
- **Critical** — blocks real workflow, fix now
- **Nice-to-have** — would improve experience, add to Phase 2/3 backlog
- **Future** — interesting but not needed yet, park it

Resist the urge to build everything. Focus on stability and core workflow reliability.

### 11.6 Exit Criteria

Move to Phase 2 when:
- No major crashes for two consecutive weeks
- At least 3 testers using it regularly on real jobs
- Core workflows (create jobsheet → generate PDF → share) work reliably
- Cloud sync functions without data loss
- You have a clear picture of which features matter most

---

## 12. Phase 2: Soft Launch with Pricing (Months 3–6)

Timeline: Months 3–6 | Revenue: First subscribers | Goal: Prove people will pay

### 12.1 Pricing

See Section 15 for full pricing strategy. Key decisions:
- Set a price accessible for self-employed engineers (£9.99–£14.99/month)
- Offer annual pricing at a discount (£99–£149/year saves ~2 months)
- Consider a free tier with limited features (tools free, jobsheets/invoicing paid)
- Give beta testers a discounted or free period — they earned it

### 12.2 Payment Integration

- **RevenueCat** — cross-platform subscription management, handles both App Store and Play Store
- **StoreKit / Google Play Billing** — direct integration for lower-level control
- **Stripe** — web subscriptions to avoid 15–30% app store commission (users sign up via website)

### 12.3 Word of Mouth

Ask testers to recommend the app to engineers they know. Word of mouth in trades is exceptionally powerful.

### 12.4 Landing Page

- Clear description of what FireThings does
- Screenshots showing key features
- Pricing information
- App Store and Play Store download links
- Email capture for interested engineers

### 12.5 Legal Completion Before Charging

- ICO registration — ✅ done
- Privacy policy published in-app and on website — ✅ done
- Terms of service published
- Business entity registered (sole trader or Ltd)
- Data deletion mechanism — ✅ done

---

## 13. Phase 3: Wider Launch (Months 6–12)

Timeline: Months 6–12 | Revenue: Growing MRR | Goal: Establish market presence

### 13.1 Entry Criteria

Only proceed if Phase 2 demonstrates traction: 20–50 paying users with low churn and positive feedback.

### 13.2 Marketing Channels

- Fire alarm engineer Facebook groups and forums (several active UK communities)
- Trade shows and local BAFE/FIA events
- Partnerships with fire safety training providers
- Content marketing: short videos showing the app on real jobs
- Fire safety trade publications and websites

### 13.3 Trust & Credibility

- Collect testimonials from beta testers and early paying users
- Case studies showing time saved or workflow improvements
- Engineer testimonials carry more weight than marketing copy

### 13.4 Feature Development

Based on Phases 1–2 feedback, prioritise retention-driving features:
- Multi-device sync
- Photo attachment to jobsheets from timestamp camera
- Recurring job scheduling
- Customer portal or email notifications for invoice tracking
- Export to accounting software (Xero, QuickBooks, FreeAgent)
- **Job Dispatch System** — see Section 16

### 13.5 App Store Optimisation

- Professional screenshots showing real app functionality
- Clear, keyword-rich description targeting fire alarm engineers
- Appropriate category (Business or Utilities)
- Respond to reviews promptly and professionally

---

## 14. Phase 4: Scale or Sell (12+ Months)

Timeline: 12+ months | Goal: Decide long-term direction

### 14.1 Option A: Keep and Grow

Vertical SaaS in niche trades can be surprisingly strong:
- Churn is low — engineers don't switch tools easily once embedded in workflow
- Market is underserved — no dominant app covers everything FireThings does
- Expansion into adjacent trades possible (emergency lighting, security systems, AOV)
- Job dispatch system unlocks team/company pricing tier (significantly higher revenue per account)

### 14.2 Option B: Sell

Potential acquirers: fire safety software companies, field service management platforms, private equity firms. Sale price: 3–5x annual recurring revenue (ARR).

| Users | Annual Price | ARR | Estimated Sale Price |
|-------|-------------|-----|---------------------|
| 100 | £120/year | £12,000 | £36,000 – £60,000 |
| 300 | £120/year | £36,000 | £108,000 – £180,000 |
| 500 | £120/year | £60,000 | £180,000 – £300,000 |
| 1,000 | £120/year | £120,000 | £360,000 – £600,000 |

With dispatch feature and team pricing (£20–30/user/month), revenue per account increases significantly.

### 14.3 Option C: License

White-label FireThings or license components (PDF certificates, jobsheet engine) to other companies.

### 14.4 Recommendation

Don't optimise for sale. Build for users, charge a fair price, let traction guide the decision.

---

## 15. Pricing Strategy

### 15.1 Market Context

Fire alarm engineers currently spend £20–£40/month on certification software, PDF tools, and job management. FireThings undercuts these with a more focused, industry-specific solution.

### 15.2 Recommended Pricing

| Tier | Monthly | Annual | Savings |
|------|---------|--------|---------|
| Free | £0 | £0 | — |
| Pro | £9.99 – £14.99 | £99 – £149 | ~2 months free |
| Team (future) | £20 – £30/user | £200 – £300/user | With dispatch |

**Free Tier:**
- All six helpful tools
- Limited jobsheet creation (e.g. 3 per month)
- No invoicing, no PDF certificates, no cloud sync

**Pro Tier:**
- Everything in Free
- Unlimited jobsheets and invoices
- PDF certificate forms
- Custom template builder
- Cloud sync and backup
- PDF design customisation
- Priority support

**Team Tier (future, with dispatch):**
- Everything in Pro
- Job dispatch system
- Company branding on all documents
- Team management
- Shared company sites and customers
- Push notifications for job assignments

### 15.3 Pricing Principles

- Start at the lower end and increase once value is proven
- Feature annual plans prominently — they reduce churn and improve cash flow
- Beta testers receive a loyalty discount or extended free period
- Review pricing after 6 months based on usage data and churn rates

---

## 16. Future Feature: Job Dispatch System

### Overview

A job dispatch system that allows office staff to create and assign jobs to engineers, with real-time status tracking, push notifications, and seamless integration into the existing jobsheet and invoicing workflow. Similar to apps like Jobber but specifically built for fire alarm engineers.

**Full technical specification:** See `DISPATCH_FEATURE_SPEC.md` (separate document).

### When to Build

Build this after the core app is validated and generating revenue — Phase 3 at the earliest. The dispatch feature is the thing that justifies a higher "Team" pricing tier. Sequence:
1. Launch solo-engineer app (current plan)
2. Validate with colleagues, start charging
3. Build dispatch with your own company (15–20 engineers) as the first pilot
4. Offer as a premium tier to other fire alarm companies

### What It Includes

- **User roles:** Admin, Dispatcher (office), Engineer
- **Company/team structure** with invite codes for joining
- **Job creation and assignment** by dispatchers with full details (site address, parking, contact, job type, system info)
- **Job lifecycle:** Created → Assigned → Accepted → En Route → On Site → Completed
- **Push notifications** via Firebase Cloud Messaging when jobs are assigned or status changes
- **Engineer job view** with map, directions, contact info, and status updates
- **Jobsheet integration** — create a jobsheet directly from a dispatched job with pre-filled data
- **Company PDF branding** — company-level header, footer, and colour scheme automatically applied to dispatched job documents; personal branding for personal documents
- **Shared company sites and customers** — accessible to all team members
- **Real-time updates** via Firestore snapshot listeners

### Architecture Impact

- New Firestore collection: `companies/{companyId}/` with subcollections for members, dispatched_jobs, sites, customers, pdf_config
- Existing personal data (`users/{uid}/`) unchanged
- Expanded Firestore security rules for company data
- Firebase Cloud Functions (Blaze plan) for push notifications
- FCM integration for device tokens and notification handling
- New screens: ~12 new screens across dispatcher and engineer views

### Revenue Impact

If your company alone had 15 engineers on a team plan at £25/user/month, that's £375/month (£4,500/year) from a single customer. Five companies like yours = £22,500/year ARR.

---

## 17. Master Checklist — All Items by Status

### Code / In-App (All Done)

| Status | Task | Details |
|--------|------|---------|
| ✅ | Firestore cloud sync | SQLite primary, Firestore backup |
| ✅ | Firestore security rules (code) | firestore.rules at project root |
| ✅ | Firebase Crashlytics (code) | runZonedGuarded, error handlers |
| ✅ | Firebase Analytics (22 events) | AnalyticsService singleton, 14 files |
| ✅ | In-app feedback mechanism | Send Feedback button, pre-filled email |
| ✅ | Remote Config (10 flags, code) | RemoteConfigService, conditional UI |
| ✅ | Account deletion (GDPR) | Full Firestore + Auth + local data wipe |
| ✅ | In-app privacy policy | 8-section privacy screen + ICO number |
| ✅ | Info.plist permissions | 6 specific permission strings |
| ✅ | Export compliance | ITSAppUsesNonExemptEncryption = false |

### External Setup (Done)

| Status | Task | Details |
|--------|------|---------|
| ✅ | Firebase: Analytics verified | Events appearing in dashboard |
| ✅ | Firebase: Remote Config working | 10 params created, published, tested |
| ✅ | Firebase: Crashlytics working | Test crash confirmed on iOS and Android |
| ✅ | Firebase: security rules verified | Per-user isolation in Rules tab |
| ✅ | Firebase: Auth provider verified | Email/Password confirmed |
| ✅ | ASC: App Privacy form | All data categories declared |
| ✅ | ASC: public TestFlight link | External testers can join via link |
| ✅ | ICO registration | Registered, paid, number received, added to policy |
| ✅ | Codemagic pipeline | Builds and uploads to TestFlight |
| ✅ | Privacy policy public URL | Uploaded to GitHub |
| ✅ | IS_ANALYTICS_ENABLED fixed | Set to true in GoogleService-Info.plist |

### External Setup (Remaining)

| Status | Task | Details | When |
|--------|------|---------|------|
| ⬜ | Firebase: App Distribution | Android tester group | When ready for Android |
| ⬜ | Back up Android keystore | .jks to secure locations | Before Android distribution |
| ⬜ | Google DPA | Signing page not accessible — may be covered by Firebase ToS | Low priority |

### Before Inviting Testers

| Status | Task | Details | When |
|--------|------|---------|------|
| ⬜ | Create tester WhatsApp group | Set feedback expectations | This week |
| ⬜ | Share TestFlight public link | With 3–5 colleagues | This week |
| ⬜ | Ensure Beta App Review passed | First external build needs Apple review | Before sharing link |

### During Beta (Months 1–3)

| Status | Task | When |
|--------|------|------|
| ⬜ | Monitor Crashlytics daily | Daily |
| ⬜ | Review analytics weekly | Weekly |
| ⬜ | Weekly tester check-ins | Weekly |
| ⬜ | Catalogue feature requests | Ongoing |

### Phase 2 Preparation (During Beta)

| Status | Task | When |
|--------|------|------|
| ⬜ | Write terms of service | Month 2 |
| ⬜ | Register as sole trader (HMRC) | Month 2 |
| ⬜ | Research payment integration | Month 2–3 |
| ⬜ | Decide pricing tiers | Month 3 |
| ⬜ | Create landing page | Month 3 |

### Phase 2 Launch (Months 3–6)

| Status | Task | When |
|--------|------|------|
| ⬜ | Implement payment system | Month 3–4 |
| ⬜ | Enable free/pro tier gating | Month 3–4 |
| ⬜ | Publish website + public privacy policy | Month 4 |
| ⬜ | Beta tester loyalty offer | Month 4 |
| ⬜ | Google Play Developer account (£20) | Month 4–5 |
| ⬜ | Full App Store listings | Month 5–6 |
| ⬜ | Consider PI insurance | Month 5–6 |

### Phase 3+ (Months 6–12+)

| Status | Task | When |
|--------|------|------|
| ⬜ | Collect user testimonials | Month 6+ |
| ⬜ | Join fire safety communities | Month 6+ |
| ⬜ | Explore BAFE/FIA events | Month 6+ |
| ⬜ | Create demo videos | Month 7+ |
| ⬜ | Contact trade publications | Month 8+ |
| ⬜ | **Begin dispatch feature development** | **Month 6–9** |
| ⬜ | Explore accounting integrations | Month 9+ |
| ⬜ | Review pricing (add Team tier) | Month 9+ |

---

## 18. Ordered Action List — Every Remaining Step

### Part A: Launch Beta (This Week)

| # | Action | Details | Time |
|---|--------|---------|------|
| 1 | Create tester WhatsApp group | Set expectations: bugs, features, honest opinions | 5 min |
| 2 | Check Beta App Review status | Ensure external build has passed Apple's beta review | 5 min |
| 3 | Share TestFlight public link | Send to 3–5 colleagues | 5 min |

**Total: ~15 minutes. After step 3, your iOS testers have the app.**

### Part B: When Ready for Android Testers

| # | Action | Details | Time |
|---|--------|---------|------|
| 4 | Back up Android keystore | Copy .jks to 2+ secure locations + save passwords | 5 min |
| 5 | Set up App Distribution | Firebase Console → create Beta Testers group | 5 min |
| 6 | Add Android testers | Add colleagues' emails to the group | 5 min |
| 7 | Add App Distribution to Codemagic | Upload step in codemagic.yaml | 15 min |

### Part C: During Beta (Ongoing)

| # | Action | Details | When |
|---|--------|---------|------|
| 8 | Monitor Crashlytics daily | Fix recurring crashes same-day | Daily |
| 9 | Review analytics weekly | Feature usage patterns and adoption | Weekly |
| 10 | Weekly tester check-ins | Active outreach, don't wait for reports | Weekly |
| 11 | Catalogue feature requests | Critical / nice-to-have / future | Ongoing |

### Part D: Phase 2 Preparation (Months 2–3)

| # | Action | Details | When |
|---|--------|---------|------|
| 12 | Write terms of service | Liability, subscriptions, data ownership | Month 2 |
| 13 | Register as sole trader | HMRC self-assessment registration | Month 2 |
| 14 | Research payment integration | RevenueCat vs StoreKit/Play Billing vs Stripe | Month 2–3 |
| 15 | Decide pricing tiers | Based on analytics: what's free vs pro | Month 3 |
| 16 | Create landing page | One-page site with screenshots and pricing | Month 3 |

### Part E: Phase 2 Launch (Months 3–6)

| # | Action | Details | When |
|---|--------|---------|------|
| 17 | Implement payment system | RevenueCat or StoreKit + Play Billing | Month 3–4 |
| 18 | Enable free/pro tier gating | Use existing Remote Config flags | Month 3–4 |
| 19 | Publish website + privacy policy | Public-facing, linked from app stores | Month 4 |
| 20 | Beta tester loyalty offer | Discount or extended free period | Month 4 |
| 21 | Google Play Developer account | £20 one-time, for public Android launch | Month 4–5 |
| 22 | Full App Store listings | Screenshots, descriptions, keywords | Month 5–6 |
| 23 | Consider PI insurance | Covers BS 5839 calculation reliance | Month 5–6 |

### Part F: Phase 3+ Growth (Months 6–12+)

| # | Action | Details | When |
|---|--------|---------|------|
| 24 | Collect user testimonials | Written or video from engineers | Month 6+ |
| 25 | Join fire safety communities | Facebook groups, forums | Month 6+ |
| 26 | Explore BAFE/FIA events | Demo opportunities or small stands | Month 6+ |
| 27 | Create demo videos | Real on-site usage of key features | Month 7+ |
| 28 | **Begin dispatch feature** | **Follow DISPATCH_FEATURE_SPEC.md** | **Month 6–9** |
| 29 | Contact trade publications | Fire safety magazines and websites | Month 8+ |
| 30 | Explore accounting integrations | Xero, QuickBooks, FreeAgent export | Month 9+ |
| 31 | Launch Team pricing tier | With dispatch feature | Month 9–12 |
| 32 | Review and adjust pricing | Based on churn, usage, and team adoption | Month 12+ |

---

*The code is done. The external setup is done. Time to get it into people's hands.*
