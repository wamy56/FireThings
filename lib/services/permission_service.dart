import 'package:cloud_firestore/cloud_firestore.dart';
import 'auth_service.dart';

class PermissionService {
  final _firestore = FirebaseFirestore.instance;
  final _authService = AuthService();

  // Cache the result to avoid repeated Firestore reads
  bool? _hasPdfCertificatesAccess;

  Future<bool> hasPdfCertificatesAccess() async {
    // Return cached value if available
    if (_hasPdfCertificatesAccess != null) {
      return _hasPdfCertificatesAccess!;
    }

    final user = _authService.currentUser;
    if (user?.email == null) {
      _hasPdfCertificatesAccess = false;
      return false;
    }

    try {
      final doc = await _firestore
          .collection('app_config')
          .doc('pdf_certificates_access')
          .get();

      if (!doc.exists) {
        _hasPdfCertificatesAccess = false;
        return false;
      }

      final allowedEmails = List<String>.from(
        doc.data()?['allowed_emails'] ?? [],
      );
      _hasPdfCertificatesAccess = allowedEmails.contains(
        user!.email!.toLowerCase(),
      );
      return _hasPdfCertificatesAccess!;
    } catch (e) {
      // On error, default to no access
      _hasPdfCertificatesAccess = false;
      return false;
    }
  }

  // Clear cache on logout or user change
  void clearCache() {
    _hasPdfCertificatesAccess = null;
  }
}
