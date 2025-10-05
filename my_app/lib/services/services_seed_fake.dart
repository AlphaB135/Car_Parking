import 'dart:convert';
import 'package:flutter/services.dart' show rootBundle;
import '../fake_database.dart';

/// Load a JSON asset into the FakeDatabase root for local testing.
class FakeSeeder {
  static Future<void> seedFromAsset(String assetPath) async {
    final jsonStr = await rootBundle.loadString(assetPath);
    final data = json.decode(jsonStr);
    await FakeDatabaseReference('/').set(data);
  }
}
