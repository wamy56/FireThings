# FireThings — Updated Launch Plan

**Updated:** 12 April 2026  
**Status:** Closed beta in progress — feature development continuing alongside testing

---

## Table of Contents

1. [Executive Summary](#1-executive-summary)
2. [Current Situation Assessment](#2-current-situation-assessment)
3. [Phase Overview & Revised Timeline](#3-phase-overview--revised-timeline)
4. [Phase 1A: Beta Testing & Feature Completion (Now – Month 2)](#4-phase-1a-beta-testing--feature-completion-now--month-2)
5. [Phase 1B: Tester Expansion (Month 2–3)](#5-phase-1b-tester-expansion-month-23)
6. [Phase 2: Soft Launch with Pricing (Months 3–6)](#6-phase-2-soft-launch-with-pricing-months-36)
7. [Phase 3: Wider Launch (Months 6–12)](#7-phase-3-wider-launch-months-612)
8. [Phase 4: Scale, Expand, or Sell (12+ Months)](#8-phase-4-scale-expand-or-sell-12-months)
9. [Defect-to-Quote Feature Plan](#9-defect-to-quote-feature-plan)
10. [Multi-Site Hosting & Marketing Website](#10-multi-site-hosting--marketing-website)
11. [Customer Portal (Future)](#11-customer-portal-future)
12. [Legal & Compliance Requirements](#12-legal--compliance-requirements)
13. [Privacy Policy Updates Required](#13-privacy-policy-updates-required)
14. [Terms of Service](#14-terms-of-service)
15. [Business Structure Guidance](#15-business-structure-guidance)
16. [Payment Integration Strategy](#16-payment-integration-strategy)
17. [Pricing Strategy](#17-pricing-strategy)
18. [Marketing Copy & Screenshots](#18-marketing-copy--screenshots)
19. [Master Checklist by Phase](#19-master-checklist-by-phase)
20. [Ordered Action List](#20-ordered-action-list)

---

## 1. Executive Summary

FireThings is a cross-platform Flutter application built specifically for fire alarm engineers. It combines jobsheet creation, invoicing, PDF certificate generation, asset register management, team job dispatch, quoting, and a suite of field tools into a single offline-first app.

**What's Changed Since the Original Plan:**

The original launch plan was written when dispatch and asset register were future features. They are now **fully built and working**. This updated plan reflects the current reality:

| Feature | Original Status | Current Status |
|---------|-----------------|----------------|
| Job Dispatch System | Future (Phase 3+) | ✅ Complete, feature-flagged |
| Asset Register & Floor Plans | Future | ✅ Complete, feature-flagged |
| Web Portal | Future | ✅ Live at firethings.co.uk |
| Defect-to-Quote | Not planned | 🔨 To build during beta |
| Multi-Site Hosting | Not planned | 📋 Planned for Phase 2 |
| Customer Portal | Not planned | 📋 Future consideration |

**Strategic Shift:** The app is now significantly more complete than originally planned. The goal is to ship a "complete unit" rather than launching with missing features that would cause companies to choose competitors like Uptick.

**Current Challenge:** Your own company has adopted Uptick, which limits internal testing. The plan now includes strategies for finding external testers.

---

## 2. Current Situation Assessment

### What's Working

| Area | Status | Notes |
|------|--------|-------|
| Core App (Jobsheets, Invoicing, Tools) | ✅ Stable | You're using this personally |
| Dispatch System | ✅ Working | Enabled, may need fine-tuning |
| Asset Register | ✅ Working | Cross-platform, most bugs resolved |
| Web Portal | ✅ Live | firethings.co.uk, needs testing |
| TestFlight | ✅ Ready | Public link available |
| Firebase Setup | ✅ Complete | All services configured |
| ICO Registration | ✅ Done | Number in privacy policy |
| HMRC Self-Employed | ✅ Done | No immediate action needed |

### What Needs Work

| Area | Status | Priority |
|------|--------|----------|
| Defect-to-Quote Feature | 🔨 Not started | High — build during beta |
| Terms of Service | ⬜ Not written | High — needed before charging |
| Marketing Website | ⬜ Not started | Medium — needed for Phase 2 |
| External Testers | ⬜ Limited | High — current company on Uptick |
| Android Distribution | ⬜ Not set up | Medium — when ready for Android testers |
| PI Insurance | ⬜ Not researched | Medium — consider before public launch |
| Payment Integration | ⬜ Not started | Medium — needed for Phase 2 |
| Brand Guidelines | ⬜ Logo only | Low — can develop over time |

### The Uptick Problem

Your company has adopted Uptick, which means:
- Internal testers aren't using FireThings regularly for real work
- Feedback is limited because they're not embedded in the workflow
- You need to find testers outside your company

**Solution:** Target fire alarm engineers in online communities and forums. They're more likely to give unbiased feedback and become paying customers.

---

## 3. Phase Overview & Revised Timeline

| Phase | Timeline | Focus | Revenue |
|-------|----------|-------|---------|
| Phase 1A | Now – Month 2 | Build Defect-to-Quote, find external testers | None |
| Phase 1B | Month 2–3 | Expand testing, refine based on feedback | None |
| Phase 2 | Months 3–6 | Marketing site, pricing, first paying users | First subscribers |
| Phase 3 | Months 6–12 | Wider launch, marketing, industry presence | Growing MRR |
| Phase 4 | 12+ months | Scale, add Customer Portal, or exit | Established ARR |

**Key Principle:** Ship a complete app. Don't launch with missing features that give customers a reason to choose Uptick instead.

---

## 4. Phase 1A: Beta Testing & Feature Completion (Now – Month 2)

### 4.1 Defect-to-Quote Development

Build the Defect-to-Quote feature during this phase. This is a core revenue feature for fire contractors — capturing repair revenue when defects are found during inspections.

**Timeline:** ~6–8 weeks (working around day job)

| Week | Focus |
|------|-------|
| 1–2 | Quote model, database schema, QuoteService |
| 3–4 | Quote screens (create, edit, list, hub) |
| 5–6 | Integration (defect bottom sheet, asset detail), PDF generation |
| 7–8 | Email, quote-to-job conversion, analytics, testing |

**See Section 9 for full implementation details.**

### 4.2 Finding External Testers

Since your company is on Uptick, actively recruit external testers:

**Where to Find Fire Alarm Engineers:**

| Platform | Approach |
|----------|----------|
| **Facebook Groups** | "Fire Alarm Engineers UK", "Fire & Security Industry Network", "BAFE Members Group" — post about needing beta testers |
| **Reddit** | r/FireAlarms, r/firePE — introduce yourself and ask for testers |
| **Fire Industry Forums** | firealarmsonline.co.uk, BAFE forums |
| **LinkedIn** | Fire alarm engineer connections, fire safety company pages |
| **Trade Bodies** | BAFE, FIA — member directories, events |
| **Personal Network** | Engineers at other companies you've worked with |

**Recruitment Message Template:**

> I'm building a fire alarm engineer app (jobsheets, asset registers, dispatch, invoicing) and looking for beta testers. It's free during testing — I just need honest feedback. iOS and Android. If you're interested, DM me for the TestFlight link.

**Target:** 10–15 external testers across 3–5 different companies

### 4.3 Tester Onboarding Process

1. **Initial contact** — explain what FireThings does, what you need from them
2. **Share TestFlight link** — iOS first, Android via App Distribution when ready
3. **Create WhatsApp/Signal group** — set expectations for feedback
4. **First-week check-in** — ensure they've logged in and tried core features
5. **Weekly outreach** — don't wait for them to come to you

### 4.4 Enable All Features for Testers

Update Remote Config to enable all features for testers:

| Flag | Set To |
|------|--------|
| `dispatch_enabled` | true |
| `asset_register_enabled` | true |
| `barcode_scanning_enabled` | true |
| `lifecycle_tracking_enabled` | true |
| `compliance_report_enabled` | true |
| `quoting_enabled` | true (when built) |

Use Firebase Console conditions to target testers via the `dispatch_tester` analytics user property.

### 4.5 Daily & Weekly Routines

**Daily:**
- Check Crashlytics for new crashes — fix recurring ones immediately
- Respond to bug reports from tester group

**Weekly:**
- Review Firebase Analytics: which features are used, which are ignored
- Check in with testers directly — ask what's working and what's frustrating
- Push bug fixes via Codemagic → TestFlight

### 4.6 Phase 1A Exit Criteria

Move to Phase 1B when:
- ✅ Defect-to-Quote feature complete and tested
- ✅ At least 5 external testers actively using the app
- ✅ No critical crashes for one week
- ✅ Core dispatch workflow tested by at least one company

---

## 5. Phase 1B: Tester Expansion (Month 2–3)

### 5.1 Expand Tester Base

Target: 15–25 testers across multiple companies

- Continue recruiting from online communities
- Ask existing testers to recommend colleagues
- Consider reaching out to small fire alarm companies directly

### 5.2 Observe Usage Patterns

Analytics data will inform pricing and feature gating:

| Question | How to Answer |
|----------|---------------|
| Which templates are used most? | Analytics: `template_selected` events |
| Is dispatch being used? | Analytics: `dispatch_job_created`, `dispatch_job_completed` |
| Is asset register valuable? | Analytics: `asset_register_viewed`, `asset_tested` |
| Are quotes being created? | Analytics: `quote_created`, `quote_sent`, `quote_converted` |
| What's the killer feature? | Direct feedback + analytics frequency |

### 5.3 Refine Based on Feedback

Categorise all feedback:
- **Critical bugs** — fix immediately
- **UX improvements** — batch and fix weekly
- **Feature requests** — log for Phase 2/3
- **Nice-to-haves** — park for later

### 5.4 Prepare for Phase 2

During Month 2–3:
- Write Terms of Service (see Section 14)
- Research payment integration (see Section 16)
- Start planning marketing website content
- Gather screenshots for marketing materials
- Ask testers what they'd pay for the app

### 5.5 Phase 1B Exit Criteria

Move to Phase 2 when:
- ✅ No major crashes for two consecutive weeks
- ✅ At least 10 testers using it regularly
- ✅ Core workflows work reliably across platforms
- ✅ Cloud sync functions without data loss
- ✅ You have clear feedback on which features matter most
- ✅ Terms of Service written
- ✅ Payment integration researched/selected

---

## 6. Phase 2: Soft Launch with Pricing (Months 3–6)

### 6.1 Marketing Website Setup

Follow the Multi-Site Hosting Plan (see Section 10):

| Site | Domain | Purpose |
|------|--------|---------|
| Marketing | www.firethings.co.uk | Public landing page |
| Dispatch Portal | app.firethings.co.uk | Existing web portal |

**Marketing Site Pages:**
- Home (hero, features overview, CTAs)
- Features (detailed breakdown with screenshots)
- Pricing (clear tier comparison)
- About (your story as a fire alarm engineer)
- Contact (support email, feedback form)
- Privacy Policy (public URL version)
- Terms of Service

### 6.2 Implement Payment System

**Recommended: RevenueCat**

RevenueCat handles subscriptions across iOS, Android, and web. It's the simplest option for a solo developer:

- Single dashboard for all platforms
- Handles App Store and Google Play billing
- Webhook support for backend integration
- Free tier for up to $2,500/month revenue

**Implementation Steps:**
1. Create RevenueCat account
2. Set up products in App Store Connect and Google Play Console
3. Configure products in RevenueCat dashboard
4. Integrate RevenueCat Flutter SDK
5. Add paywall UI to gated features
6. Test subscription flow end-to-end

### 6.3 Feature Gating

Use existing Remote Config flags to gate Pro features:

| Feature | Free Tier | Pro Tier |
|---------|-----------|----------|
| Helpful Tools (all 6) | ✅ | ✅ |
| Jobsheets | 3/month | ✅ Unlimited |
| Invoices | 3/month | ✅ Unlimited |
| Asset Register | 1 site, 10 assets | ✅ Unlimited |
| Dispatch | ❌ | ✅ |
| Quoting | ❌ | ✅ |
| Custom Templates | ❌ | ✅ |
| PDF Certificates | ❌ | ✅ |
| Cloud Sync | ❌ | ✅ |
| PDF Branding | ❌ | ✅ |

### 6.4 Beta Tester Rewards

Reward testers who helped validate the app:
- 50% off first year (£49.50 instead of £99)
- Or 3 months free, then standard pricing
- Grandfather them into any price increases

### 6.5 App Store Preparation

Prepare for public App Store submission:

**App Store Connect:**
- Professional screenshots (5.5" and 6.5" iPhone, iPad)
- App preview video (optional but impactful)
- Compelling description with keywords
- Category: Business or Productivity
- Privacy policy URL (marketing site)

**Google Play Console:**
- Create developer account (£20 one-time)
- Complete app content declarations
- Set up closed testing → open testing → production track
- Similar assets to App Store

### 6.6 Phase 2 Exit Criteria

Move to Phase 3 when:
- ✅ Marketing website live
- ✅ Payment system working on iOS and Android
- ✅ At least 10 paying customers
- ✅ Positive app store reviews
- ✅ Clear pricing validated by market response

---

## 7. Phase 3: Wider Launch (Months 6–12)

### 7.1 Marketing Channels

| Channel | Approach | Effort |
|---------|----------|--------|
| **Fire alarm Facebook groups** | Helpful posts, not salesy; share tips then mention app | Low |
| **Reddit (r/FireAlarms, r/firePE)** | Answer questions, build reputation, occasional mention | Low |
| **YouTube** | Short demo videos showing real workflows | Medium |
| **Trade shows (BAFE, FIA events)** | Small booth or demo table | High |
| **Fire safety publications** | Editorial coverage, sponsored content | Medium |
| **Google/Facebook ads** | Targeted at fire alarm engineers | Variable |

**Content Ideas:**
- "How I fill out BS 5839 jobsheets in 5 minutes"
- "Asset register walkthrough for fire alarm systems"
- "Dispatching jobs to engineers — FireThings demo"
- "Fire alarm inspection checklist app comparison"

### 7.2 Testimonials & Case Studies

Collect from early users:
- Written testimonials for marketing site
- Video testimonials (even short phone recordings)
- Case studies: "How [Company] saved X hours per week"

**Questions to ask:**
- What were you using before FireThings?
- What's your favourite feature?
- How much time does it save you?
- Would you recommend it to other engineers?

### 7.3 Feature Development Priorities

Based on beta feedback, prioritise:

| Feature | Value | Effort |
|---------|-------|--------|
| Photo attachment to jobsheets | High | Low |
| Recurring job scheduling | High | Medium |
| Export to Xero/QuickBooks | Medium | Medium |
| Multi-device sync for solo engineers | Medium | High |
| Additional PDF certificate templates | Low | Low |

### 7.4 Team Pricing Tier

Launch the Team tier for companies with dispatch:

| Tier | Price | Includes |
|------|-------|----------|
| Free | £0 | Tools, limited jobsheets |
| Pro | £9.99/month | Full solo engineer features |
| Team | £19.99/user/month | Everything + dispatch + company features |

**Revenue Example:**
- 1 company with 10 engineers on Team = £199.90/month = £2,399/year
- 5 companies like this = £11,995/year ARR

---

## 8. Phase 4: Scale, Expand, or Sell (12+ Months)

### 8.1 Customer Portal (See Section 11)

Build when demand justifies it:
- Customer login to view service history
- Download compliance reports/certificates
- Request service visits
- View upcoming scheduled maintenance
- Pay invoices online

### 8.2 Scale Options

**Option A: Keep and Grow**
- Expand to adjacent trades (emergency lighting, security, AOV)
- Add advanced features (reporting, analytics, integrations)
- Hire support staff as user base grows

**Option B: Sell**
- Potential acquirers: fire safety software companies, field service platforms
- Sale price: 3–5x ARR
- Build to demonstrate traction, then explore

**Option C: License**
- White-label for other fire safety companies
- License PDF/jobsheet engine to other apps

---

## 9. Defect-to-Quote Feature Plan

### 9.1 Overview

When an engineer finds a defect during an inspection, they should be able to generate a quote for the repair with one tap. This captures repair revenue that would otherwise require a separate process.

**User Flow:**
1. Engineer inspects asset, finds defect
2. Tap "Quote This Defect" from defect bottom sheet
3. Quote pre-fills with customer, site, defect description, suggested line items
4. Engineer edits line items (labour, parts, materials)
5. Quote saved, sent to customer via email
6. Customer approves → converts to dispatched job

**Status Flow:** `Draft → Sent → Approved/Declined → Converted`

### 9.2 Data Model

**New file: `lib/models/quote.dart`**

```dart
enum QuoteStatus { draft, sent, approved, declined, converted }

class QuoteItem {
  final String id;
  final String description;
  final double quantity;
  final double unitPrice;
  final String? category; // labour, parts, materials
  double get total => quantity * unitPrice;
}

class Quote {
  final String id;
  final String quoteNumber;         // Q-0001 format
  final String engineerId;
  final String engineerName;
  final String? companyId;
  
  // Customer
  final String customerName;
  final String customerAddress;
  final String? customerEmail;
  
  // Site
  final String siteId;
  final String siteName;
  
  // Source defect
  final String? defectId;
  final String? defectDescription;
  final String? defectSeverity;
  
  // Quote content
  final List<QuoteItem> items;
  final String? notes;
  final bool includeVat;
  
  // Status & dates
  final QuoteStatus status;
  final DateTime validUntil;
  final DateTime createdAt;
  
  // Conversion
  final String? convertedJobId;
  
  // Computed
  double get subtotal => items.fold(0, (sum, item) => sum + item.total);
  double get vatAmount => includeVat ? subtotal * 0.2 : 0;
  double get total => subtotal + vatAmount;
}
```

### 9.3 Database Updates

**SQLite (solo engineers):** Add quotes table (DB version 17)

**Firestore (company users):** Path `companies/{companyId}/quotes/{quoteId}`

### 9.4 New Files Required

| File | Purpose |
|------|---------|
| `lib/models/quote.dart` | Quote, QuoteItem, QuoteStatus models |
| `lib/services/quote_service.dart` | CRUD + workflow logic |
| `lib/services/quote_pdf_service.dart` | PDF generation |
| `lib/screens/quoting/quote_screen.dart` | Create/edit quote |
| `lib/screens/quoting/quote_list_screen.dart` | List quotes by status |
| `lib/screens/quoting/quoting_hub_screen.dart` | Quoting dashboard |

### 9.5 Integration Points

- Add "Quote This Defect" button to defect bottom sheet
- Add "Create Quote" button in asset detail defect card
- Add "Quotes" tile to home screen helpful tools
- Add quote-to-job conversion for approved quotes
- Add 4 analytics events: `quote_created`, `quote_sent`, `quote_status_changed`, `quote_converted`

### 9.6 Remote Config Flag

Add: `quoting_enabled` (default: false)

Gate the feature until ready for release.

### 9.7 Privacy Policy Impact

**Update Required:** Yes — the privacy policy needs to include:
- Quote data collection (customer details, pricing, defect information)
- Quote storage in cloud sync
- Email sending for quote delivery

See Section 13 for full privacy policy updates.

---

## 10. Multi-Site Hosting & Marketing Website

### 10.1 Architecture

```
Firebase Project: firethings-51e00
│
├── Site: firethings-marketing (NEW)
│   ├── Domain: www.firethings.co.uk
│   └── Purpose: Public marketing site
│
└── Site: firethings-app (EXISTING)
    ├── Domain: app.firethings.co.uk (or firethings.co.uk)
    └── Purpose: Dispatch portal
```

### 10.2 Setup Steps

**Step 1: Create Marketing Site in Firebase**
```bash
firebase hosting:sites:create firethings-marketing
```

**Step 2: Update `.firebaserc`**
```json
{
  "projects": { "default": "firethings-51e00" },
  "targets": {
    "firethings-51e00": {
      "hosting": {
        "app": ["firethings-51e00"],
        "marketing": ["firethings-marketing"]
      }
    }
  }
}
```

**Step 3: Update `firebase.json`**
```json
{
  "hosting": [
    {
      "target": "app",
      "public": "build/web",
      "rewrites": [{ "source": "**", "destination": "/index.html" }]
    },
    {
      "target": "marketing",
      "public": "marketing-site/public"
    }
  ]
}
```

**Step 4: DNS Configuration (Squarespace)**

| Type | Name | Value |
|------|------|-------|
| CNAME | www | firethings-marketing.web.app |
| CNAME | app | firethings-51e00.web.app |

**Step 5: Connect Domains in Firebase Console**

### 10.3 Marketing Site Content

**Pages to Create:**

| Page | Content |
|------|---------|
| **Home** | Hero, key features, CTAs, screenshots |
| **Features** | Detailed breakdown of all features |
| **Pricing** | Tier comparison, FAQs |
| **About** | Your story as a fire alarm engineer |
| **Contact** | Support email, feedback form |
| **Privacy Policy** | Full policy text |
| **Terms of Service** | Full terms text |

### 10.4 Recommended Tech Stack

For simplicity, use **plain HTML/CSS/JS**:
- No build step required
- Easy to update
- Deploys instantly to Firebase Hosting
- Can always migrate to Next.js later if needed

---

## 11. Customer Portal (Future)

### 11.1 Overview

A web portal where customers can log in to view their service history, download reports, and request service.

**Status:** Future feature — build based on demand from paying customers.

### 11.2 Potential Features

| Feature | Priority |
|---------|----------|
| View service history for their sites | High |
| Download compliance reports/certificates | High |
| Request service visits | Medium |
| View upcoming scheduled maintenance | Medium |
| Pay invoices online | Medium |
| Access documentation | Low |

### 11.3 Technical Approach

- Separate Firebase Hosting site: customers.firethings.co.uk
- Customer authentication (Firebase Auth)
- Read-only access to relevant company data
- Firestore security rules for customer data isolation

### 11.4 Privacy Policy Impact

**Update Required:** Yes — would need:
- Customer account creation and login
- Customer data access and retention
- Payment processing (if invoices payable online)

### 11.5 When to Build

Build when:
- Multiple paying customers request it
- It would reduce support burden (sending reports manually)
- It creates competitive advantage vs Uptick

---

## 12. Legal & Compliance Requirements

### 12.1 Current Status

| Requirement | Status | Notes |
|-------------|--------|-------|
| ICO Registration | ✅ Done | Number in privacy policy |
| In-App Privacy Policy | ✅ Done | 8 sections |
| Public Privacy Policy URL | ✅ Done | GitHub |
| Account Deletion (GDPR) | ✅ Done | Full data wipe |
| HMRC Self-Employed | ✅ Done | Construction work |
| Terms of Service | ⬜ Not done | Needed before charging |
| PI Insurance | ⬜ Not done | Consider before public launch |

### 12.2 What's Needed Before Charging

1. **Terms of Service** — liability limits, subscription terms (see Section 14)
2. **Update Privacy Policy** — add quoting feature data (see Section 13)
3. **Payment processor agreement** — when setting up RevenueCat/Stripe

### 12.3 Professional Indemnity Insurance

**Why Consider It:**
- App includes BS 5839 calculations engineers may rely on
- Detector spacing, battery load calculations inform real decisions
- PI insurance protects if a calculation were wrong and caused harm

**Cost:** Typically £200–£500/year for software/consulting businesses

**When:** Before public launch or when revenue justifies the cost

---

## 13. Privacy Policy Updates Required

### 13.1 New Data Types to Add

The Defect-to-Quote feature collects additional data that must be disclosed:

**Add to "Data Collected" section:**
- Quote information (quote number, line items, pricing, VAT)
- Quote status and dates (created, sent, approved, declined, converted)
- Customer email addresses for quote delivery
- Linked defect information in quotes

**Add to "Third-Party Services" section:**
- Email service provider (if using a third-party service for quote emails)

### 13.2 Updated Privacy Policy Text

Add to Section 1 (Data Collected):

> **Quotes:** If you create quotes from defects, we collect quote details including line items, pricing, customer information, and status. This data is stored to enable the quote workflow and may be synced to our cloud backup service.

Add to Section 6 (Data Sharing):

> **Quote Delivery:** When you send a quote to a customer, we use your device's email application to send the quote PDF. We do not store customer email addresses beyond what you enter in the quote.

### 13.3 When to Update

Update the privacy policy **before** enabling the quoting feature for testers. This ensures compliance from day one.

---

## 14. Terms of Service

### 14.1 Key Sections Required

| Section | Purpose |
|---------|---------|
| **Service Description** | What FireThings does and doesn't do |
| **Account Terms** | Registration, responsibilities, security |
| **Acceptable Use** | What users can and cannot do |
| **Subscription & Payment** | Pricing, billing, cancellation, refunds |
| **Intellectual Property** | You own app, users own their data |
| **Data & Privacy** | Reference to privacy policy |
| **BS 5839 Disclaimer** | Calculations are guidance only |
| **Limitation of Liability** | No liability for business decisions |
| **Indemnification** | Users responsible for their use |
| **Termination** | When accounts can be terminated |
| **Changes to Terms** | How you'll notify of changes |
| **Governing Law** | UK law, UK courts |
| **Contact Information** | How to reach you |

### 14.2 BS 5839 Disclaimer (Critical)

This is the most important section given your tools reference British Standards:

> **BS 5839 Reference Data Disclaimer**
>
> FireThings includes tools that reference BS 5839-1 and other fire safety standards. These tools are provided as a convenience to assist qualified fire alarm engineers and are not a substitute for reading, understanding, and applying the full standards.
>
> The calculations provided (detector spacing, battery load testing, etc.) are based on our interpretation of the standards as of the date shown in the app. Standards may be updated, and our interpretation may contain errors.
>
> YOU ARE SOLELY RESPONSIBLE for verifying that any calculations or recommendations are appropriate for your specific installation. FireThings accepts no liability for decisions made based on information in this app.
>
> If you are not a qualified fire alarm engineer, you should not use this app to make decisions about fire safety systems.

### 14.3 Subscription Terms

> **Subscriptions**
>
> FireThings offers monthly and annual subscription plans. Subscriptions automatically renew unless cancelled at least 24 hours before the end of the current period.
>
> **Cancellation:** You may cancel your subscription at any time through your App Store or Google Play account settings. Cancellation takes effect at the end of the current billing period. You will retain access to Pro features until then.
>
> **Refunds:** Refunds are handled by Apple (App Store) or Google (Play Store) according to their respective policies. We do not process refunds directly.
>
> **Price Changes:** We may change subscription prices with 30 days' notice. Price changes do not affect your current billing period.

### 14.4 Data Ownership

> **Your Data**
>
> You retain all rights to the data you enter into FireThings, including jobsheets, invoices, quotes, asset records, and customer information. We do not claim any ownership of your data.
>
> You may export or delete your data at any time. If you delete your account, all data is permanently removed as described in our Privacy Policy.

---

## 15. Business Structure Guidance

### 15.1 Current Situation

You're already registered as self-employed with HMRC for construction work. You can sell software subscriptions under this same registration initially.

### 15.2 Sole Trader vs Limited Company

| Factor | Sole Trader | Limited Company |
|--------|-------------|-----------------|
| **Setup** | Already done | £12–£50 to register |
| **Admin** | Simple — self-assessment | More complex — accounts, filings |
| **Liability** | Personal liability | Limited to company assets |
| **Tax** | Income tax (20%/40%) | Corporation tax (19-25%), then dividends |
| **Credibility** | Fine for small scale | Better for B2B sales |
| **Separation** | Personal finances mixed | Company finances separate |

### 15.3 Recommendation

**Start as Sole Trader:**
- No immediate action needed — you're already registered
- Keep things simple while validating the business
- Track FireThings income/expenses separately from construction work

**Consider Ltd When:**
- Revenue exceeds £30,000/year (tax efficiency kicks in)
- You want liability protection (PI insurance also helps)
- B2B sales to larger companies require it for procurement
- You want to bring on a co-founder or investor

### 15.4 Action Items

| When | Action |
|------|--------|
| Now | Nothing — continue as sole trader |
| Phase 2 | Open separate bank account for FireThings income |
| £30k+ revenue | Consult an accountant about Ltd incorporation |

---

## 16. Payment Integration Strategy

### 16.1 Recommendation: RevenueCat

**Why RevenueCat:**
- Cross-platform (iOS, Android, web)
- Handles subscription complexity for you
- Free up to $2,500/month revenue
- Single dashboard for all platforms
- Good Flutter SDK

**Alternatives:**

| Option | Pros | Cons |
|--------|------|------|
| **Native (StoreKit + Play Billing)** | No third-party dependency | Complex, platform-specific code |
| **Stripe** | Web subscriptions, avoid app store fees | Users must subscribe via web |
| **Purchases.js + RevenueCat** | Hybrid approach | More complexity |

### 16.2 Implementation Steps

**Week 1: Setup**
1. Create RevenueCat account
2. Create App Store Connect in-app purchases
3. Create Google Play in-app products
4. Link to RevenueCat

**Week 2: Integration**
1. Add `purchases_flutter` to pubspec.yaml
2. Initialize RevenueCat on app start
3. Implement subscription check service
4. Create paywall UI

**Week 3: Testing**
1. Test subscription flow on iOS sandbox
2. Test on Android with test accounts
3. Test restore purchases
4. Test cancellation and expiry

### 16.3 App Store Fees

| Store | Commission |
|-------|------------|
| Apple App Store | 15% (small business) or 30% |
| Google Play | 15% first $1M, then 30% |

**Tip:** Apple's Small Business Program (15% commission) applies automatically if you earn under $1M/year. Apply through App Store Connect.

---

## 17. Pricing Strategy

### 17.1 Competitive Context

| Competitor | Pricing | Notes |
|------------|---------|-------|
| Uptick | ~$50–100/user/month | Enterprise-focused |
| Simpro | Similar to Uptick | Full job management |
| Generic PDF apps | £5–10/month | No fire-specific features |

FireThings is more affordable than Uptick while more specialised than generic tools.

### 17.2 Recommended Tiers

| Tier | Monthly | Annual | Features |
|------|---------|--------|----------|
| **Free** | £0 | £0 | All 6 tools, 3 jobsheets/month, 1 site/10 assets |
| **Pro** | £9.99 | £99 | Unlimited jobsheets, invoices, assets, quotes, sync |
| **Team** | £19.99/user | £199/user | Everything + dispatch + company features |

**Annual Discount:** ~17% (2 months free)

### 17.3 Beta Tester Pricing

| Offer | Value |
|-------|-------|
| 50% off first year | £49.50 instead of £99 |
| 3 months free then standard | Good for long-term retention |
| Lifetime Pro for early testers | Consider for first 10 who gave substantial feedback |

### 17.4 Pricing Validation

Before finalising:
- Ask testers: "What would you pay for this?"
- Ask: "What does Uptick cost your company per user?"
- Start lower and increase rather than overpricing initially

---

## 18. Marketing Copy & Screenshots

### 18.1 App Store Description

**Title:** FireThings — Fire Alarm Jobs

**Subtitle:** Jobsheets, Dispatch, Asset Register

**Description:**

> FireThings is the complete app for fire alarm engineers. Create professional jobsheets, manage asset registers, dispatch jobs to your team, and invoice customers — all in one offline-first app built specifically for the fire protection industry.
>
> **PROFESSIONAL JOBSHEETS**
> Choose from 6 pre-built templates covering battery replacement, detector replacement, annual inspections, quarterly tests, panel commissioning, and fault finding. Or create your own custom templates. Generate branded PDFs with your company logo and colours.
>
> **ASSET REGISTER & FLOOR PLANS**
> Track every device on every site. Upload floor plans, place asset pins, and run inspections with built-in checklists based on BS 5839-1. Generate compliance reports showing pass/fail status across all assets.
>
> **JOB DISPATCH**
> Office staff can create and assign jobs to engineers. Engineers receive push notifications, get directions, and can update job status in real-time. When the job is done, the jobsheet links directly back to the dispatched job.
>
> **QUOTING & INVOICING**
> Find a defect? Create a quote with one tap. Customer approves? Convert to a dispatched job. Send professional invoices with your bank details and payment terms.
>
> **HELPFUL TOOLS**
> • BS 5839-1 Reference Guide — searchable guidance on detectors, sounders, cables, and more
> • Detector Spacing Calculator — calculate how many detectors for any room
> • Battery Load Tester — verify battery capacity per BS 5839-1 Annex D
> • Decibel Meter — measure sounder output levels
> • Timestamp Camera — watermark photos with date, time, location, and engineer name
> • DIP Switch Calculator — addressable device addressing made easy
>
> **OFFLINE-FIRST**
> Works without internet. Your data syncs automatically when you're back online.
>
> **BUILT BY A FIRE ALARM ENGINEER**
> FireThings was built by a working fire alarm engineer who got frustrated with generic apps that don't understand the job. Every feature is designed for the way fire engineers actually work.
>
> Download free. Upgrade to Pro for unlimited jobsheets, invoicing, quoting, and cloud sync.

**Keywords:** fire alarm, jobsheet, asset register, dispatch, fire engineer, BS 5839, inspection, compliance, PDF, invoice

### 18.2 Screenshot Concepts

| Screen | What to Show |
|--------|--------------|
| 1 | Home screen with tools grid |
| 2 | Jobsheet creation with template selection |
| 3 | Asset register with floor plan and pins |
| 4 | Dispatch dashboard showing job cards |
| 5 | BS 5839 reference guide |
| 6 | Professional PDF output example |

**Tips:**
- Use real-looking sample data (not "Test Customer")
- Show the app in action, not just screens
- Consider adding device frames
- Use consistent, professional mockup style

### 18.3 Marketing Website Copy

**Hero Section:**
> **Fire Alarm Management Made Simple**
>
> Professional jobsheets, asset registers, and job dispatch for fire alarm engineers. Built by an engineer who gets it.
>
> [Download on App Store] [Get on Google Play] [Dispatch Portal]

**Feature Sections:**
- "One App, Everything You Need"
- "Asset Registers That Actually Work"
- "Dispatch Jobs, Not Emails"
- "Built for BS 5839 Compliance"

---

## 19. Master Checklist by Phase

### Phase 1A: Now – Month 2

| Status | Task | Priority |
|--------|------|----------|
| ⬜ | Build Defect-to-Quote data model | High |
| ⬜ | Build Quote service and screens | High |
| ⬜ | Integrate quotes with defects | High |
| ⬜ | Add quote PDF generation | High |
| ⬜ | Add quote-to-job conversion | High |
| ⬜ | Update privacy policy for quotes | High |
| ⬜ | Post in fire alarm Facebook groups | High |
| ⬜ | Post in Reddit fire communities | High |
| ⬜ | Reach out to engineers at other companies | High |
| ⬜ | Create tester WhatsApp group | Medium |
| ⬜ | Enable all features for testers (Remote Config) | Medium |
| ⬜ | Set up Firebase App Distribution (Android) | Medium |
| ⬜ | Back up Android keystore | Medium |

### Phase 1B: Month 2–3

| Status | Task | Priority |
|--------|------|----------|
| ⬜ | Expand to 15+ testers | High |
| ⬜ | Write Terms of Service | High |
| ⬜ | Research RevenueCat integration | High |
| ⬜ | Gather pricing feedback from testers | Medium |
| ⬜ | Fix bugs reported by testers | Ongoing |
| ⬜ | Plan marketing website content | Medium |

### Phase 2: Months 3–6

| Status | Task | Priority |
|--------|------|----------|
| ⬜ | Create Firebase multi-site hosting | High |
| ⬜ | Build marketing website | High |
| ⬜ | Configure DNS (Squarespace) | High |
| ⬜ | Implement RevenueCat | High |
| ⬜ | Create App Store products | High |
| ⬜ | Create Google Play products | High |
| ⬜ | Add paywall UI | High |
| ⬜ | Publish Terms of Service | High |
| ⬜ | Beta tester loyalty offers | Medium |
| ⬜ | Create App Store screenshots | Medium |
| ⬜ | Submit to App Store | Medium |
| ⬜ | Submit to Google Play | Medium |
| ⬜ | Consider PI insurance | Low |

### Phase 3: Months 6–12

| Status | Task | Priority |
|--------|------|----------|
| ⬜ | Collect testimonials | High |
| ⬜ | Create demo videos | Medium |
| ⬜ | Join fire safety communities | Medium |
| ⬜ | Explore BAFE/FIA events | Low |
| ⬜ | Contact trade publications | Low |
| ⬜ | Launch Team pricing tier | When ready |
| ⬜ | Explore accounting integrations | When requested |

### Phase 4: 12+ Months

| Status | Task | Priority |
|--------|------|----------|
| ⬜ | Evaluate Customer Portal demand | Based on feedback |
| ⬜ | Consider Ltd incorporation | When revenue justifies |
| ⬜ | Review pricing and adjust | Based on data |

---

## 20. Ordered Action List

### This Week

| # | Action | Time |
|---|--------|------|
| 1 | Update privacy policy to include quoting data | 30 min |
| 2 | Start Defect-to-Quote data model implementation | 2–3 hours |
| 3 | Post in 2–3 fire alarm Facebook groups asking for testers | 30 min |
| 4 | Post in r/FireAlarms introducing yourself and asking for testers | 15 min |
| 5 | Create tester WhatsApp group | 5 min |
| 6 | Back up Android keystore to 2 secure locations | 10 min |

### Next 2 Weeks

| # | Action | Time |
|---|--------|------|
| 7 | Complete Quote model and database schema | 4–6 hours |
| 8 | Build QuoteService with CRUD operations | 4–6 hours |
| 9 | Build quote_screen.dart (create/edit) | 4–6 hours |
| 10 | Build quote_list_screen.dart | 2–3 hours |
| 11 | Build quoting_hub_screen.dart | 2–3 hours |
| 12 | Set up Firebase App Distribution for Android testers | 30 min |
| 13 | Follow up with anyone who responded to tester posts | Ongoing |

### Month 1–2

| # | Action |
|---|--------|
| 14 | Complete Defect-to-Quote integration |
| 15 | Add quote PDF generation |
| 16 | Add quote-to-job conversion |
| 17 | Test quoting workflow end-to-end |
| 18 | Enable quoting for testers via Remote Config |
| 19 | Collect feedback on quoting feature |
| 20 | Start writing Terms of Service |

### Month 2–3

| # | Action |
|---|--------|
| 21 | Complete Terms of Service |
| 22 | Research and select payment integration (RevenueCat) |
| 23 | Ask testers what they'd pay |
| 24 | Begin marketing website content planning |
| 25 | Fix any bugs from tester feedback |

### Month 3–4

| # | Action |
|---|--------|
| 26 | Set up Firebase multi-site hosting |
| 27 | Build marketing website |
| 28 | Configure Squarespace DNS |
| 29 | Implement RevenueCat |
| 30 | Create App Store/Play Store products |
| 31 | Add paywall UI to app |
| 32 | Test subscription flow |

### Month 4–6

| # | Action |
|---|--------|
| 33 | Create professional screenshots |
| 34 | Submit to App Store for public release |
| 35 | Submit to Google Play for public release |
| 36 | Launch beta tester loyalty offers |
| 37 | Announce pricing on marketing website |
| 38 | Begin accepting paying customers |

---

## Summary

**The app is more complete than the original plan anticipated.** Dispatch, asset register, and web portal are all built. The main work now is:

1. **Build Defect-to-Quote** — captures repair revenue, matches Uptick functionality
2. **Find external testers** — your company is on Uptick, so look elsewhere
3. **Ship a complete product** — don't launch with missing features
4. **Set up marketing and payments** — website, RevenueCat, app stores
5. **Charge money** — validate that people will pay

The goal is a complete, professional app that fire alarm companies choose over Uptick because it's built by someone who understands the job, costs less, and does everything they need.

---

*Time to ship it.*
