import '../models/models.dart';
import 'database_helper.dart';
import 'auth_service.dart';
import 'package:uuid/uuid.dart';

/// High-level service for jobsheet operations
class JobsheetService {
  final DatabaseHelper _db = DatabaseHelper.instance;
  final AuthService _auth = AuthService();

  /// Create a new jobsheet with current user info
  Future<Jobsheet> createJobsheet({
    required String customerName,
    required String siteAddress,
    required String jobNumber,
    required String systemCategory,
    required String templateType,
    required Map<String, dynamic> formData,
    String notes = '',
    List<String> defects = const [],
  }) async {
    final user = _auth.currentUser;
    if (user == null) {
      throw Exception('User not logged in');
    }

    final jobsheet = Jobsheet(
      id: const Uuid().v4(),
      engineerId: user.uid,
      engineerName: user.displayName ?? user.email!,
      date: DateTime.now(),
      customerName: customerName,
      siteAddress: siteAddress,
      jobNumber: jobNumber,
      systemCategory: systemCategory,
      templateType: templateType,
      formData: formData,
      notes: notes,
      defects: defects,
      createdAt: DateTime.now(),
    );

    return await _db.insertJobsheet(jobsheet);
  }

  /// Get all jobsheets for current user
  Future<List<Jobsheet>> getMyJobsheets() async {
    final user = _auth.currentUser;
    if (user == null) return [];

    return await _db.getJobsheetsByEngineerId(user.uid);
  }

  /// Get jobsheet count for current user
  Future<int> getMyJobsheetsCount() async {
    final jobsheets = await getMyJobsheets();
    return jobsheets.length;
  }

  /// Add signatures to a jobsheet
  Future<Jobsheet> addSignatures({
    required String jobsheetId,
    required String engineerSignature,
    required String customerSignature,
    required String customerSignatureName,
  }) async {
    final jobsheet = await _db.getJobsheetById(jobsheetId);
    if (jobsheet == null) {
      throw Exception('Jobsheet not found');
    }

    final updated = jobsheet.copyWith(
      engineerSignature: engineerSignature,
      customerSignature: customerSignature,
      customerSignatureName: customerSignatureName,
    );

    await _db.updateJobsheet(updated);
    return updated;
  }

  /// Search current user's jobsheets
  Future<List<Jobsheet>> searchMyJobsheets(String query) async {
    final allResults = await _db.searchJobsheets(query);
    final user = _auth.currentUser;

    if (user == null) return [];

    // Filter to only current user's jobsheets
    return allResults.where((j) => j.engineerId == user.uid).toList();
  }
}
