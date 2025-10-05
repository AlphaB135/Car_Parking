import 'dart:async';
import 'package:flutter/material.dart';
import '../widgets/bottom_navigation.dart';
import 'package:firebase_database/firebase_database.dart';
import '../firebase_enabled.dart';
import '../fake_database.dart';
import '../services/services_rtdb.dart';
import '../services/services_seed_fake.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  _HomeScreenState createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final int _currentIndex = 0;

  @override
  void initState() {
    super.initState();
    _lots = List<_Lot>.from(_seedLots);
    if (firebaseEnabled) {
      _db?.child('test_connection').set({
        'status': 'ok',
        'ts': ServerValue.timestamp,
      });
      _writeTestConnection();
    } else {
      _fakeDb.child('test_connection').set({
        'status': 'ok',
        'ts': DateTime.now().millisecondsSinceEpoch,
      });
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('โหมดจำลอง: ใช้ฐานข้อมูลจำลองแทน Firebase'),
          ),
        );
      });
    }
    _lotOverviewSub = Rtdb().lotOverview().listen(
      _onLotOverview,
      onError: (error, stack) {
        print('[HomeScreen] lotOverview error: $error');
      },
    );
  }

  @override
  void dispose() {
    _lotOverviewSub?.cancel();
    super.dispose();
  }

  Future<void> _writeTestConnection() async {
    final db = _db;
    if (!firebaseEnabled || db == null) return;
    try {
      print(
        '[RTDB] Writing test_connection {status: ok, ts: ServerValue.timestamp}',
      );
      await db.child('test_connection').update({
        'status': 'ok',
        'ts': ServerValue.timestamp,
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Firebase: write successful')),
      );
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Firebase write failed: $e')));
    }
  }

  // อ้างอิง Realtime Database จริงเมื่อเปิด Firebase
  final DatabaseReference? _db = firebaseEnabled
      ? FirebaseDatabase.instance.ref()
      : null;
  // fallback fake ref for UI when Firebase disabled
  final FakeDatabaseReference _fakeDb = FakeDatabaseReference();

  StreamSubscription<Map<String, dynamic>>? _lotOverviewSub;
  late List<_Lot> _lots;

  static const List<_Lot> _seedLots = [
    _Lot(
      id: 'A',
      title: 'ลานจอด A - อาคาร LC',
      location: 'อาคารเรียน LC',
      capacity: 10,
      occupied: 4,
      available: 6,
      routeName: '/parkingA',
    ),
    _Lot(
      id: 'B',
      title: 'ลานจอด B - อาคารวิศวกรรม',
      location: 'หน้าอาคารวิศวกรรม',
      capacity: 10,
      occupied: 8,
      available: 2,
      routeName: '/parkingB',
    ),
    _Lot(
      id: 'C',
      title: 'ลานจอด C - ศูนย์กีฬา',
      location: 'หน้าศูนย์กีฬา',
      capacity: 10,
      occupied: 10,
      available: 0,
      routeName: '/parkingC',
    ),
  ];

  // Simple widget that listens to the test_connection node and shows status
  Widget _firebaseStatusBanner() {
    // If Firebase was not initialized, show a mock-mode banner
    if (!firebaseEnabled || _db == null) {
      return Container(
        width: double.infinity,
        color: Colors.orange.withOpacity(0.06),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Row(
          children: const [
            Icon(Icons.storage, color: Colors.orange),
            SizedBox(width: 8),
            Text(
              'Firebase: Mock mode (FakeDatabase)',
              style: TextStyle(color: Colors.orange),
            ),
          ],
        ),
      );
    }

    // Real Firebase: subscribe to /test_connection and display last value
    return StreamBuilder<DatabaseEvent>(
      stream: _db.child('test_connection').onValue,
      builder: (context, snapshot) {
        final raw = snapshot.data;
        final val = raw?.snapshot.value as Map<dynamic, dynamic>?;
        final connected = val != null && val['status'] == 'ok';
        final color = connected ? Colors.green : Colors.red;

        return Container(
          width: double.infinity,
          color: color.withOpacity(0.06),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(
            children: [
              Icon(
                connected ? Icons.cloud_done : Icons.cloud_off,
                color: color,
              ),
              const SizedBox(width: 8),
              Text(
                'Firebase: ${connected ? 'Connected (RTDB)' : 'Connected - no data'}',
                style: TextStyle(color: color),
              ),
              const Spacer(),
              if (val != null && val['ts'] != null)
                Text(
                  'ts: ${val['ts']}',
                  style: TextStyle(color: color, fontSize: 12),
                ),
            ],
          ),
        );
      },
    );
  }

  void _onLotOverview(Map<String, dynamic> data) {
    if (!mounted) return;
    if (data.isEmpty) {
      setState(() {
        _lots = List<_Lot>.from(_seedLots);
      });
      return;
    }

    final updated = data.entries.map((entry) {
      final raw = entry.value;
      final map = raw is Map
          ? Map<String, dynamic>.from(raw as Map)
          : <String, dynamic>{};
      final meta = map['metadata'] is Map
          ? Map<String, dynamic>.from(map['metadata'] as Map)
          : <String, dynamic>{};
      final summary = map['summary'] is Map
          ? Map<String, dynamic>.from(map['summary'] as Map)
          : <String, dynamic>{};

      final id = entry.key.toString();
      final name = (map['name'] ?? meta['name'] ?? 'ลานจอด $id').toString();
      final location =
          (map['location'] ?? meta['location'] ?? '').toString();

      final totalFromMeta =
          _asInt(map['total_spots'] ?? meta['total_spots'], 0);
      final sensorsCount = meta['sensors_map'] is Map
          ? (meta['sensors_map'] as Map).length
          : 0;
      final occupied = _asInt(map['occupied'] ?? summary['occupied'], 0);
      final availableGuess = sensorsCount != 0
          ? sensorsCount - occupied
          : _asInt(summary['available'], 0);
      final available =
          _asInt(map['available'] ?? summary['available'], availableGuess);

      final provisionalTotal = totalFromMeta != 0
          ? totalFromMeta
          : (sensorsCount != 0 ? sensorsCount : occupied + available);

      final total = provisionalTotal < 0 ? 0 : provisionalTotal;
      final safeAvailable = available < 0
          ? 0
          : (available > total ? total : available);
      final computedOccupied = total - safeAvailable;
      final updatedAtRaw =
          _asInt(map['updated_at'] ?? summary['updated_at'], 0);
      final updatedAt = updatedAtRaw == 0 ? null : updatedAtRaw;
      final route = (map['route'] ?? '/parking$id').toString();

      return _Lot(
        id: id,
        title: name,
        location: location,
        capacity: total,
        occupied: computedOccupied,
        available: safeAvailable,
        updatedAt: updatedAt,
        routeName: route,
      );
    }).toList()
      ..sort((a, b) => a.id.compareTo(b.id));

    setState(() {
      _lots = updated;
    });
  }

  int _asInt(dynamic value, [int fallback = 0]) {
    if (value == null) return fallback;
    if (value is int) return value;
    if (value is double) return value.round();
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value) ?? fallback;
    return fallback;
  }

  @override
  Widget build(BuildContext context) {
    // === สถิติโดยรวมของลานจอด ===
    final int totalLots = _lots.length;
    final int totalOccupied = _lots.fold(0, (sum, l) => sum + l.occupied);
    final int totalFree = _lots.fold(0, (sum, l) => sum + l.available);

    return Scaffold(
      backgroundColor: const Color(0xFFE8F0FE),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: const BoxDecoration(
                color: Color(0xFF4285F4),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.person, color: Colors.white, size: 20),
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'ระบบจอดรถอัจฉริยะ',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.black,
                  ),
                ),
                Text(
                  'ติดตามสถานะที่จอดแบบเรียลไทม์',
                  style: TextStyle(fontSize: 12, color: Colors.grey),
                ),
              ],
            ),
          ],
        ),
        actions: [
          Stack(
            children: [
              IconButton(
                icon: const Icon(
                  Icons.notifications_outlined,
                  color: Colors.black,
                ),
                onPressed: () {},
              ),
              Positioned(
                right: 8,
                top: 8,
                child: Container(
                  width: 8,
                  height: 8,
                  decoration: const BoxDecoration(
                    color: Colors.red,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
      // ปุ่มสำหรับรีเฟรชข้อมูลหรือส่งคำสั่ง seed ไปยังฐานข้อมูล
      floatingActionButton: FloatingActionButton(
        onPressed: _seedAgain,
        child: const Icon(Icons.cloud_upload),
      ),

      body: Column(
        children: [
          // แสดงสถานะการเชื่อมต่อ Firebase (Realtime Database)
          _firebaseStatusBanner(),

          // เนื้อหาหลักของแดชบอร์ดที่แสดงสถิติและรายการลานจอด
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Row(
                  children: [
                    Expanded(
                      child: _buildStatCard(
                        'ที่จอดว่างทั้งหมด',
                        '$totalFree',
                        Colors.green,
                        Icons.trending_up,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildStatCard(
                        'ที่ถูกใช้งาน',
                        '$totalOccupied',
                        const Color(0xFF4285F4),
                        Icons.location_on,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: _buildStatCard(
                        'จำนวนลานจอด',
                        '$totalLots',
                        Colors.orange,
                        Icons.location_on,
                        onTap: () {
                          Navigator.pushNamed(context, '/parking-selection');
                        },
                      ),
                    ),
                    const SizedBox(width: 12),
                    const Expanded(child: SizedBox()),
                  ],
                ),
                const SizedBox(height: 24),

                // เธฅเธฒเธเธเธญเธ”เธฃเธ– (live summaries)
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.1),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'สรุปสถานะลานจอด',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Colors.black,
                        ),
                      ),
                      const SizedBox(height: 16),

                      if (_lots.isEmpty)
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 32),
                          child: Center(child: CircularProgressIndicator()),
                        )
                      else
                        Column(
                          children: _lots.map((lot) {
                            final isFull = lot.available <= 0;
                            final statusColor =
                                isFull ? Colors.red : Colors.green;
                            final capacityLabel =
                                'ว่าง ${lot.available}/${lot.capacity}';
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 16),
                              child: _buildParkingLotItem(
                                lotId: lot.id,
                                title: lot.title,
                                location: lot.location,
                                capacity: capacityLabel,
                                statusColor: statusColor,
                                isFull: isFull,
                                updatedAt: lot.updatedAt,
                                onTap: () => Navigator.pushNamed(
                                  context,
                                  lot.routeName ?? '/parking${lot.id}',
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),

      bottomNavigationBar: const BottomNavigation(currentIndex: 0),
    );
  }

  Widget _buildStatCard(
    String title,
    String value,
    Color color,
    IconData icon, {
    VoidCallback? onTap,
  }) {
    final card = Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.3),
            blurRadius: 8,
            offset: const Offset(0, 4),
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
                title,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
              Icon(icon, color: Colors.white.withOpacity(0.8), size: 20),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 28,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );

    if (onTap != null) {
      return InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: card,
      );
    }

    return card;
  }

  // Seed again action used by the FAB: re-seed fake DB or write a fresh timestamp to Firebase
  Future<void> _seedAgain() async {
    if (!firebaseEnabled) {
      try {
        await FakeSeeder.seedFromAsset('assets/parking_schema_minimal.json');
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('รีเฟรชข้อมูลจำลองแล้ว')),
        );
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('รีเฟรชข้อมูลจำลองไม่สำเร็จ: $e')),
        );
      }
      return;
    }

    final db = _db;
    if (db == null) return;
    try {
      await db.child('manual_seed_at').set(ServerValue.timestamp);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Firebase: timestamp updated')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Firebase seed failed: $e')),
      );
    }
  }
  Widget _buildParkingLotItem({
    required String lotId,
    required String title,
    required String location,
    required String capacity,
    required Color statusColor,
    required bool isFull,
    required VoidCallback onTap,
    int? updatedAt,
  }) {
    final lastUpdated =
        updatedAt != null ? _formatUpdatedAt(updatedAt) : null;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.grey[50],
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey[200]!),
        ),
        child: Row(
          children: [
            Container(
              width: 12,
              height: 12,
              decoration: BoxDecoration(
                color: statusColor,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: Colors.black,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        capacity,
                        style:
                            TextStyle(fontSize: 14, color: Colors.grey[600]),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(
                        Icons.location_on,
                        size: 14,
                        color: Colors.grey[500],
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          location.isEmpty ? '-' : location,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[600],
                          ),
                        ),
                      ),
                    ],
                  ),
                  if (lastUpdated != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      'อัปเดตล่าสุด $lastUpdated',
                      style:
                          TextStyle(fontSize: 11, color: Colors.grey[500]),
                    ),
                  ],
                  const SizedBox(height: 8),
                  _liveFreeCountWidget(context, lotId, statusColor),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: Color(0xFF4285F4), size: 20),
          ],
        ),
      ),
    );
  }

  Widget _liveFreeCountWidget(
    BuildContext context,
    String lotId,
    Color fallbackColor,
  ) {
    final stream = Rtdb().lotSpots(lotId);
    return StreamBuilder<List<bool>>(
      stream: stream,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Text(
            'ข้อมูลไม่พร้อม',
            style: TextStyle(color: Colors.red.shade400, fontSize: 12),
          );
        }

        final spots = snapshot.data;
        if (spots == null) {
          return Row(
            children: const [
              SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
              SizedBox(width: 8),
              Text('กำลังโหลด...', style: TextStyle(fontSize: 12)),
            ],
          );
        }

        final total = spots.length;
        final occupied = spots.where((e) => e).length;
        final available = total - occupied;
        final color = available <= 0 ? Colors.red.shade400 : fallbackColor;
        final statusLabel = available <= 0
            ? 'เต็ม'
            : 'ว่าง $available จาก $total';

        return Row(
          children: [
            Icon(Icons.local_parking, size: 16, color: color),
            const SizedBox(width: 6),
            Text(
              statusLabel,
              style: TextStyle(
                fontSize: 12,
                color: color,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        );
      },
    );
  }

  String _formatUpdatedAt(int millis) {
    final dt = DateTime.fromMillisecondsSinceEpoch(millis).toLocal();
    final two = (int v) => v.toString().padLeft(2, '0');
    final dateLabel = '${dt.day}/${dt.month}/${dt.year}';
    final timeLabel = '${two(dt.hour)}:${two(dt.minute)}:${two(dt.second)}';
    return '$dateLabel $timeLabel';
  }
}

// โครงสร้างข้อมูลของลานจอด
class _Lot {
  final String id;
  final String title;
  final String location;
  final int capacity;
  final int occupied;
  final int available;
  final int? updatedAt;
  final String? routeName;
  const _Lot({
    required this.id,
    required this.title,
    required this.location,
    required this.capacity,
    required this.occupied,
    required this.available,
    this.updatedAt,
    required this.routeName,
  });

  int get freeSpots => available;
}
