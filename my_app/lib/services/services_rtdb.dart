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
  /// NOTE: summaries are now computed from `current/<lotId>` only.
  Stream<Map<String, dynamic>> lotSummary(String lotId) {
    if (_fb != null) {
      return fb.FirebaseDatabase.instance
          .ref()
          .child('current/$lotId')
          .onValue
          .map((e) {
            final raw = (e.snapshot.value as Map?) ?? {};
            final counts = computeLotCountsFromMap(raw);
            return {
              'available': counts.free,
              'occupied': counts.occupied,
              'total_spots': counts.total,
              'updated_at': DateTime.now().millisecondsSinceEpoch,
            };
          });
    }
    final FakeDatabaseReference fakeRef = _fake!;
    return fakeRef.child('current/$lotId').onValue.map((e) {
      final raw = (e.snapshotValue as Map?) ?? {};
      final counts = computeLotCountsFromMap(raw);
      return {
        'available': counts.free,
        'occupied': counts.occupied,
        'total_spots': counts.total,
        'updated_at': DateTime.now().millisecondsSinceEpoch,
      };
    });
  }

  /// Stream of all lot summaries computed from `current` root.
  Stream<Map<String, dynamic>> allLotSummaries() {
    if (_fb != null) {
      return fb.FirebaseDatabase.instance
          .ref()
          .child('current')
          .onValue
          .map((e) {
            final raw = (e.snapshot.value as Map?) ?? {};
            final out = <String, dynamic>{};
            (raw as Map).forEach((lotId, lotMap) {
              final counts = computeLotCountsFromMap(lotMap as Map?);
              out['$lotId'] = {
                'available': counts.free,
                'occupied': counts.occupied,
                'total_spots': counts.total,
                'updated_at': DateTime.now().millisecondsSinceEpoch,
              };
            });
            return out;
          });
    }
    final FakeDatabaseReference fakeRef = _fake!;
    return fakeRef.child('current').onValue.map((e) {
      final raw = (e.snapshotValue as Map?) ?? {};
      final out = <String, dynamic>{};
      (raw as Map).forEach((lotId, lotMap) {
        final counts = computeLotCountsFromMap(lotMap as Map?);
        out['$lotId'] = {
          'available': counts.free,
          'occupied': counts.occupied,
          'total_spots': counts.total,
          'updated_at': DateTime.now().millisecondsSinceEpoch,
        };
      });
      return out;
    });
  }

  /// Stream of spot occupancy for a lot as ordered List<bool> (01..10)
  /// Now reads from `current/<lotId>` and normalizes occupied values.
  Stream<List<bool>> lotSpots(String lotId) {
    return lotSpotsMap(lotId).map((m) => _spotsMapToList(m));
  }

  /// Stream the raw spot map for a lot as { "01": {...}, "02": {...} }
  /// Reads from `current/<lotId>` so UI and summaries use the same source.
  Stream<Map<String, Map<String, dynamic>>> lotSpotsMap(String lotId) {
    if (_fb != null) {
      return fb.FirebaseDatabase.instance
          .ref()
          .child('current/$lotId')
          .onValue
          .map((e) {
            final raw = (e.snapshot.value as Map?) ?? {};
            return raw.map(
              (k, v) => MapEntry('$k', Map<String, dynamic>.from(v)),
            );
          });
    }
    final FakeDatabaseReference fakeRef = _fake!;
    return fakeRef.child('current/$lotId').onValue.map((e) {
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
    final path = 'current/$lotId/$spotId/occupied';
    if (_fb != null) {
      await fb.FirebaseDatabase.instance.ref().child(path).set(occupied);
    } else {
      final fakeRef = _fake!;
      await fakeRef.child(path).set(occupied);
      // summaries are computed from `current` live; no local recompute needed
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
          .child('current/$lotId/$spotId/occupied')
          .get();
      final cur = normalizeOccupied(snap.value);
      await fb.FirebaseDatabase.instance
          .ref()
          .child('current/$lotId/$spotId/occupied')
          .set(!cur);
    } else {
      final fake = _fake!;
      final curRaw = await fake.child('current/$lotId/$spotId/occupied').get();
      final cur = normalizeOccupied(curRaw);
      await fake.child('current/$lotId/$spotId/occupied').set(!cur);
    }
  }

  // --- helpers ---

  static Map<String, dynamic> _castMap(dynamic v) {
    if (v == null) return <String, dynamic>{};
    return Map<String, dynamic>.from(v as Map);
  }

  /// Normalize various occupied value types into a boolean.
  /// Accepts bool, num (1/0), or strings like 'true'/'false' (case-insensitive) or '1'/ '0'.
  static bool normalizeOccupied(dynamic o) {
    // debug log for runtime type and raw value
    // (temporary) prints will help track inconsistent types from RTDB
    // ignore: avoid_print
    print('normalizeOccupied raw=$o type=${o?.runtimeType}');
    if (o is bool) return o;
    if (o is num) return o != 0;
    if (o is String) {
      final s = o.toLowerCase().trim();
      return s == 'true' || s == '1';
    }
    return false;
  }

  static List<bool> _spotsMapToList(Map<String, dynamic> m) {
    // Expect keys '01'..'10'
    final keys = m.keys.toList()
      ..sort((a, b) {
        final ai = int.tryParse(a.toString()) ?? 0;
        final bi = int.tryParse(b.toString()) ?? 0;
        return ai - bi;
      });
    return keys
        .map((k) {
          final entry = Map<String, dynamic>.from(m[k] as Map);
          return normalizeOccupied(entry['occupied']);
        })
        .toList(growable: false);
  }

  /// Compute counts (total, occupied, free) from a raw `current/<lot>` map.
  /// Only counts keys that look like spot ids (two-digit strings like '01').
  static LotCounts computeLotCountsFromMap(Map? raw) {
    final m = raw ?? <dynamic, dynamic>{};
    int total = 0, occ = 0;
    m.forEach((k, v) {
      // accept keys like '01', '02', ..., '10' (two characters, numeric)
      if (k is String && k.length == 2 && int.tryParse(k) != null && v is Map) {
        final isOcc = normalizeOccupied(v['occupied']);
        // temporary debug print to aid diagnosis
        // ignore: avoid_print
        print('spot $k occupied=${v['occupied']} (${v['occupied']?.runtimeType}) -> $isOcc');
        occ += isOcc ? 1 : 0;
        total++;
      }
    });
    return LotCounts(total, occ, total - occ);
  }

}

/// Simple value object for lot counts.
class LotCounts {
  final int total, occupied, free;
  const LotCounts(this.total, this.occupied, this.free);
}
