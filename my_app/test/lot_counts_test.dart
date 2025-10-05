import 'package:flutter_test/flutter_test.dart';
import 'package:my_app/services/services_rtdb.dart';

void main() {
  test('computeLotCountsFromMap handles mixed occupied types', () {
    final raw = {
      '01': {'occupied': true},
      '02': {'occupied': 'true'},
      '03': {'occupied': '1'},
      '04': {'occupied': 1},
      '05': {'occupied': false},
      '06': {'occupied': 'false'},
      '07': {'occupied': 0},
      '08': {'occupied': '0'},
      '09': {'occupied': null},
      '10': {'occupied': 'TrUe'},
    };

    final counts = Rtdb.computeLotCountsFromMap(raw);
    expect(counts.total, 10);
    expect(counts.occupied, 5); // 01,02,03,04,10 are truthy
    expect(counts.free, 5);
  });
}
