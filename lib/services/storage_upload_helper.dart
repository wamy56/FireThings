/// Shared Firebase Storage upload helper.
///
/// On Flutter web, `firebase_storage_web`'s `putData()` silently fails — no
/// network request, no error, no console output. This is a known bug in the
/// FlutterFire Storage web implementation (see flutterfire issues #11872,
/// #12628; firebase-js-sdk #4451). `getDownloadURL()` has the same issue.
///
/// This helper routes web uploads through the Firebase Storage REST API,
/// bypassing the broken Dart SDK entirely. Mobile/desktop use the SDK
/// normally.
///
/// TODO: Delete the kIsWeb branch when firebase_storage_web fixes putData.
library;

import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:http/http.dart' as http;

class StorageUploadHelper {
  StorageUploadHelper._();

  static final _storage = FirebaseStorage.instance;

  static Future<String> upload(
    String path,
    Uint8List bytes,
    String contentType,
  ) async {
    if (kIsWeb) {
      return _uploadViaRestApi(path, bytes, contentType);
    }
    final ref = _storage.ref(path);
    await ref.putData(bytes, SettableMetadata(contentType: contentType));
    return await ref.getDownloadURL();
  }

  static Future<String> _uploadViaRestApi(
    String path,
    Uint8List bytes,
    String contentType,
  ) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) throw Exception('Not signed in');

    final idToken = await user.getIdToken();
    final bucket = _storage.bucket;
    final encodedPath = Uri.encodeComponent(path);

    final uri = Uri.parse(
      'https://firebasestorage.googleapis.com/v0/b/$bucket/o?uploadType=media&name=$encodedPath',
    );

    final response = await http.post(
      uri,
      headers: {
        'Authorization': 'Bearer $idToken',
        'Content-Type': contentType,
      },
      body: bytes,
    ).timeout(const Duration(seconds: 30));

    if (response.statusCode != 200) {
      throw Exception('Upload failed (${response.statusCode})');
    }

    // Parse download token from REST response and build URL directly —
    // getDownloadURL() has the same web SDK bug.
    final metadata = jsonDecode(response.body) as Map<String, dynamic>;
    final token = metadata['downloadTokens'] as String?;
    if (token == null) {
      throw Exception('Upload succeeded but no download token in response');
    }
    return 'https://firebasestorage.googleapis.com/v0/b/$bucket/o/$encodedPath?alt=media&token=$token';
  }
}
