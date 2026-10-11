import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Exposes the configured Firestore instance with offline persistence.
final firestoreProvider = Provider<FirebaseFirestore>((ref) {
  final db = FirebaseFirestore.instance;

  // Enable offline persistence (cache size: 100 MB)
  db.settings = const Settings(
    persistenceEnabled: true,
    cacheSizeBytes: Settings.CACHE_SIZE_UNLIMITED,
  );

  return db;
});
