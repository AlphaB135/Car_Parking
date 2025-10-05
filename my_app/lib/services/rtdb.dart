import 'package:firebase_database/firebase_database.dart';

/// Legacy helper updated to use the `current` schema where each spot has an
/// 'occupied' boolean (or possibly other types) and a 'since' timestamp.
class RTDB {
  static DatabaseReference get _root => FirebaseDatabase.instance.ref();

  /// Count of free spots computed from `current/<lotId>`.
  static Stream<int> freeCountStream(String lotId) {
    final ref = _root.child('current/$lotId');
    return ref.onValue.map((e) {
      final m = (e.snapshot.value as Map?) ?? {};
      int free = 0;
      m.forEach((k, v) {
        if (v is Map) {
          final occ = _normalizeOccupied(v['occupied']);
          if (!occ) free++;
        }
      });
      return free;
    });
  }

  /// Live map of spots for a lot: { "01": {...}, "02": {...}, ... }
  static Stream<Map<String, Map<String, dynamic>>> lotSpots(String lotId) {
    final ref = _root.child('current/$lotId');
    return ref.onValue.map((e) {
      final raw = (e.snapshot.value as Map?) ?? {};
      return raw.map((k, v) => MapEntry('$k', Map<String, dynamic>.from(v)));
    });
  }

  /// Toggle a spot occupied boolean using a transaction and server timestamp.
  static Future<void> toggleSpot(String lotId, String spotId) async {
    final ref = _root.child('current/$lotId/$spotId/occupied');
    final snap = await ref.get();
    final cur = _normalizeOccupied(snap.value);
    await ref.set(!cur);
  }

  static bool _normalizeOccupied(dynamic o) {
    if (o is bool) return o;
    if (o is num) return o != 0;
    if (o is String) {
      final s = o.toLowerCase().trim();
      return s == 'true' || s == '1';
    }
    return false;
  }
}
