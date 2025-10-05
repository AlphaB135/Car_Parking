import 'dart:async';
import 'package:flutter/material.dart';
import '../widgets/bottom_navigation.dart';
import '../firebase_enabled.dart';
import '../services/services_rtdb.dart';

class ParkingDetailBScreen extends StatefulWidget {
  const ParkingDetailBScreen({super.key});

  @override
  _ParkingDetailBScreenState createState() => _ParkingDetailBScreenState();
}

class _ParkingDetailBScreenState extends State<ParkingDetailBScreen> {
  final String lotId = 'B';

  // Local mock fallback (10 spots)
  List<bool> parkingSpots = [
    true,
    true,
    true,
    true,
    true,
    true,
    true,
    true,
    false,
    false,
  ];

  StreamSubscription<Map<String, dynamic>>? _lotOverviewSub;
  String _lotName = 'ลาน B - อาคารวิทยาศาสตร์';
  String _lotLocation = 'ใกล้อาคารวิทยาศาสตร์';
  String _lotDescription = 'ลานจอดรถสำหรับนักศึกษาและบุคลากร';
  int _totalSpotsLive = 10;
  int _availableLive = 2;
  int _occupiedLive = 8;
  int? _lastUpdated;

  @override
  void initState() {
    super.initState();
    _lotOverviewSub = Rtdb().lotOverview().listen((data) {
      final raw = data[lotId] as Map?;
      if (raw == null) return;
      final meta = raw['metadata'] is Map
          ? Map<String, dynamic>.from(raw['metadata'] as Map)
          : <String, dynamic>{};
      final summary = raw['summary'] is Map
          ? Map<String, dynamic>.from(raw['summary'] as Map)
          : <String, dynamic>{};

      final name = (raw['name'] ?? meta['name'])?.toString();
      final location = (raw['location'] ?? meta['location'])?.toString();
      final description = meta['description']?.toString() ?? _lotDescription;
      final total = _asInt(
        raw['total_spots'] ?? meta['total_spots'],
        parkingSpots.length,
      );
      final sensorsCount = meta['sensors_map'] is Map
          ? (meta['sensors_map'] as Map).length
          : parkingSpots.length;
      final available = _asInt(
        raw['available'] ?? summary['available'],
        sensorsCount - _occupiedLive,
      );
      // occupied computed from total/available when present
      final updatedAt = summary['updated_at'] ?? raw['updated_at'];

      if (!mounted) return;
      setState(() {
        if (name != null && name.isNotEmpty) _lotName = name;
        if (location != null && location.isNotEmpty) _lotLocation = location;
        _lotDescription = description;
        _totalSpotsLive = total;
        final safeAvailable = available.clamp(0, total);
        _availableLive = safeAvailable;
        _occupiedLive = total - safeAvailable;
        if (updatedAt is int) _lastUpdated = updatedAt;
      });
    });
  }

  @override
  void dispose() {
    _lotOverviewSub?.cancel();
    super.dispose();
  }

  int _asInt(dynamic value, [int fallback = 0]) {
    if (value == null) return fallback;
    if (value is int) return value;
    if (value is double) return value.round();
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value) ?? fallback;
    return fallback;
  }

  String? get _lastUpdatedLabel =>
      _lastUpdated == null ? null : _formatUpdatedAt(_lastUpdated!);

  String _formatUpdatedAt(int millis) {
    final dt = DateTime.fromMillisecondsSinceEpoch(millis).toLocal();
    String two(int v) => v.toString().padLeft(2, '0');
    return '${dt.day}/${dt.month}/${dt.year} ${two(dt.hour)}:${two(dt.minute)}:${two(dt.second)}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFE8F0FE),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'รายละเอียดลานจอด',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.black,
              ),
            ),
            Text(
              'ข้อมูลลานจอดแบบเรียลไทม์',
              style: TextStyle(fontSize: 12, color: Colors.grey[600]),
            ),
          ],
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: SingleChildScrollView(
          child: Column(
            children: [
              // Info card
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.04),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          _lotName,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.black,
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFFE3F2FD),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: const [
                              Icon(
                                Icons.refresh,
                                size: 16,
                                color: Color(0xFF4285F4),
                              ),
                              SizedBox(width: 4),
                              Text(
                                'ข้อมูลสด',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Color(0xFF4285F4),
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Icon(
                          Icons.location_on,
                          size: 16,
                          color: Colors.grey[500],
                        ),
                        const SizedBox(width: 4),
                        Text(
                          _lotLocation,
                          style: const TextStyle(
                            fontSize: 14,
                            color: Colors.black54,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    Row(
                      children: [
                        _buildLegendItem('ว่าง', Colors.green),
                        const SizedBox(width: 24),
                        _buildLegendItem('ไม่ว่าง', Colors.red),
                      ],
                    ),
                    const SizedBox(height: 16),
                    _buildLiveStatsRow(),
                    if (_lastUpdatedLabel != null) ...[
                      const SizedBox(height: 8),
                      Text(
                        'อัปเดตล่าสุด $_lastUpdatedLabel',
                        style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                      ),
                    ],
                    // 'ข้อมูลเพิ่มเติม' section removed per request
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Spots grid: live when firebaseEnabled, otherwise local mock
              firebaseEnabled
                  ? StreamBuilder<Map<String, Map<String, dynamic>>>(
                      stream: Rtdb().lotSpotsMap(lotId),
                      builder: (context, snapshot) {
                        final map =
                            snapshot.data ?? <String, Map<String, dynamic>>{};
                        // show loader while waiting for first data
                        if (snapshot.connectionState ==
                                ConnectionState.waiting &&
                            map.isEmpty) {
                          return const Padding(
                            padding: EdgeInsets.all(24),
                            child: Center(child: CircularProgressIndicator()),
                          );
                        }
                        return _buildSpotsGridFromMap(context, map);
                      },
                    )
                  : _buildSpotsGridFromMock(),
            ],
          ),
        ),
      ),
      bottomNavigationBar: const BottomNavigation(currentIndex: 1),
    );
  }

  Widget _buildLiveStatsRow() {
    final total = _totalSpotsLive;
    final available = _availableLive.clamp(0, total);
    final occupied = _occupiedLive.clamp(0, total);
    return Row(
      children: [
        _buildStatChip('$total', 'ทั้งหมด', const Color(0xFF1E88E5)),
        const SizedBox(width: 12),
        _buildStatChip('$available', 'ที่ว่าง', const Color(0xFF059669)),
        const SizedBox(width: 12),
        _buildStatChip('$occupied', 'ไม่ว่าง', const Color(0xFFDC2626)),
      ],
    );
  }

  Widget _buildStatChip(String value, String label, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: color.withOpacity(0.12),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          children: [
            Text(
              value,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(fontSize: 12, color: color.withOpacity(0.8)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSpotsGridFromMock() {
    Widget spot(int i) {
      final occupied = parkingSpots[i];
      return GestureDetector(
        onTap: () => setState(() => parkingSpots[i] = !parkingSpots[i]),
        child: Padding(
          padding: const EdgeInsets.all(6),
          child: _buildRealisticParkingSpot(i + 1, occupied, isTopRow: i < 5),
        ),
      );
    }

    final firstRow = Row(children: List<Widget>.generate(5, (i) => spot(i)));
    final secondRow = Row(
      children: List<Widget>.generate(5, (i) => spot(i + 5)),
    );
    return Column(children: [firstRow, const SizedBox(height: 8), secondRow]);
  }

  // ...existing code...

  // kept for compatibility; spot rendering now uses grid builders when live

  Widget _buildSpotsGridFromMap(
    BuildContext context,
    Map<String, Map<String, dynamic>> map,
  ) {
    final items = List<Widget>.generate(10, (i) {
      final key = (i + 1).toString().padLeft(2, '0');
      final entry = map.containsKey(key)
          ? map[key]!
          : <String, dynamic>{'occupied': false};
      final occupied = (entry['occupied'] as bool?) ?? false;
      final spotId = key;
      return GestureDetector(
        onTap: () async {
          if (!firebaseEnabled) {
            setState(() {});
            return;
          }
          try {
            await Rtdb().toggleSpot(lotId, spotId);
          } catch (e) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text(
                  '\u0e2d\u0e31\u0e1b\u0e40\u0e14\u0e15\u0e2a\u0e16\u0e32\u0e19\u0e30\u0e0a\u0e48\u0e2d\u0e07\u0e08\u0e2d\u0e14\u0e44\u0e21\u0e48\u0e2a\u0e33',
                ),
              ),
            );
          }
        },
        child: Padding(
          padding: const EdgeInsets.all(6),
          child: _buildRealisticParkingSpot(i + 1, occupied, isTopRow: i < 5),
        ),
      );
    });
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(children: items.sublist(0, 5)),
        const SizedBox(height: 8),
        Row(children: items.sublist(5)),
      ],
    );
  }

  Widget _buildRealisticParkingSpot(
    int number,
    bool isOccupied, {
    required bool isTopRow,
  }) {
    return SizedBox(
      width: 55,
      height: 80,
      child: Stack(
        children: [
          Container(
            decoration: BoxDecoration(
              color: const Color(0xFFF5F5F5),
              borderRadius: BorderRadius.circular(4),
            ),
          ),
          Positioned(
            left: 2,
            top: isTopRow ? 0 : 8,
            bottom: isTopRow ? 8 : 0,
            child: Container(
              width: 3,
              decoration: BoxDecoration(
                color: const Color(0xFF333333),
                borderRadius: BorderRadius.circular(1.5),
              ),
            ),
          ),
          Positioned(
            right: 2,
            top: isTopRow ? 0 : 8,
            bottom: isTopRow ? 8 : 0,
            child: Container(
              width: 3,
              decoration: BoxDecoration(
                color: const Color(0xFF333333),
                borderRadius: BorderRadius.circular(1.5),
              ),
            ),
          ),
          Positioned(
            left: 2,
            right: 2,
            top: isTopRow ? null : 0,
            bottom: isTopRow ? 0 : null,
            child: Container(
              height: 3,
              decoration: BoxDecoration(
                color: const Color(0xFF333333),
                borderRadius: BorderRadius.circular(1.5),
              ),
            ),
          ),
          if (isOccupied)
            Center(
              child: Container(
                width: 35,
                height: 50,
                decoration: BoxDecoration(
                  color: Colors.red[700],
                  borderRadius: BorderRadius.circular(8),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.12),
                      blurRadius: 3,
                      offset: const Offset(0, 1),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.directions_car,
                      color: Colors.white,
                      size: 20,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '$number',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          if (!isOccupied)
            Center(
              child: Container(
                width: 35,
                height: 50,
                decoration: BoxDecoration(
                  color: Colors.green[600],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.white, width: 2),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.04),
                      blurRadius: 4,
                      offset: const Offset(0, 1),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.local_parking,
                      color: Colors.white,
                      size: 20,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '$number',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildLegendItem(String label, Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Text(label, style: const TextStyle(fontSize: 14, color: Colors.black)),
      ],
    );
  }
}
