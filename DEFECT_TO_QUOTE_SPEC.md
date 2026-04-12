# Defect-to-Quote Workflow — Implementation Spec

## Context

Feature identified from gap analysis vs Uptick/Simpro competitors. This is a core revenue feature for fire contractors — capturing repair revenue when defects are found during inspections. Engineer finds defect → one tap → quote generated → customer approves → job dispatched.

---

## User Flow

1. Engineer inspects asset, finds defect
2. Tap "Quote This Defect" from defect bottom sheet
3. Quote pre-fills with customer, site, defect description, suggested line items
4. Engineer edits line items (labour, parts, materials)
5. Quote saved, sent to customer via email
6. Customer approves → converts to dispatched job

**Status flow:** `Draft → Sent → Approved/Declined → Converted`

---

## Phase 1: Data Model

### New file: `lib/models/quote.dart`

**QuoteStatus enum:**
```dart
enum QuoteStatus { draft, sent, approved, declined, converted }
```

**QuoteItem model:**
```dart
class QuoteItem {
  final String id;
  final String description;
  final double quantity;
  final double unitPrice;
  final String? category; // labour, parts, materials
  
  double get total => quantity * unitPrice;
  
  // toJson, fromJson, copyWith
}
```

**Quote model fields:**
```dart
class Quote {
  final String id;
  final String quoteNumber;         // Q-0001 format
  final String engineerId;
  final String engineerName;
  final String? companyId;          // null for solo engineers
  
  // Customer
  final String customerName;
  final String customerAddress;
  final String? customerEmail;
  final String? customerPhone;
  
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
  final DateTime? lastModifiedAt;
  final DateTime? sentAt;
  final DateTime? respondedAt;
  
  // Conversion
  final String? convertedJobId;     // link to created DispatchedJob
  final bool useCompanyBranding;
  
  // Computed
  double get subtotal => items.fold(0, (sum, item) => sum + item.total);
  double get vatAmount => includeVat ? subtotal * 0.2 : 0;
  double get total => subtotal + vatAmount;
  
  // toJson, fromJson, copyWith
}
```

### Database updates

**SQLite (solo engineers):** Add quotes table to `database_helper.dart`

```sql
CREATE TABLE quotes (
  id TEXT PRIMARY KEY,
  quote_number TEXT,
  engineer_id TEXT,
  engineer_name TEXT,
  customer_name TEXT,
  customer_address TEXT,
  customer_email TEXT,
  customer_phone TEXT,
  site_id TEXT,
  site_name TEXT,
  defect_id TEXT,
  defect_description TEXT,
  defect_severity TEXT,
  items TEXT,  -- JSON array
  notes TEXT,
  include_vat INTEGER,
  status TEXT,
  valid_until TEXT,
  created_at TEXT,
  last_modified_at TEXT,
  sent_at TEXT,
  responded_at TEXT,
  converted_job_id TEXT,
  use_company_branding INTEGER
)
```

- Add migration in `_onUpgrade` (increment DB version to 17)
- CRUD methods: insertQuote, updateQuote, deleteQuote, getQuotes, getQuoteById, getQuotesByStatus

**Firestore (company users):** Path `companies/{companyId}/quotes/{quoteId}`

### Update: `lib/models/defect.dart`

Add field to track linked quote:
```dart
final String? linkedQuoteId;
```

Update toJson, fromJson, copyWith.

---

## Phase 2: Quote Service

### New file: `lib/services/quote_service.dart`

Singleton pattern (like DispatchService):

```dart
class QuoteService {
  static final QuoteService instance = QuoteService._();
  QuoteService._();
  
  final _db = DatabaseHelper.instance;
  final _firestore = FirebaseFirestore.instance;
  
  String get _basePath {
    final profile = UserProfileService.instance.currentProfile;
    if (profile?.companyId != null) {
      return 'companies/${profile!.companyId}/quotes';
    }
    return 'users/${AuthService.instance.currentUser!.uid}/quotes';
  }
  
  bool get _isCompanyUser => UserProfileService.instance.currentProfile?.companyId != null;
```

**Core methods:**
```dart
Future<Quote> createQuote(Quote quote);
Future<void> updateQuote(Quote quote);
Future<void> deleteQuote(String quoteId);
Stream<List<Quote>> getQuotesStream();
Future<List<Quote>> getQuotesByStatus(QuoteStatus status);
Future<void> updateQuoteStatus(String quoteId, QuoteStatus newStatus, {String? convertedJobId});
```

**Workflow methods:**
```dart
Future<DispatchedJob> convertToJob(Quote quote);
Future<void> linkQuoteToDefect(String defectId, String quoteId);
Future<String> getNextQuoteNumber();  // Q-0001, Q-0002, etc.
```

**Storage routing:**
- `_isCompanyUser` → Firestore
- Solo → SQLite

---

## Phase 3: PDF Generation

### New file: `lib/services/quote_pdf_service.dart`

Mirror `invoice_pdf_service.dart` structure:

```dart
class QuotePdfService {
  static Future<Uint8List> generateQuotePdf(
    Quote quote,
    PaymentDetails? paymentDetails,
  ) async {
    // ...
  }
}
```

**PDF sections:**
1. Header with "QUOTE" badge (coral accent colour)
2. Quote number, date, valid until date
3. Customer section (QUOTATION FOR)
4. **Defect summary section** (NEW)
   - Defect description
   - Severity badge
   - Asset info if available
5. Items table (same as invoice)
   - Description, Qty, Unit Price, Total
   - Category column (Labour/Parts/Materials)
6. Totals (subtotal, VAT if applicable, total)
7. Terms section
   - "This quote is valid until [date]"
   - "To accept, please reply to this email or call [phone]"
8. Footer with branding

---

## Phase 4: UI Screens

### New file: `lib/screens/quoting/quote_screen.dart`

Create/edit quote form (mirror invoice_screen.dart):

**Pre-fill from defect:**
```dart
Quote.fromDefect(Defect defect, Site site, Customer? customer) {
  return Quote(
    id: Uuid().v4(),
    quoteNumber: await QuoteService.instance.getNextQuoteNumber(),
    customerName: customer?.name ?? site.customerName ?? '',
    customerAddress: customer?.address ?? site.address ?? '',
    customerEmail: customer?.email ?? '',
    siteId: site.id,
    siteName: site.name,
    defectId: defect.id,
    defectDescription: defect.note,
    defectSeverity: defect.severity.name,
    items: _suggestedItems(defect),  // Based on severity/type
    status: QuoteStatus.draft,
    validUntil: DateTime.now().add(Duration(days: 30)),
    // ...
  );
}
```

**Form sections:**
1. Header (quote number auto-generated, dates)
2. Customer section (with autocomplete from saved customers)
3. Defect summary card (read-only, shows source defect info)
4. Line items section
   - Add/remove items
   - Category dropdown per item
   - Quantity, unit price fields
   - Running total
5. VAT toggle
6. Notes section
7. Valid until date picker

**Action buttons (contextual by status):**
- **Draft:** Save Draft, Preview PDF, Send Quote
- **Sent:** Preview PDF, Mark Approved, Mark Declined
- **Approved:** Convert to Job
- **Declined:** Edit & Resend
- **Converted:** View Linked Job

### New file: `lib/screens/quoting/quote_list_screen.dart`

```dart
// Filter tabs
enum QuoteFilter { all, drafts, sent, approved, declined, converted }

// List item card shows:
// - Quote number
// - Customer name
// - Site name
// - Total value
// - Status badge (colour-coded)
// - Valid until (with overdue warning)
// - Created date
```

Swipe actions:
- Swipe right: Quick status update (contextual)
- Swipe left: Delete (drafts only)

### New file: `lib/screens/quoting/quoting_hub_screen.dart`

Dashboard layout:
```
┌─────────────────────────────────────┐
│  Quotes                             │
├─────────────────────────────────────┤
│  ┌─────────┐ ┌─────────┐           │
│  │ Drafts  │ │  Sent   │           │
│  │    3    │ │    5    │           │
│  └─────────┘ └─────────┘           │
│  ┌─────────┐ ┌─────────┐           │
│  │Approved │ │ Total   │           │
│  │    2    │ │ £4,250  │           │
│  └─────────┘ └─────────┘           │
├─────────────────────────────────────┤
│  Quick Actions                      │
│  ┌─────────────────────────────┐   │
│  │  + Create New Quote         │   │
│  └─────────────────────────────┘   │
│  ┌─────────────────────────────┐   │
│  │  📋 View All Quotes         │   │
│  └─────────────────────────────┘   │
└─────────────────────────────────────┘
```

---

## Phase 5: Integration Points

### Update: `lib/widgets/defect_bottom_sheet.dart`

After defect is saved, show option:

```dart
// In _buildActions() or similar
if (defect.linkedQuoteId == null) {
  ListTile(
    leading: Icon(AppIcons.receipt),
    title: Text('Quote This Defect'),
    subtitle: Text('Create a repair quote for the customer'),
    onTap: () {
      Navigator.pop(context);
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => QuoteScreen(
            fromDefect: defect,
            site: site,
            customer: customer,
          ),
        ),
      );
    },
  ),
} else {
  ListTile(
    leading: Icon(AppIcons.receipt),
    title: Text('View Linked Quote'),
    subtitle: Text('Quote ${defect.linkedQuoteId}'),
    onTap: () => _navigateToQuote(defect.linkedQuoteId!),
  ),
}
```

### Update: `lib/screens/assets/asset_detail_screen.dart`

In `_ActiveDefectCard` widget:

```dart
// Add button row
Row(
  children: [
    if (defect.linkedQuoteId == null)
      OutlinedButton.icon(
        icon: Icon(AppIcons.receipt),
        label: Text('Create Quote'),
        onPressed: () => _createQuoteFromDefect(defect),
      )
    else
      OutlinedButton.icon(
        icon: Icon(AppIcons.receipt),
        label: Text('View Quote'),
        onPressed: () => _viewQuote(defect.linkedQuoteId!),
      ),
  ],
)
```

### Update: `lib/screens/home/home_screen.dart`

Add Quoting tile to tools grid (or separate card):

```dart
_buildToolTile(
  icon: AppIcons.receipt,
  label: 'Quotes',
  badge: pendingQuoteCount > 0 ? '$pendingQuoteCount' : null,
  onTap: () => Navigator.push(
    context,
    MaterialPageRoute(builder: (_) => QuotingHubScreen()),
  ),
)
```

---

## Phase 6: Quote-to-Job Conversion

In `quote_service.dart`:

```dart
Future<DispatchedJob> convertQuoteToJob(Quote quote) async {
  // Validate
  if (quote.status != QuoteStatus.approved) {
    throw StateError('Only approved quotes can be converted');
  }
  if (quote.companyId == null) {
    throw StateError('Quote-to-job conversion requires company membership');
  }
  
  // Create job
  final job = DispatchedJob(
    id: Uuid().v4(),
    companyId: quote.companyId!,
    title: 'Defect Repair: ${quote.siteName}',
    description: '${quote.defectDescription}\n\nQuote: ${quote.quoteNumber}\nValue: £${quote.total.toStringAsFixed(2)}',
    siteName: quote.siteName,
    siteAddress: quote.customerAddress,
    contactName: quote.customerName,
    contactEmail: quote.customerEmail,
    contactPhone: quote.customerPhone,
    status: DispatchedJobStatus.created,
    priority: JobPriority.normal,
    createdAt: DateTime.now(),
    updatedAt: DateTime.now(),
    createdBy: AuthService.instance.currentUser!.uid,
  );
  
  // Save job
  await DispatchService.instance.createJob(job);
  
  // Update quote
  await updateQuoteStatus(
    quote.id, 
    QuoteStatus.converted,
    convertedJobId: job.id,
  );
  
  // Analytics
  AnalyticsService.instance.logQuoteConverted(
    quoteId: quote.id,
    jobId: job.id,
    value: quote.total,
  );
  
  return job;
}
```

**UI:** In quote detail screen when status == approved:

```dart
ElevatedButton.icon(
  icon: Icon(AppIcons.dispatch),
  label: Text('Convert to Job'),
  style: ElevatedButton.styleFrom(
    backgroundColor: AppTheme.success,
  ),
  onPressed: () async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text('Convert to Job?'),
        content: Text('This will create a new dispatched job from this quote.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: Text('Cancel')),
          ElevatedButton(onPressed: () => Navigator.pop(context, true), child: Text('Convert')),
        ],
      ),
    );
    if (confirmed == true) {
      final job = await QuoteService.instance.convertQuoteToJob(quote);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Job created: ${job.title}')),
      );
      // Navigate to job or refresh
    }
  },
)
```

---

## Phase 7: Email & Analytics

### Update: `lib/services/email_service.dart`

```dart
static Future<void> sendQuote({
  required String recipientEmail,
  required String recipientName,
  required String quoteNumber,
  required double total,
  required DateTime validUntil,
  required Uint8List pdfBytes,
  required String senderName,
  String? senderPhone,
}) async {
  final subject = 'Quote $quoteNumber from $senderName';
  final body = '''
Dear $recipientName,

Please find attached our quotation $quoteNumber for the value of £${total.toStringAsFixed(2)}.

This quote is valid until ${DateFormat('d MMMM yyyy').format(validUntil)}.

To accept this quote, please reply to this email or call us${senderPhone != null ? ' on $senderPhone' : ''}.

Kind regards,
$senderName
''';

  // Use existing email sending logic with PDF attachment
  await _sendEmailWithAttachment(
    to: recipientEmail,
    subject: subject,
    body: body,
    attachmentBytes: pdfBytes,
    attachmentName: 'Quote_$quoteNumber.pdf',
  );
}
```

### Update: `lib/services/analytics_service.dart`

```dart
void logQuoteCreated({required bool fromDefect, required double value}) {
  _analytics.logEvent(name: 'quote_created', parameters: {
    'from_defect': fromDefect,
    'value': value,
  });
}

void logQuoteSent({required String quoteId, required double value}) {
  _analytics.logEvent(name: 'quote_sent', parameters: {
    'quote_id': quoteId,
    'value': value,
  });
}

void logQuoteStatusChanged({required String from, required String to}) {
  _analytics.logEvent(name: 'quote_status_changed', parameters: {
    'from_status': from,
    'to_status': to,
  });
}

void logQuoteConverted({required String quoteId, required String jobId, required double value}) {
  _analytics.logEvent(name: 'quote_converted', parameters: {
    'quote_id': quoteId,
    'job_id': jobId,
    'value': value,
  });
}
```

---

## Files Summary

### New files (6):

| File | Purpose |
|------|---------|
| `lib/models/quote.dart` | Quote, QuoteItem, QuoteStatus models |
| `lib/services/quote_service.dart` | CRUD + workflow logic |
| `lib/services/quote_pdf_service.dart` | PDF generation |
| `lib/screens/quoting/quote_screen.dart` | Create/edit quote |
| `lib/screens/quoting/quote_list_screen.dart` | List quotes by status |
| `lib/screens/quoting/quoting_hub_screen.dart` | Quoting dashboard |

### Modified files (8):

| File | Changes |
|------|---------|
| `lib/models/models.dart` | Add `export 'quote.dart';` |
| `lib/models/defect.dart` | Add `linkedQuoteId` field |
| `lib/services/database_helper.dart` | Quotes table, migrations, CRUD (DB v17) |
| `lib/services/defect_service.dart` | Add `linkQuoteToDefect` method |
| `lib/services/email_service.dart` | Add `sendQuote` method |
| `lib/services/analytics_service.dart` | Add 4 quote analytics events |
| `lib/widgets/defect_bottom_sheet.dart` | Add "Quote This Defect" button |
| `lib/screens/assets/asset_detail_screen.dart` | Add quote button in defect card |

---

## Permissions (Company Users)

Add to `lib/models/permission.dart`:

```dart
// In AppPermission enum
quotesCreate,
quotesEdit,
quotesSend,
quotesApprove,
quotesConvert,
```

Check in UI: `UserProfileService.instance.hasPermission(AppPermission.quotesCreate)`

---

## Remote Config Flag

Add: `quoting_enabled` (default: false)

Gate the feature behind this flag until ready for release.

---

## Verification Plan

1. **Model tests:** Quote serialization, computed totals, status transitions
2. **Service tests:** QuoteService CRUD, SQLite and Firestore paths
3. **Integration test:** Create defect → tap Quote → fill form → save → appears in list
4. **PDF test:** Generate quote PDF, verify all sections render
5. **Email test:** Send quote email, verify PDF attachment
6. **Conversion test:** Approve quote → convert → verify DispatchedJob created
7. **Offline test:** Create quote offline (solo engineer), verify persistence

---

## Implementation Order

1. **Week 1:** Quote model, database schema, QuoteService
2. **Week 2:** quote_screen.dart, quote_list_screen.dart, quoting_hub_screen.dart
3. **Week 3:** Integration (defect_bottom_sheet, asset_detail_screen), PDF generation
4. **Week 4:** Email, quote-to-job conversion, analytics, testing

---

## Competitive Sources

- [Uptick Features](https://www.uptickhq.com/us/features)
- [Uptick Sales Quoting](https://www.uptickhq.com/us/features/service-quoting)
- [Uptick Defect Quoting](https://uptickhq.com/features/defect-quoting/index.html)
- [Simpro Fire Protection Software](https://www.simprogroup.com/industries/fire-protection-software)
