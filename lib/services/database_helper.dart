import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../models/models.dart';
import 'firestore_sync_service.dart';

/// Database helper to manage SQLite database operations
class DatabaseHelper {
  // Singleton pattern - only one instance of DatabaseHelper
  static final DatabaseHelper instance = DatabaseHelper._init();
  static Database? _database;

  DatabaseHelper._init();

  /// Get database instance (create if doesn't exist)
  Future<Database> get database async {
    if (kIsWeb) {
      throw UnsupportedError('SQLite is not available on web');
    }
    if (_database != null) return _database!;
    _database = await _initDB('jobsheets.db');
    return _database!;
  }

  /// Initialize database
  Future<Database> _initDB(String filePath) async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, filePath);

    return await openDatabase(
      path,
      version: 18,
      onCreate: _createDB,
      onUpgrade: _upgradeDB,
    );
  }

  /// Upgrade database for new versions
  Future<void> _upgradeDB(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      await _createInvoicesTable(db);
    }
    if (oldVersion < 3) {
      await _createSavedCustomersTable(db);
    }
    if (oldVersion < 4) {
      await _createCustomTemplatesTable(db);
      await _createFilledTemplatesTable(db);
    }
    if (oldVersion < 5) {
      // Recreate invoices table to fix column name issues
      await db.execute('DROP TABLE IF EXISTS invoices');
      await _createInvoicesTable(db);
    }
    if (oldVersion < 6) {
      await db.execute('ALTER TABLE jobsheets ADD COLUMN fieldLabels TEXT');
    }
    if (oldVersion < 7) {
      await db.execute("ALTER TABLE jobsheets ADD COLUMN status TEXT DEFAULT 'completed'");
    }
    if (oldVersion < 8) {
      await _createJobTemplatesTable(db);
    }
    if (oldVersion < 9) {
      await db.execute('ALTER TABLE job_templates ADD COLUMN sectionLayout TEXT');
      await db.execute('ALTER TABLE jobsheets ADD COLUMN sectionLayout TEXT');
    }
    if (oldVersion < 10) {
      await _createSavedSitesTable(db);
    }
    if (oldVersion < 11) {
      await db.execute('ALTER TABLE jobsheets ADD COLUMN lastModifiedAt TEXT');
      await db.execute('ALTER TABLE invoices ADD COLUMN lastModifiedAt TEXT');
      await db.execute('ALTER TABLE saved_customers ADD COLUMN lastModifiedAt TEXT');
      await db.execute('ALTER TABLE saved_sites ADD COLUMN lastModifiedAt TEXT');
      await db.execute('ALTER TABLE job_templates ADD COLUMN lastModifiedAt TEXT');
      await db.execute('ALTER TABLE filled_templates ADD COLUMN lastModifiedAt TEXT');
    }
    if (oldVersion < 12) {
      await db.execute('ALTER TABLE invoices ADD COLUMN customerEmail TEXT');
    }
    if (oldVersion < 13) {
      await db.execute('ALTER TABLE jobsheets ADD COLUMN dispatchedJobId TEXT');
      await db.execute('ALTER TABLE invoices ADD COLUMN useCompanyBranding INTEGER DEFAULT 0');
    }
    if (oldVersion < 14) {
      await _createAssetsTable(db);
      await _createAssetTypeConfigTable(db);
      await _createFloorPlansTable(db);
      await _createAssetServiceHistoryTable(db);
    }
    if (oldVersion < 15) {
      await db.execute('ALTER TABLE jobsheets ADD COLUMN siteId TEXT');
    }
    if (oldVersion < 16) {
      await db.execute(
          'ALTER TABLE jobsheets ADD COLUMN useCompanyBranding INTEGER DEFAULT 0');
    }
    if (oldVersion < 17) {
      await _createQuotesTable(db);
    }
    if (oldVersion < 18) {
      await db.execute('ALTER TABLE invoices ADD COLUMN linkedJobsheetId TEXT');
    }
  }

  /// Create database tables
  Future<void> _createDB(Database db, int version) async {
    const idType = 'TEXT PRIMARY KEY';
    const textType = 'TEXT NOT NULL';
    const textTypeNullable = 'TEXT';

    await db.execute('''
      CREATE TABLE jobsheets (
        id $idType,
        engineerId $textType,
        engineerName $textType,
        date $textType,
        customerName $textType,
        siteAddress $textType,
        jobNumber $textType,
        systemCategory $textTypeNullable,
        templateType $textType,
        formData $textType,
        fieldLabels $textTypeNullable,
        status $textType DEFAULT 'draft',
        engineerSignature $textTypeNullable,
        customerSignature $textTypeNullable,
        customerSignatureName $textTypeNullable,
        notes $textTypeNullable,
        defects $textTypeNullable,
        createdAt $textType,
        sectionLayout $textTypeNullable,
        lastModifiedAt $textTypeNullable,
        dispatchedJobId $textTypeNullable,
        siteId $textTypeNullable,
        useCompanyBranding INTEGER NOT NULL DEFAULT 0
      )
    ''');

    await _createInvoicesTable(db);
    await _createSavedCustomersTable(db);
    await _createCustomTemplatesTable(db);
    await _createFilledTemplatesTable(db);
    await _createJobTemplatesTable(db);
    await _createSavedSitesTable(db);
    await _createAssetsTable(db);
    await _createAssetTypeConfigTable(db);
    await _createFloorPlansTable(db);
    await _createAssetServiceHistoryTable(db);
    await _createQuotesTable(db);

    debugPrint('Database tables created successfully');
  }

  /// Create job_templates table for custom JobTemplate objects
  Future<void> _createJobTemplatesTable(Database db) async {
    const idType = 'TEXT PRIMARY KEY';
    const textType = 'TEXT NOT NULL';
    const textTypeNullable = 'TEXT';

    await db.execute('''
      CREATE TABLE job_templates (
        id $idType,
        name $textType,
        description $textType,
        fields $textType,
        isShared INTEGER NOT NULL DEFAULT 0,
        creatorId $textTypeNullable,
        createdAt $textTypeNullable,
        sectionLayout $textTypeNullable,
        lastModifiedAt $textTypeNullable
      )
    ''');

    debugPrint('Job templates table created successfully');
  }

  /// Create saved_customers table
  Future<void> _createSavedCustomersTable(Database db) async {
    const idType = 'TEXT PRIMARY KEY';
    const textType = 'TEXT NOT NULL';
    const textTypeNullable = 'TEXT';

    await db.execute('''
      CREATE TABLE saved_customers (
        id $idType,
        engineerId $textType,
        customerName $textType,
        customerAddress $textType,
        email $textTypeNullable,
        notes $textTypeNullable,
        createdAt $textType,
        lastModifiedAt $textTypeNullable
      )
    ''');

    debugPrint('Saved customers table created successfully');
  }

  /// Create invoices table
  Future<void> _createInvoicesTable(Database db) async {
    const idType = 'TEXT PRIMARY KEY';
    const textType = 'TEXT NOT NULL';
    const textTypeNullable = 'TEXT';

    await db.execute('''
      CREATE TABLE invoices (
        id $idType,
        invoiceNumber $textType,
        engineerId $textType,
        engineerName $textType,
        customerName $textType,
        customerAddress $textType,
        customerEmail $textTypeNullable,
        date $textType,
        dueDate $textType,
        items $textType,
        notes $textTypeNullable,
        includeVat INTEGER NOT NULL DEFAULT 0,
        status $textType,
        createdAt $textType,
        lastModifiedAt $textTypeNullable,
        useCompanyBranding INTEGER NOT NULL DEFAULT 0,
        linkedJobsheetId $textTypeNullable
      )
    ''');

    debugPrint('Invoices table created successfully');
  }

  /// Insert a jobsheet
  Future<Jobsheet> insertJobsheet(Jobsheet jobsheet) async {
    final db = await database;
    final stamped = jobsheet.copyWith(lastModifiedAt: DateTime.now());

    await db.insert(
      'jobsheets',
      stamped.toJson(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );

    debugPrint('Jobsheet inserted: ${stamped.id}');
    FirestoreSyncService.instance.upsertJobsheet(stamped);
    return stamped;
  }

  /// Get all jobsheets
  Future<List<Jobsheet>> getAllJobsheets() async {
    final db = await database;

    final result = await db.query('jobsheets', orderBy: 'date DESC');

    return result.map((json) => Jobsheet.fromJson(json)).toList();
  }

  /// Get jobsheets by engineer ID
  Future<List<Jobsheet>> getJobsheetsByEngineerId(String engineerId) async {
    final db = await database;

    final result = await db.query(
      'jobsheets',
      where: 'engineerId = ?',
      whereArgs: [engineerId],
      orderBy: 'createdAt DESC',
    );

    return result.map((json) => Jobsheet.fromJson(json)).toList();
  }

  /// Get draft jobsheets by engineer ID
  Future<List<Jobsheet>> getDraftJobsheetsByEngineerId(String engineerId) async {
    final db = await database;

    final result = await db.query(
      'jobsheets',
      where: 'engineerId = ? AND status = ?',
      whereArgs: [engineerId, 'draft'],
      orderBy: 'createdAt DESC',
    );

    return result.map((json) => Jobsheet.fromJson(json)).toList();
  }

  /// Get a single jobsheet by ID
  Future<Jobsheet?> getJobsheetById(String id) async {
    final db = await database;

    final result = await db.query(
      'jobsheets',
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );

    if (result.isEmpty) return null;

    return Jobsheet.fromJson(result.first);
  }

  /// Update a jobsheet
  Future<int> updateJobsheet(Jobsheet jobsheet) async {
    final db = await database;
    final stamped = jobsheet.copyWith(lastModifiedAt: DateTime.now());

    final result = await db.update(
      'jobsheets',
      stamped.toJson(),
      where: 'id = ?',
      whereArgs: [stamped.id],
    );
    FirestoreSyncService.instance.upsertJobsheet(stamped);
    return result;
  }

  /// Delete a jobsheet
  Future<int> deleteJobsheet(String id) async {
    final db = await database;

    final result = await db.delete('jobsheets', where: 'id = ?', whereArgs: [id]);
    FirestoreSyncService.instance.deleteDocument('jobsheets', id);
    return result;
  }

  Future<int> deleteJobsheets(List<String> ids) async {
    if (ids.isEmpty) return 0;
    final db = await database;
    final placeholders = List.filled(ids.length, '?').join(',');
    final result = await db.delete(
      'jobsheets',
      where: 'id IN ($placeholders)',
      whereArgs: ids,
    );
    for (final id in ids) {
      FirestoreSyncService.instance.deleteDocument('jobsheets', id);
    }
    return result;
  }

  /// Search jobsheets by customer name or job number
  Future<List<Jobsheet>> searchJobsheets(String query) async {
    final db = await database;

    final result = await db.query(
      'jobsheets',
      where: 'customerName LIKE ? OR jobNumber LIKE ?',
      whereArgs: ['%$query%', '%$query%'],
      orderBy: 'date DESC',
    );

    return result.map((json) => Jobsheet.fromJson(json)).toList();
  }

  /// Get jobsheets count
  Future<int> getJobsheetsCount() async {
    final db = await database;
    final result = await db.rawQuery('SELECT COUNT(*) FROM jobsheets');
    return Sqflite.firstIntValue(result) ?? 0;
  }

  /// Get jobsheets by date range
  Future<List<Jobsheet>> getJobsheetsByDateRange({
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    final db = await database;

    final result = await db.query(
      'jobsheets',
      where: 'date BETWEEN ? AND ?',
      whereArgs: [startDate.toIso8601String(), endDate.toIso8601String()],
      orderBy: 'date DESC',
    );

    return result.map((json) => Jobsheet.fromJson(json)).toList();
  }

  /// Delete all jobsheets (for testing/reset)
  Future<int> deleteAllJobsheets() async {
    final db = await database;
    return await db.delete('jobsheets');
  }

  // ==================== INVOICE METHODS ====================

  /// Insert an invoice
  Future<Invoice> insertInvoice(Invoice invoice) async {
    final db = await database;
    final stamped = invoice.copyWith(lastModifiedAt: DateTime.now());

    final json = stamped.toJson();
    // Convert items list to JSON string for storage
    json['items'] = jsonEncode(json['items']);
    // Convert bool to int for SQLite
    json['includeVat'] = json['includeVat'] == true ? 1 : 0;

    await db.insert(
      'invoices',
      json,
      conflictAlgorithm: ConflictAlgorithm.replace,
    );

    debugPrint('Invoice inserted: ${stamped.id}');
    FirestoreSyncService.instance.upsertInvoice(stamped);
    return stamped;
  }

  /// Get all invoices
  Future<List<Invoice>> getAllInvoices() async {
    final db = await database;

    final result = await db.query('invoices', orderBy: 'createdAt DESC');

    return result.map((json) => _parseInvoiceJson(json)).toList();
  }

  /// Get invoices by engineer ID
  Future<List<Invoice>> getInvoicesByEngineerId(String engineerId) async {
    final db = await database;

    final result = await db.query(
      'invoices',
      where: 'engineerId = ?',
      whereArgs: [engineerId],
      orderBy: 'createdAt DESC',
    );

    return result.map((json) => _parseInvoiceJson(json)).toList();
  }

  /// Get outstanding (sent but not paid) invoices by engineer ID
  Future<List<Invoice>> getOutstandingInvoicesByEngineerId(String engineerId) async {
    final db = await database;

    final result = await db.query(
      'invoices',
      where: 'engineerId = ? AND status = ?',
      whereArgs: [engineerId, 'sent'],
      orderBy: 'createdAt DESC',
    );

    return result.map((json) => _parseInvoiceJson(json)).toList();
  }

  /// Get draft invoices by engineer ID
  Future<List<Invoice>> getDraftInvoicesByEngineerId(String engineerId) async {
    final db = await database;

    final result = await db.query(
      'invoices',
      where: 'engineerId = ? AND status = ?',
      whereArgs: [engineerId, 'draft'],
      orderBy: 'createdAt DESC',
    );

    return result.map((json) => _parseInvoiceJson(json)).toList();
  }

  /// Get a single invoice by ID
  Future<Invoice?> getInvoiceById(String id) async {
    final db = await database;

    final result = await db.query(
      'invoices',
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );

    if (result.isEmpty) return null;

    return _parseInvoiceJson(result.first);
  }

  /// Update an invoice
  Future<int> updateInvoice(Invoice invoice) async {
    final db = await database;
    final stamped = invoice.copyWith(lastModifiedAt: DateTime.now());

    final json = stamped.toJson();
    json['items'] = jsonEncode(json['items']);
    // Convert bool to int for SQLite
    json['includeVat'] = json['includeVat'] == true ? 1 : 0;

    final result = await db.update(
      'invoices',
      json,
      where: 'id = ?',
      whereArgs: [stamped.id],
    );
    FirestoreSyncService.instance.upsertInvoice(stamped);
    return result;
  }

  /// Delete an invoice
  Future<int> deleteInvoice(String id) async {
    final db = await database;

    final result = await db.delete('invoices', where: 'id = ?', whereArgs: [id]);
    FirestoreSyncService.instance.deleteDocument('invoices', id);
    return result;
  }

  Future<int> deleteInvoices(List<String> ids) async {
    if (ids.isEmpty) return 0;
    final db = await database;
    final placeholders = List.filled(ids.length, '?').join(',');
    final result = await db.delete(
      'invoices',
      where: 'id IN ($placeholders)',
      whereArgs: ids,
    );
    for (final id in ids) {
      FirestoreSyncService.instance.deleteDocument('invoices', id);
    }
    return result;
  }

  /// Get next invoice number
  Future<String> getNextInvoiceNumber() async {
    final db = await database;
    final result = await db.rawQuery('SELECT COUNT(*) FROM invoices');
    final count = (Sqflite.firstIntValue(result) ?? 0) + 1;
    return count.toString();
  }

  /// Parse invoice JSON from database (handles items string conversion)
  Invoice _parseInvoiceJson(Map<String, dynamic> json) {
    final mutableJson = Map<String, dynamic>.from(json);

    // Parse items from string back to list
    if (mutableJson['items'] is String) {
      final itemsStr = mutableJson['items'] as String;
      // Parse the string representation of list back to actual list
      final itemsList = _parseItemsString(itemsStr);
      mutableJson['items'] = itemsList;
    }

    // Convert int to bool for includeVat
    if (mutableJson['includeVat'] is int) {
      mutableJson['includeVat'] = mutableJson['includeVat'] == 1;
    }

    return Invoice.fromJson(mutableJson);
  }

  /// Parse items string back to list of maps
  List<Map<String, dynamic>> _parseItemsString(String itemsStr) {
    // Handle empty or invalid strings
    if (itemsStr.isEmpty || itemsStr == '[]') return [];

    try {
      // Use dart:convert for proper JSON parsing
      final List<dynamic> parsed =
          (itemsStr.startsWith('['))
              ? _parseJsonList(itemsStr)
              : [];
      return parsed.cast<Map<String, dynamic>>();
    } catch (e) {
      debugPrint('Error parsing items: $e');
      return [];
    }
  }

  /// Simple JSON list parser
  List<dynamic> _parseJsonList(String jsonStr) {
    return jsonDecode(jsonStr) as List<dynamic>;
  }

  // ==================== QUOTES TABLE & METHODS ====================

  /// Create quotes table
  Future<void> _createQuotesTable(Database db) async {
    const idType = 'TEXT PRIMARY KEY';
    const textType = 'TEXT NOT NULL';
    const textTypeNullable = 'TEXT';

    await db.execute('''
      CREATE TABLE quotes (
        id $idType,
        quoteNumber $textType,
        engineerId $textType,
        engineerName $textType,
        companyId $textTypeNullable,
        customerName $textType,
        customerAddress $textType,
        customerEmail $textTypeNullable,
        customerPhone $textTypeNullable,
        siteId $textType,
        siteName $textType,
        defectId $textTypeNullable,
        defectDescription $textTypeNullable,
        defectSeverity $textTypeNullable,
        items $textType,
        notes $textTypeNullable,
        includeVat INTEGER NOT NULL DEFAULT 0,
        status $textType,
        validUntil $textType,
        createdAt $textType,
        lastModifiedAt $textTypeNullable,
        sentAt $textTypeNullable,
        respondedAt $textTypeNullable,
        convertedJobId $textTypeNullable,
        useCompanyBranding INTEGER NOT NULL DEFAULT 0
      )
    ''');

    debugPrint('Quotes table created successfully');
  }

  /// Insert a quote
  Future<Quote> insertQuote(Quote quote) async {
    final db = await database;
    final stamped = quote.copyWith(lastModifiedAt: DateTime.now());

    final json = stamped.toJson();
    json['items'] = jsonEncode(json['items']);
    json['includeVat'] = json['includeVat'] == true ? 1 : 0;
    json['useCompanyBranding'] = json['useCompanyBranding'] == 1 ? 1 : 0;

    await db.insert(
      'quotes',
      json,
      conflictAlgorithm: ConflictAlgorithm.replace,
    );

    debugPrint('Quote inserted: ${stamped.id}');
    FirestoreSyncService.instance.upsertQuote(stamped);
    return stamped;
  }

  /// Get all quotes
  Future<List<Quote>> getAllQuotes() async {
    final db = await database;
    final result = await db.query('quotes', orderBy: 'createdAt DESC');
    return result.map((json) => _parseQuoteJson(json)).toList();
  }

  /// Get quotes by engineer ID
  Future<List<Quote>> getQuotesByEngineerId(String engineerId) async {
    final db = await database;
    final result = await db.query(
      'quotes',
      where: 'engineerId = ?',
      whereArgs: [engineerId],
      orderBy: 'createdAt DESC',
    );
    return result.map((json) => _parseQuoteJson(json)).toList();
  }

  /// Get quotes by engineer ID and status
  Future<List<Quote>> getQuotesByStatus(String engineerId, String status) async {
    final db = await database;
    final result = await db.query(
      'quotes',
      where: 'engineerId = ? AND status = ?',
      whereArgs: [engineerId, status],
      orderBy: 'createdAt DESC',
    );
    return result.map((json) => _parseQuoteJson(json)).toList();
  }

  /// Get draft quotes by engineer ID
  Future<List<Quote>> getDraftQuotesByEngineerId(String engineerId) async {
    return getQuotesByStatus(engineerId, 'draft');
  }

  /// Get a single quote by ID
  Future<Quote?> getQuoteById(String id) async {
    final db = await database;
    final result = await db.query(
      'quotes',
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    if (result.isEmpty) return null;
    return _parseQuoteJson(result.first);
  }

  /// Update a quote
  Future<int> updateQuote(Quote quote) async {
    final db = await database;
    final stamped = quote.copyWith(lastModifiedAt: DateTime.now());

    final json = stamped.toJson();
    json['items'] = jsonEncode(json['items']);
    json['includeVat'] = json['includeVat'] == true ? 1 : 0;
    json['useCompanyBranding'] = json['useCompanyBranding'] == 1 ? 1 : 0;

    final result = await db.update(
      'quotes',
      json,
      where: 'id = ?',
      whereArgs: [stamped.id],
    );
    FirestoreSyncService.instance.upsertQuote(stamped);
    return result;
  }

  /// Delete a quote
  Future<int> deleteQuote(String id) async {
    final db = await database;
    final result = await db.delete('quotes', where: 'id = ?', whereArgs: [id]);
    FirestoreSyncService.instance.deleteDocument('quotes', id);
    return result;
  }

  Future<int> deleteQuotes(List<String> ids) async {
    if (ids.isEmpty) return 0;
    final db = await database;
    final placeholders = List.filled(ids.length, '?').join(',');
    final result = await db.delete(
      'quotes',
      where: 'id IN ($placeholders)',
      whereArgs: ids,
    );
    for (final id in ids) {
      FirestoreSyncService.instance.deleteDocument('quotes', id);
    }
    return result;
  }

  /// Get next quote number (Q-0001 format)
  Future<String> getNextQuoteNumber() async {
    final db = await database;
    final result = await db.rawQuery(
        "SELECT MAX(CAST(REPLACE(quoteNumber, 'Q-', '') AS INTEGER)) AS maxNum FROM quotes");
    final maxNum = Sqflite.firstIntValue(result) ?? 0;
    return 'Q-${(maxNum + 1).toString().padLeft(4, '0')}';
  }

  /// Delete all quotes
  Future<int> deleteAllQuotes() async {
    final db = await database;
    return await db.delete('quotes');
  }

  /// Parse quote JSON from database (handles items string conversion)
  Quote _parseQuoteJson(Map<String, dynamic> json) {
    final mutableJson = Map<String, dynamic>.from(json);

    if (mutableJson['items'] is String) {
      final itemsStr = mutableJson['items'] as String;
      final itemsList = _parseItemsString(itemsStr);
      mutableJson['items'] = itemsList;
    }

    if (mutableJson['includeVat'] is int) {
      mutableJson['includeVat'] = mutableJson['includeVat'] == 1;
    }

    if (mutableJson['useCompanyBranding'] is int) {
      mutableJson['useCompanyBranding'] = mutableJson['useCompanyBranding'] == 1;
    }

    return Quote.fromJson(mutableJson);
  }

  // ==================== SAVED CUSTOMERS METHODS ====================

  /// Insert a saved customer
  Future<SavedCustomer> insertSavedCustomer(SavedCustomer customer) async {
    final db = await database;
    final stamped = customer.copyWith(lastModifiedAt: DateTime.now());

    await db.insert(
      'saved_customers',
      stamped.toJson(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );

    debugPrint('Saved customer inserted: ${stamped.id}');
    FirestoreSyncService.instance.upsertSavedCustomer(stamped);
    return stamped;
  }

  /// Get all saved customers for an engineer
  Future<List<SavedCustomer>> getSavedCustomersByEngineerId(String engineerId) async {
    final db = await database;

    final result = await db.query(
      'saved_customers',
      where: 'engineerId = ?',
      whereArgs: [engineerId],
      orderBy: 'customerName ASC',
    );

    return result.map((json) => SavedCustomer.fromJson(json)).toList();
  }

  /// Get a single saved customer by ID
  Future<SavedCustomer?> getSavedCustomerById(String id) async {
    final db = await database;

    final result = await db.query(
      'saved_customers',
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );

    if (result.isEmpty) return null;

    return SavedCustomer.fromJson(result.first);
  }

  /// Update a saved customer
  Future<int> updateSavedCustomer(SavedCustomer customer) async {
    final db = await database;
    final stamped = customer.copyWith(lastModifiedAt: DateTime.now());

    final result = await db.update(
      'saved_customers',
      stamped.toJson(),
      where: 'id = ?',
      whereArgs: [stamped.id],
    );
    FirestoreSyncService.instance.upsertSavedCustomer(stamped);
    return result;
  }

  /// Delete a saved customer
  Future<int> deleteSavedCustomer(String id) async {
    final db = await database;

    final result = await db.delete('saved_customers', where: 'id = ?', whereArgs: [id]);
    FirestoreSyncService.instance.deleteDocument('saved_customers', id);
    return result;
  }

  Future<int> deleteSavedCustomers(List<String> ids) async {
    if (ids.isEmpty) return 0;
    final db = await database;
    final placeholders = List.filled(ids.length, '?').join(',');
    final result = await db.delete(
      'saved_customers',
      where: 'id IN ($placeholders)',
      whereArgs: ids,
    );
    for (final id in ids) {
      FirestoreSyncService.instance.deleteDocument('saved_customers', id);
    }
    return result;
  }

  /// Search saved customers by name
  Future<List<SavedCustomer>> searchSavedCustomers(String engineerId, String query) async {
    final db = await database;

    final result = await db.query(
      'saved_customers',
      where: 'engineerId = ? AND customerName LIKE ?',
      whereArgs: [engineerId, '%$query%'],
      orderBy: 'customerName ASC',
    );

    return result.map((json) => SavedCustomer.fromJson(json)).toList();
  }

  // ==================== CUSTOM TEMPLATES METHODS ====================

  /// Create custom_templates table
  Future<void> _createCustomTemplatesTable(Database db) async {
    const idType = 'TEXT PRIMARY KEY';
    const textType = 'TEXT NOT NULL';
    const textTypeNullable = 'TEXT';

    await db.execute('''
      CREATE TABLE custom_templates (
        id $idType,
        name $textType,
        description $textTypeNullable,
        category $textType,
        pdfPath $textType,
        isBundled INTEGER NOT NULL DEFAULT 0,
        fields $textType,
        pageCount INTEGER NOT NULL DEFAULT 1,
        createdAt $textType,
        updatedAt $textTypeNullable
      )
    ''');

    debugPrint('Custom templates table created successfully');
  }

  /// Create filled_templates table
  Future<void> _createFilledTemplatesTable(Database db) async {
    const idType = 'TEXT PRIMARY KEY';
    const textType = 'TEXT NOT NULL';
    const textTypeNullable = 'TEXT';

    await db.execute('''
      CREATE TABLE filled_templates (
        id $idType,
        templateId $textType,
        engineerId $textType,
        engineerName $textType,
        jobReference $textTypeNullable,
        fieldValues $textType,
        createdAt $textType,
        completedAt $textTypeNullable,
        isComplete INTEGER NOT NULL DEFAULT 0,
        lastModifiedAt $textTypeNullable
      )
    ''');

    debugPrint('Filled templates table created successfully');
  }

  /// Insert a custom PDF form template
  Future<PdfFormTemplate> insertPdfFormTemplate(PdfFormTemplate template) async {
    final db = await database;

    final json = template.toJson();
    json['isBundled'] = json['isBundled'] == true ? 1 : 0;

    await db.insert(
      'custom_templates',
      json,
      conflictAlgorithm: ConflictAlgorithm.replace,
    );

    debugPrint('PDF form template inserted: ${template.id}');
    return template;
  }

  /// Get all custom PDF form templates
  Future<List<PdfFormTemplate>> getAllPdfFormTemplates() async {
    final db = await database;

    final result = await db.query('custom_templates', orderBy: 'name ASC');

    return result.map((json) => _parsePdfFormTemplateJson(json)).toList();
  }

  /// Get a single PDF form template by ID
  Future<PdfFormTemplate?> getPdfFormTemplateById(String id) async {
    final db = await database;

    final result = await db.query(
      'custom_templates',
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );

    if (result.isEmpty) return null;

    return _parsePdfFormTemplateJson(result.first);
  }

  /// Update a PDF form template
  Future<int> updatePdfFormTemplate(PdfFormTemplate template) async {
    final db = await database;

    final json = template.toJson();
    json['isBundled'] = json['isBundled'] == true ? 1 : 0;

    return await db.update(
      'custom_templates',
      json,
      where: 'id = ?',
      whereArgs: [template.id],
    );
  }

  /// Delete a PDF form template
  Future<int> deletePdfFormTemplate(String id) async {
    final db = await database;

    return await db.delete('custom_templates', where: 'id = ?', whereArgs: [id]);
  }

  /// Parse PDF form template JSON from database
  PdfFormTemplate _parsePdfFormTemplateJson(Map<String, dynamic> json) {
    final mutableJson = Map<String, dynamic>.from(json);

    // Convert int to bool for isBundled
    if (mutableJson['isBundled'] is int) {
      mutableJson['isBundled'] = mutableJson['isBundled'] == 1;
    }

    return PdfFormTemplate.fromJson(mutableJson);
  }

  // ==================== FILLED PDF FORMS METHODS ====================

  /// Insert a filled PDF form
  Future<FilledPdfForm> insertFilledPdfForm(FilledPdfForm filled) async {
    final db = await database;
    final stamped = filled.copyWith(lastModifiedAt: DateTime.now());

    await db.insert(
      'filled_templates',
      stamped.toJson(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );

    debugPrint('Filled PDF form inserted: ${stamped.id}');
    FirestoreSyncService.instance.upsertFilledPdfForm(stamped);
    return stamped;
  }

  /// Get all filled PDF forms for an engineer
  Future<List<FilledPdfForm>> getFilledPdfFormsByEngineerId(String engineerId) async {
    final db = await database;

    final result = await db.query(
      'filled_templates',
      where: 'engineerId = ?',
      whereArgs: [engineerId],
      orderBy: 'createdAt DESC',
    );

    return result.map((json) => FilledPdfForm.fromJson(json)).toList();
  }

  /// Get a single filled PDF form by ID
  Future<FilledPdfForm?> getFilledPdfFormById(String id) async {
    final db = await database;

    final result = await db.query(
      'filled_templates',
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );

    if (result.isEmpty) return null;

    return FilledPdfForm.fromJson(result.first);
  }

  /// Update a filled PDF form
  Future<int> updateFilledPdfForm(FilledPdfForm filled) async {
    final db = await database;
    final stamped = filled.copyWith(lastModifiedAt: DateTime.now());

    final result = await db.update(
      'filled_templates',
      stamped.toJson(),
      where: 'id = ?',
      whereArgs: [stamped.id],
    );
    FirestoreSyncService.instance.upsertFilledPdfForm(stamped);
    return result;
  }

  /// Delete a filled PDF form
  Future<int> deleteFilledPdfForm(String id) async {
    final db = await database;

    final result = await db.delete('filled_templates', where: 'id = ?', whereArgs: [id]);
    FirestoreSyncService.instance.deleteDocument('filled_templates', id);
    return result;
  }

  /// Get filled PDF forms by template ID
  Future<List<FilledPdfForm>> getFilledPdfFormsByTemplateId(String templateId) async {
    final db = await database;

    final result = await db.query(
      'filled_templates',
      where: 'templateId = ?',
      whereArgs: [templateId],
      orderBy: 'createdAt DESC',
    );

    return result.map((json) => FilledPdfForm.fromJson(json)).toList();
  }

  // ==================== JOB TEMPLATES METHODS ====================

  /// Insert a job template
  Future<JobTemplate> insertJobTemplate(JobTemplate template) async {
    final db = await database;
    final stamped = template.copyWith(lastModifiedAt: DateTime.now());

    final json = stamped.toJson();
    // Convert fields list to JSON string for storage
    json['fields'] = jsonEncode(json['fields']);
    // Convert bool to int for SQLite
    json['isShared'] = json['isShared'] == true ? 1 : 0;
    // Convert sectionLayout map to JSON string for storage
    if (json['sectionLayout'] != null) {
      json['sectionLayout'] = jsonEncode(json['sectionLayout']);
    }

    await db.insert(
      'job_templates',
      json,
      conflictAlgorithm: ConflictAlgorithm.replace,
    );

    debugPrint('Job template inserted: ${stamped.id}');
    FirestoreSyncService.instance.upsertJobTemplate(stamped);
    return stamped;
  }

  /// Get all job templates
  Future<List<JobTemplate>> getAllJobTemplates() async {
    final db = await database;

    final result = await db.query('job_templates', orderBy: 'name ASC');

    return result.map((json) => _parseJobTemplateJson(json)).toList();
  }

  /// Get a single job template by ID
  Future<JobTemplate?> getJobTemplateById(String id) async {
    final db = await database;

    final result = await db.query(
      'job_templates',
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );

    if (result.isEmpty) return null;

    return _parseJobTemplateJson(result.first);
  }

  /// Update a job template
  Future<int> updateJobTemplate(JobTemplate template) async {
    final db = await database;
    final stamped = template.copyWith(lastModifiedAt: DateTime.now());

    final json = stamped.toJson();
    json['fields'] = jsonEncode(json['fields']);
    json['isShared'] = json['isShared'] == true ? 1 : 0;
    if (json['sectionLayout'] != null) {
      json['sectionLayout'] = jsonEncode(json['sectionLayout']);
    }

    final result = await db.update(
      'job_templates',
      json,
      where: 'id = ?',
      whereArgs: [stamped.id],
    );
    FirestoreSyncService.instance.upsertJobTemplate(stamped);
    return result;
  }

  /// Delete a job template
  Future<int> deleteJobTemplate(String id) async {
    final db = await database;

    final result = await db.delete('job_templates', where: 'id = ?', whereArgs: [id]);
    FirestoreSyncService.instance.deleteDocument('job_templates', id);
    return result;
  }

  /// Parse job template JSON from database
  JobTemplate _parseJobTemplateJson(Map<String, dynamic> json) {
    final mutableJson = Map<String, dynamic>.from(json);

    // Parse fields from string back to list
    if (mutableJson['fields'] is String) {
      final fieldsStr = mutableJson['fields'] as String;
      mutableJson['fields'] = jsonDecode(fieldsStr) as List<dynamic>;
    }

    // Convert int to bool for isShared
    if (mutableJson['isShared'] is int) {
      mutableJson['isShared'] = mutableJson['isShared'] == 1;
    }

    // Parse sectionLayout from string back to map
    if (mutableJson['sectionLayout'] is String) {
      final layoutStr = mutableJson['sectionLayout'] as String;
      if (layoutStr.isNotEmpty) {
        mutableJson['sectionLayout'] = jsonDecode(layoutStr) as Map<String, dynamic>;
      } else {
        mutableJson['sectionLayout'] = null;
      }
    }

    return JobTemplate.fromJson(mutableJson);
  }

  // ==================== SAVED SITES METHODS ====================

  /// Create saved_sites table
  Future<void> _createSavedSitesTable(Database db) async {
    const idType = 'TEXT PRIMARY KEY';
    const textType = 'TEXT NOT NULL';
    const textTypeNullable = 'TEXT';

    await db.execute('''
      CREATE TABLE saved_sites (
        id $idType,
        engineerId $textType,
        siteName $textType,
        address $textType,
        notes $textTypeNullable,
        createdAt $textType,
        lastModifiedAt $textTypeNullable
      )
    ''');

    debugPrint('Saved sites table created successfully');
  }

  /// Insert a saved site
  Future<SavedSite> insertSavedSite(SavedSite site) async {
    final db = await database;
    final stamped = site.copyWith(lastModifiedAt: DateTime.now());

    await db.insert(
      'saved_sites',
      stamped.toJson(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );

    debugPrint('Saved site inserted: ${stamped.id}');
    FirestoreSyncService.instance.upsertSavedSite(stamped);
    return stamped;
  }

  /// Update a saved site
  Future<int> updateSavedSite(SavedSite site) async {
    final db = await database;
    final stamped = site.copyWith(lastModifiedAt: DateTime.now());

    final result = await db.update(
      'saved_sites',
      stamped.toJson(),
      where: 'id = ?',
      whereArgs: [stamped.id],
    );
    FirestoreSyncService.instance.upsertSavedSite(stamped);
    return result;
  }

  /// Get all saved sites for an engineer
  Future<List<SavedSite>> getSavedSitesByEngineerId(String engineerId) async {
    final db = await database;

    final result = await db.query(
      'saved_sites',
      where: 'engineerId = ?',
      whereArgs: [engineerId],
      orderBy: 'siteName ASC',
    );

    return result.map((json) => SavedSite.fromJson(json)).toList();
  }

  /// Delete a saved site
  Future<int> deleteSavedSite(String id) async {
    final db = await database;

    final result = await db.delete('saved_sites', where: 'id = ?', whereArgs: [id]);
    FirestoreSyncService.instance.deleteDocument('saved_sites', id);
    return result;
  }

  Future<int> deleteSavedSites(List<String> ids) async {
    if (ids.isEmpty) return 0;
    final db = await database;
    final placeholders = List.filled(ids.length, '?').join(',');
    final result = await db.delete(
      'saved_sites',
      where: 'id IN ($placeholders)',
      whereArgs: ids,
    );
    for (final id in ids) {
      FirestoreSyncService.instance.deleteDocument('saved_sites', id);
    }
    return result;
  }

  // ==================== BULK DELETE METHODS ====================

  /// Delete all invoices
  Future<int> deleteAllInvoices() async {
    final db = await database;
    return await db.delete('invoices');
  }

  /// Delete all saved customers
  Future<int> deleteAllSavedCustomers() async {
    final db = await database;
    return await db.delete('saved_customers');
  }

  /// Delete all saved sites
  Future<int> deleteAllSavedSites() async {
    final db = await database;
    return await db.delete('saved_sites');
  }

  /// Delete all job templates
  Future<int> deleteAllJobTemplates() async {
    final db = await database;
    return await db.delete('job_templates');
  }

  /// Delete all PDF form templates
  Future<int> deleteAllPdfFormTemplates() async {
    final db = await database;
    return await db.delete('custom_templates');
  }

  /// Delete all filled PDF forms
  Future<int> deleteAllFilledPdfForms() async {
    final db = await database;
    return await db.delete('filled_templates');
  }

  /// Delete all local data across all tables
  Future<void> deleteAllData() async {
    await deleteAllJobsheets();
    await deleteAllInvoices();
    await deleteAllQuotes();
    await deleteAllSavedCustomers();
    await deleteAllSavedSites();
    await deleteAllJobTemplates();
    await deleteAllPdfFormTemplates();
    await deleteAllFilledPdfForms();
  }

  // ==================== ASSET REGISTER TABLES ====================

  Future<void> _createAssetsTable(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS assets (
        id TEXT PRIMARY KEY,
        siteId TEXT NOT NULL,
        assetTypeId TEXT NOT NULL,
        variant TEXT,
        make TEXT,
        model TEXT,
        serialNumber TEXT,
        reference TEXT,
        barcode TEXT,
        floorPlanId TEXT,
        xPercent REAL,
        yPercent REAL,
        locationDescription TEXT,
        zone TEXT,
        installDate TEXT,
        warrantyExpiry TEXT,
        expectedLifespanYears INTEGER,
        decommissionDate TEXT,
        decommissionReason TEXT,
        complianceStatus TEXT NOT NULL DEFAULT 'untested',
        lastServiceDate TEXT,
        lastServiceBy TEXT,
        lastServiceByName TEXT,
        nextServiceDue TEXT,
        photoUrl TEXT,
        createdBy TEXT NOT NULL,
        createdAt TEXT NOT NULL,
        updatedAt TEXT NOT NULL,
        notes TEXT,
        lastModifiedAt TEXT
      )
    ''');
    debugPrint('Assets table created successfully');
  }

  Future<void> _createAssetTypeConfigTable(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS asset_type_config (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        category TEXT,
        iconName TEXT NOT NULL,
        defaultColor TEXT NOT NULL,
        variants TEXT,
        defaultLifespanYears INTEGER,
        defaultChecklist TEXT,
        isBuiltIn INTEGER NOT NULL DEFAULT 0,
        lastModifiedAt TEXT
      )
    ''');
    debugPrint('Asset type config table created successfully');
  }

  Future<void> _createFloorPlansTable(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS floor_plans (
        id TEXT PRIMARY KEY,
        siteId TEXT NOT NULL,
        name TEXT NOT NULL,
        sortOrder INTEGER NOT NULL DEFAULT 0,
        imageUrl TEXT NOT NULL,
        imageWidth REAL NOT NULL,
        imageHeight REAL NOT NULL,
        createdBy TEXT NOT NULL,
        createdAt TEXT NOT NULL,
        updatedAt TEXT NOT NULL,
        lastModifiedAt TEXT
      )
    ''');
    debugPrint('Floor plans table created successfully');
  }

  Future<void> _createAssetServiceHistoryTable(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS asset_service_history (
        id TEXT PRIMARY KEY,
        assetId TEXT NOT NULL,
        siteId TEXT NOT NULL,
        jobsheetId TEXT,
        dispatchedJobId TEXT,
        engineerId TEXT NOT NULL,
        engineerName TEXT NOT NULL,
        serviceDate TEXT NOT NULL,
        overallResult TEXT NOT NULL,
        checklistResults TEXT,
        defectNote TEXT,
        defectPhotoUrls TEXT,
        defectSeverity TEXT,
        defectAction TEXT,
        notes TEXT,
        createdAt TEXT NOT NULL
      )
    ''');
    debugPrint('Asset service history table created successfully');
  }

  // ==================== ASSET CRUD ====================

  /// Insert an asset (solo users)
  Future<Asset> insertAsset(Asset asset) async {
    final db = await database;
    final stamped = asset.copyWith(lastModifiedAt: DateTime.now());

    await db.insert(
      'assets',
      stamped.toJson(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );

    debugPrint('Asset inserted: ${stamped.id}');
    return stamped;
  }

  /// Get all assets for a site (solo users)
  Future<List<Asset>> getAssetsBySiteId(String siteId) async {
    final db = await database;

    final result = await db.query(
      'assets',
      where: 'siteId = ?',
      whereArgs: [siteId],
      orderBy: 'reference ASC',
    );

    return result.map((json) => Asset.fromJson(json)).toList();
  }

  /// Update an asset (solo users)
  Future<int> updateAsset(Asset asset) async {
    final db = await database;
    final stamped = asset.copyWith(
      updatedAt: DateTime.now(),
      lastModifiedAt: DateTime.now(),
    );

    return await db.update(
      'assets',
      stamped.toJson(),
      where: 'id = ?',
      whereArgs: [stamped.id],
    );
  }

  /// Delete an asset (solo users)
  Future<int> deleteAsset(String id) async {
    final db = await database;
    return await db.delete('assets', where: 'id = ?', whereArgs: [id]);
  }

  /// Delete all assets for a site (solo users)
  Future<int> deleteAllAssets() async {
    final db = await database;
    return await db.delete('assets');
  }

  /// Close database connection
  Future<void> close() async {
    final db = await database;
    await db.close();
  }
}
