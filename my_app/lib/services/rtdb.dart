import 'package:firebase_database/firebase_database.dart';

class RTDB {
  static DatabaseReference get _root => FirebaseDatabase.instance.ref();

  /// Count of free spots in a lot using the indexed field "status"
  static Stream<int> freeCountStream(String lotId) {
    final ref = _root.child('spots/$lotId');
    return ref.orderByChild('status').equalTo('free').onValue.map((e) {
      final m = (e.snapshot.value as Map?) ?? {};
      return m.length; // equalTo returns only matched children
    });
  }

  /// Live map of spots for a lot: { "01": {...}, "02": {...}, ... }
  static Stream<Map<String, Map<String, dynamic>>> lotSpots(String lotId) {
    final ref = _root.child('spots/$lotId');
    return ref.onValue.map((e) {
      final raw = (e.snapshot.value as Map?) ?? {};
      return raw.map((k, v) => MapEntry('$k', Map<String, dynamic>.from(v)));
    });
  }

  /// Toggle a spot status with a transaction; updates server timestamp.
  static Future<void> toggleSpot(String lotId, String spotId) async {
    final ref = _root.child('spots/$lotId/$spotId');
    await ref.runTransaction((current) {
      final m = Map<String, dynamic>.from((current as Map?) ?? {});
      final st = (m['status'] ?? 'free').toString();
      if (st == 'free') {
        m['status'] = 'occupied';
      } else {
        m['status'] = 'free';
        m.remove('vehicle');
      }
      m['updated_at'] = ServerValue.timestamp;
      return Transaction.success(m);
    });
  }
}
