// services/rtdb.dart
import 'dart:async';
import 'package:firebase_database/firebase_database.dart' as fb;
import '../fake_database.dart';
import '../firebase_enabled.dart';

/// Thin wrapper that switches between Firebase RTDB and the in-memory Fake DB
/// based on [firebaseEnabled]. Matches the minimal schema:
/// devices, lot_summaries, lots, spots
class Rtdb {
  final fb.DatabaseReference? _fb;
  final FakeDatabaseReference? _fake;

  Rtdb()
    : _fb = firebaseEnabled ? fb.FirebaseDatabase.instance.ref() : null,
      _fake = firebaseEnabled ? null : FakeDatabaseReference('/');

  /// Stream of a single lot summary (available, occupied, updated_at)
  Stream<Map<String, dynamic>> lotSummary(String lotId) {
    if (_fb != null) {
      final fbRef = _fb;
      return fbRef
          .child('lot_summaries/$lotId')
          .onValue
          .map((e) => _castMap(e.snapshot.value));
    }
    final fakeRef = _fake!;
    return fakeRef
        .child('lot_summaries/$lotId')
        .onValue
        .map((e) => _castMap(e.snapshotValue));
  }

  /// Stream of all lot summaries as Map<lotId, Map>
  Stream<Map<String, dynamic>> allLotSummaries() {
    if (_fb != null) {
      final fbRef = _fb;
      return fbRef
          .child('lot_summaries')
          .onValue
          .map((e) => _castMap(e.snapshot.value));
    }
    final fakeRef = _fake!;
    return fakeRef
        .child('lot_summaries')
        .onValue
        .map((e) => _castMap(e.snapshotValue));
  }

  /// Stream of spot occupancy for a lot as ordered List<bool> (01..10)
  Stream<List<bool>> lotSpots(String lotId) {
    if (_fb != null) {
      final fbRef = _fb;
      return fbRef
          .child('spots/$lotId')
          .onValue
          .map((e) => _spotsMapToList(_castMap(e.snapshot.value)));
    }
    final fakeRef = _fake!;
    return fakeRef
        .child('spots/$lotId')
        .onValue
        .map((e) => _spotsMapToList(_castMap(e.snapshotValue)));
  }

  /// Stream the raw spots map for a lot as { "01": {...}, "02": {...} }
  Stream<Map<String, Map<String, dynamic>>> lotSpotsMap(String lotId) {
    if (_fb != null) {
      return fb.FirebaseDatabase.instance
          .ref()
          .child('spots/$lotId')
          .onValue
          .map((e) {
            final raw = (e.snapshot.value as Map?) ?? {};
            return raw.map(
              (k, v) => MapEntry('$k', Map<String, dynamic>.from(v)),
            );
          });
    }
    final FakeDatabaseReference fakeRef = _fake!;
    return fakeRef.child('spots/$lotId').onValue.map((e) {
      final raw = (e.snapshotValue as Map?) ?? {};
      return raw.map((k, v) => MapEntry('$k', Map<String, dynamic>.from(v)));
    });
  }

  /// Stream of metadata for a single lot (name, location, total_spots, etc.)
  Stream<Map<String, dynamic>> lotMetadata(String lotId) {
    if (_fb != null) {
      return fb.FirebaseDatabase.instance
          .ref()
          .child('lots/$lotId')
          .onValue
          .map((e) => _castMap(e.snapshot.value));
    }
    final FakeDatabaseReference fakeRef = _fake!;
    return fakeRef
        .child('lots/$lotId')
        .onValue
        .map((e) => _castMap(e.snapshotValue));
  }

  /// Stream of metadata for all lots keyed by lot id.
  Stream<Map<String, dynamic>> allLotsMetadata() {
    if (_fb != null) {
      return fb.FirebaseDatabase.instance
          .ref()
          .child('lots')
          .onValue
          .map((e) => _castMap(e.snapshot.value));
    }
    final FakeDatabaseReference fakeRef = _fake!;
    return fakeRef.child('lots').onValue.map((e) => _castMap(e.snapshotValue));
  }

  /// Combined stream with metadata and live summaries per lot.
  /// Each entry is keyed by lotId and exposes: id, name, location, total_spots, available, occupied, updated_at, metadata, summary.
  Stream<Map<String, dynamic>> lotOverview() {
    Map<String, dynamic> latestSummaries = <String, dynamic>{};
    Map<String, dynamic> latestLots = <String, dynamic>{};
    StreamSubscription<Map<String, dynamic>>? summariesSub;
    StreamSubscription<Map<String, dynamic>>? lotsSub;
    late StreamController<Map<String, dynamic>> controller;

    Map<String, dynamic> _combine() {
      final ids = <String>{
        ...latestSummaries.keys.map((e) => e.toString()),
        ...latestLots.keys.map((e) => e.toString()),
      };
      final result = <String, dynamic>{};
      for (final id in ids) {
        final metaRaw = latestLots[id];
        final meta = metaRaw is Map
            ? Map<String, dynamic>.from(metaRaw)
            : <String, dynamic>{};
        final summaryRaw = latestSummaries[id];
        final summary = summaryRaw is Map
            ? Map<String, dynamic>.from(summaryRaw)
            : <String, dynamic>{};
        final combined = <String, dynamic>{
          'id': id,
          'name': meta['name'],
          'location': meta['location'],
          'metadata': meta,
          'summary': summary,
        };
        final total =
            meta['total_spots'] ??
            (meta['sensors_map'] is Map
                ? (meta['sensors_map'] as Map).length
                : null);
        if (total != null) combined['total_spots'] = total;
        if (summary.containsKey('available'))
          combined['available'] = summary['available'];
        if (summary.containsKey('occupied'))
          combined['occupied'] = summary['occupied'];
        if (summary.containsKey('updated_at'))
          combined['updated_at'] = summary['updated_at'];
        result[id] = combined;
      }
      return result;
    }

    controller = StreamController<Map<String, dynamic>>.broadcast(
      onListen: () {
        summariesSub = allLotSummaries().listen((value) {
          latestSummaries = value;
          final combined = _combine();
          if (combined.isNotEmpty) controller.add(combined);
        });
        lotsSub = allLotsMetadata().listen((value) {
          latestLots = value;
          final combined = _combine();
          if (combined.isNotEmpty) controller.add(combined);
        });
      },
      onCancel: () async {
        await summariesSub?.cancel();
        await lotsSub?.cancel();
      },
    );
    return controller.stream;
  }

  /// Convenience helper for widgets that only need the metadata once.
  Future<Map<String, dynamic>> fetchLotsOnce() async {
    if (_fb != null) {
      final snap = await fb.FirebaseDatabase.instance.ref().child('lots').get();
      return _castMap(snap.value);
    }
    final snap = await _fake!.child('lots').get();
    return _castMap(snap);
  }

  /// For quick manual toggles in fake mode or admin UIs.
  Future<void> setSpotOccupied(
    String lotId,
    String spotId,
    bool occupied,
  ) async {
    final path = 'spots/$lotId/$spotId/occupied';
    if (_fb != null) {
      await fb.FirebaseDatabase.instance.ref().child(path).set(occupied);
    } else {
      final fakeRef = _fake!;
      await fakeRef.child(path).set(occupied);
      // also update lot_summaries for convenience in fake mode
      await _recomputeLotSummary(lotId);
    }
  }

  /// Compatibility: count of free spots (occupied==false)
  Stream<int> freeCountStream(String lotId) {
    return lotSpots(lotId).map((list) => list.where((b) => !b).length);
  }

  /// Compatibility: toggle spot (flip occupied) -- uses setSpotOccupied underneath
  Future<void> toggleSpot(String lotId, String spotId) async {
    // read current value
    if (_fb != null) {
      final snap = await fb.FirebaseDatabase.instance
          .ref()
          .child('spots/$lotId/$spotId/occupied')
          .get();
      final cur = snap.value as bool? ?? false;
      await fb.FirebaseDatabase.instance
          .ref()
          .child('spots/$lotId/$spotId/occupied')
          .set(!cur);
    } else {
      final fake = _fake!;
      final cur =
          (await fake.child('spots/$lotId/$spotId/occupied').get()) as bool? ??
          false;
      await fake.child('spots/$lotId/$spotId/occupied').set(!cur);
      await _recomputeLotSummary(lotId);
    }
  }

  // --- helpers ---

  static Map<String, dynamic> _castMap(dynamic v) {
    if (v == null) return <String, dynamic>{};
    return Map<String, dynamic>.from(v as Map);
  }

  static List<bool> _spotsMapToList(Map<String, dynamic> m) {
    // Expect keys '01'..'10'
    final keys = m.keys.toList()..sort((a, b) => int.parse(a) - int.parse(b));
    return keys
        .map((k) {
          final entry = Map<String, dynamic>.from(m[k] as Map);
          return (entry['occupied'] as bool?) ?? false;
        })
        .toList(growable: false);
  }

  Future<void> _recomputeLotSummary(String lotId) async {
    if (_fake == null) return;
    final snap = await _fake.child('spots/$lotId').get();
    final m = _castMap(snap);
    final list = _spotsMapToList(m);
    final total = list.length;
    final occupied = list.where((e) => e).length;
    final available = total - occupied;
    await _fake.child('lot_summaries/$lotId').set({
      'available': available,
      'occupied': occupied,
      'updated_at': DateTime.now().millisecondsSinceEpoch,
    });
  }
}
