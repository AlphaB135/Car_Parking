import 'dart:async';
import 'package:flutter/material.dart';
import '../widgets/bottom_navigation.dart';
import '../firebase_enabled.dart';
import '../services/services_rtdb.dart';

class ParkingDetailAScreen extends StatefulWidget {
  const ParkingDetailAScreen({super.key});

  @override
  _ParkingDetailAScreenState createState() => _ParkingDetailAScreenState();
}

class _ParkingDetailAScreenState extends State<ParkingDetailAScreen> {
  final String lotId = 'A';

  // Local mock fallback (10 spots)
  List<bool> parkingSpots = [
    false,
    true,
    false,
    true,
    false,
    false,
    true,
    true,
    false,
    false,
  ];

  StreamSubscription<Map<String, dynamic>>? _lotOverviewSub;
  String _lotName = 'ลาน A - อาคาร LC';
  String _lotLocation = 'ใกล้อาคาร LC';
  String _lotDescription = 'ลานจอดรถสำหรับอาจารย์และเจ้าหน้าที่คณะวิศวกรรม';
  int _totalSpotsLive = 10;
  int _availableLive = 6;
  int _occupiedLive = 4;
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
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // <CHANGE> Centered parking spots grid with improved styling
              Center(
                child: Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.06),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: firebaseEnabled
                      ? StreamBuilder<Map<String, Map<String, dynamic>>>(
                          stream: Rtdb().lotSpotsMap(lotId),
                          builder: (context, snapshot) {
                            final map =
                                snapshot.data ??
                                <String, Map<String, dynamic>>{};
                            if (snapshot.connectionState ==
                                    ConnectionState.waiting &&
                                map.isEmpty) {
                              return const Padding(
                                padding: EdgeInsets.all(24),
                                child: Center(
                                  child: CircularProgressIndicator(),
                                ),
                              );
                            }
                            return _buildSpotsGridFromMap(context, map);
                          },
                        )
                      : _buildSpotsGridFromMock(),
                ),
              ),
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

  // <CHANGE> Improved mock grid with better centering and spacing
  Widget _buildSpotsGridFromMock() {
    Widget spot(int i) {
      final occupied = parkingSpots[i];
      return GestureDetector(
        onTap: () => setState(() => parkingSpots[i] = !parkingSpots[i]),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
          child: _buildRealisticParkingSpot(i + 1, occupied, isTopRow: i < 5),
        ),
      );
    }

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List<Widget>.generate(5, (i) => spot(i)),
        ),
        const SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List<Widget>.generate(5, (i) => spot(i + 5)),
        ),
      ],
    );
  }

  // <CHANGE> Improved live grid with better centering and spacing
  Widget _buildSpotsGridFromMap(
    BuildContext context,
    Map<String, Map<String, dynamic>> map,
  ) {
    final items = List<Widget>.generate(10, (i) {
      final key = (i + 1).toString().padLeft(2, '0');
      final entry = map.containsKey(key)
          ? map[key]!
          : <String, dynamic>{'occupied': false};
      final occupied = Rtdb.normalizeOccupied(entry['occupied']);
      print(
        'A spot $key raw=${entry['occupied']} type=${entry['occupied']?.runtimeType} -> $occupied',
      );
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
              const SnackBar(content: Text('อัปเดตสถานะช่องจอดไม่สำเร็จ')),
            );
          }
        },
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
          child: _buildRealisticParkingSpot(i + 1, occupied, isTopRow: i < 5),
        ),
      );
    });

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: items.sublist(0, 5),
        ),
        const SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: items.sublist(5),
        ),
      ],
    );
  }

  // <CHANGE> Enhanced parking spot design with better shadows and borders
  Widget _buildRealisticParkingSpot(
    int number,
    bool isOccupied, {
    required bool isTopRow,
  }) {
    return SizedBox(
      width: 58,
      height: 85,
      child: Stack(
        children: [
          // Background
          Container(
            decoration: BoxDecoration(
              color: const Color(0xFFF8F8F8),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: Colors.grey[300]!, width: 1),
            ),
          ),
          // Left border
          Positioned(
            left: 3,
            top: isTopRow ? 0 : 10,
            bottom: isTopRow ? 10 : 0,
            child: Container(
              width: 3.5,
              decoration: BoxDecoration(
                color: const Color(0xFF424242),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          // Right border
          Positioned(
            right: 3,
            top: isTopRow ? 0 : 10,
            bottom: isTopRow ? 10 : 0,
            child: Container(
              width: 3.5,
              decoration: BoxDecoration(
                color: const Color(0xFF424242),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          // Top/Bottom border
          Positioned(
            left: 3,
            right: 3,
            top: isTopRow ? null : 0,
            bottom: isTopRow ? 0 : null,
            child: Container(
              height: 3.5,
              decoration: BoxDecoration(
                color: const Color(0xFF424242),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          // Car/Parking indicator
          if (isOccupied)
            Center(
              child: Container(
                width: 38,
                height: 55,
                decoration: BoxDecoration(
                  color: Colors.red[600],
                  borderRadius: BorderRadius.circular(10),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.red.withOpacity(0.3),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.directions_car,
                      color: Colors.white,
                      size: 24,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '$number',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 11,
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
                width: 38,
                height: 55,
                decoration: BoxDecoration(
                  color: Colors.green[600],
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.white, width: 2.5),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.green.withOpacity(0.3),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.local_parking,
                      color: Colors.white,
                      size: 24,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '$number',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 11,
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
