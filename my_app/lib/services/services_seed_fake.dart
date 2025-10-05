import 'dart:convert';
import 'package:flutter/services.dart' show rootBundle;
import '../fake_database.dart';

/// Load a JSON asset into the FakeDatabase root for local testing.
class FakeSeeder {
  static Future<void> seedFromAsset(String assetPath) async {
    final jsonStr = await rootBundle.loadString(assetPath);
    final data = json.decode(jsonStr);
    // The app expects a schema with top-level: devices, lots, spots, lot_summaries
    // Some seeds (like RTDB export with `current`) contain a different shape.
    final Map<String, dynamic> seed = {};

    // Copy devices and lots if present
    if (data is Map && data.containsKey('devices'))
      seed['devices'] = data['devices'];
    if (data is Map && data.containsKey('lots')) seed['lots'] = data['lots'];

    // If the seed uses `current` -> convert to `spots` structure
    if (data is Map && data.containsKey('current')) {
      final current = data['current'] as Map;
      final spots = <String, dynamic>{};
      final lotSummaries = <String, dynamic>{};
      current.forEach((lotId, lotMap) {
        final spotMap = <String, dynamic>{};
        int total = 0;
        int occupied = 0;
        (lotMap as Map).forEach((spotId, info) {
          total++;
          final occupiedFlag = (info is Map && info['occupied'] == true);
          if (occupiedFlag) occupied++;
          spotMap['$spotId'] = {
            'occupied': occupiedFlag,
            'source': info is Map && info.containsKey('device')
                ? info['device']
                : null,
            'updated_at': info is Map && info.containsKey('since')
                ? info['since']
                : 0,
          };
        });
        spots[lotId] = spotMap;
        lotSummaries[lotId] = {
          'available': total - occupied,
          'occupied': occupied,
          'updated_at': DateTime.now().millisecondsSinceEpoch,
        };
      });
      seed['spots'] = spots;
      seed['lot_summaries'] = lotSummaries;
    }

    // Fallback: if original file already contains 'spots' or 'lot_summaries', merge
    if (data is Map && data.containsKey('spots')) seed['spots'] = data['spots'];
    if (data is Map && data.containsKey('lot_summaries'))
      seed['lot_summaries'] = data['lot_summaries'];

    await FakeDatabaseReference('/').set(seed);
  }
}
