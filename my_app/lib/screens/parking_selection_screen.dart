import 'package:flutter/material.dart';
import '../widgets/bottom_navigation.dart';
import '../services/services_rtdb.dart';

class ParkingSelectionScreen extends StatelessWidget {
  const ParkingSelectionScreen({super.key});

  static const List<Map<String, dynamic>> _fallbackLots = [
    {
      'id': 'A',
      'title': 'ลาน A - อาคาร LC',
      'location': 'อาคารเรียน LC',
      'route': '/parkingA',
      'available': 6,
      'total': 10,
    },
    {
      'id': 'B',
      'title': 'ลาน B - อาคารวิศวกรรม',
      'location': 'หน้าอาคารวิศวกรรม',
      'route': '/parkingB',
      'available': 2,
      'total': 10,
    },
    {
      'id': 'C',
      'title': 'ลาน C - ศูนย์กีฬา',
      'location': 'หน้าศูนย์กีฬา',
      'route': '/parkingC',
      'available': 0,
      'total': 10,
    },
  ];

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<Map<String, dynamic>>(
      stream: Rtdb().lotOverview(),
      builder: (context, snapshot) {
        final overview = snapshot.data;
        final hasLive = overview != null && overview.isNotEmpty;
        final lots = hasLive
            ? _buildLotViewModels(overview!)
            : _fallbackLots
                  .map((lot) => Map<String, dynamic>.from(lot))
                  .toList();

        final totalAvailable = lots.fold<int>(
          0,
          (sum, lot) => sum + (lot['available'] as int),
        );
        final totalSpots = lots.fold<int>(
          0,
          (sum, lot) => sum + (lot['total'] as int),
        );

        return _buildSelectionScaffold(
          context,
          lots,
          totalAvailable,
          totalSpots,
          hasLiveData: hasLive,
        );
      },
    );
  }

  List<Map<String, dynamic>> _buildLotViewModels(
    Map<String, dynamic> overview,
  ) {
    final items =
        overview.entries.map((entry) {
            final raw = entry.value is Map
                ? Map<String, dynamic>.from(entry.value as Map)
                : <String, dynamic>{};
            final meta = raw['metadata'] is Map
                ? Map<String, dynamic>.from(raw['metadata'] as Map)
                : <String, dynamic>{};
            final summary = raw['summary'] is Map
                ? Map<String, dynamic>.from(raw['summary'] as Map)
                : <String, dynamic>{};

            final id = entry.key.toString();
            final title = (raw['name'] ?? meta['name'] ?? 'ลาน $id')
                .toString();
            final location = (raw['location'] ?? meta['location'] ?? '')
                .toString();

            final totalFromMeta = _asInt(
              raw['total_spots'] ?? meta['total_spots'],
              0,
            );
            final sensorsCount = meta['sensors_map'] is Map
                ? (meta['sensors_map'] as Map).length
                : 0;
            // summaries provided by Rtdb are computed from `current` so prefer them
            final available = _asInt(summary['available'], sensorsCount);
            final occupied = _asInt(summary['occupied'], 0);

            final provisionalTotal = totalFromMeta != 0
                ? totalFromMeta
                : (sensorsCount != 0 ? sensorsCount : available + occupied);

            final total = provisionalTotal < 0 ? 0 : provisionalTotal;
            final safeAvailable = available < 0
                ? 0
                : (available > total ? total : available);
            final computedOccupied = total - safeAvailable;

            return {
              'id': id,
              'title': title,
              'location': location,
              'route': raw['route'] ?? '/parking$id',
              'available': safeAvailable,
              'total': total,
              'occupied': computedOccupied,
              'updated_at': raw['updated_at'] ?? summary['updated_at'],
            };
          }).toList()
          ..sort((a, b) => (a['id'] as String).compareTo(b['id'] as String));
    return items;
  }

  int _asInt(dynamic value, [int fallback = 0]) {
    if (value == null) return fallback;
    if (value is int) return value;
    if (value is double) return value.round();
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value) ?? fallback;
    return fallback;
  }

  String _formatUpdatedAt(int millis) {
    final dt = DateTime.fromMillisecondsSinceEpoch(millis).toLocal();
    final two = (int v) => v.toString().padLeft(2, '0');
    final dateLabel = '${dt.day}/${dt.month}/${dt.year}';
    final timeLabel = '${two(dt.hour)}:${two(dt.minute)}:${two(dt.second)}';
    return '$dateLabel $timeLabel';
  }

  Widget _buildSelectionScaffold(
    BuildContext context,
    List<Map<String, dynamic>> lots,
    int totalAvailable,
    int totalSpots, {
    required bool hasLiveData,
  }) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('เลือกที่จอดรถ'),
        backgroundColor: Colors.white,
        elevation: 0,
        foregroundColor: Colors.black,
      ),
      backgroundColor: const Color(0xFFE8F0FE),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.04),
                    blurRadius: 8,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF1F8FF),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      Icons.local_parking,
                      color: const Color(0xFF4285F4),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'เลือกที่จอดรถที่พร้อมใช้งาน',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'ว่าง $totalAvailable / $totalSpots ช่อง',
                          style: TextStyle(color: Colors.grey[700]),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          hasLiveData
                              ? 'ข้อมูลสดจาก Firebase Realtime Database'
                              : 'ใช้ข้อมูลจำลอง (โหมดออฟไลน์)',
                          style: TextStyle(
                            color: hasLiveData
                                ? const Color(0xFF1E8E6B)
                                : const Color(0xFFB45309),
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  ElevatedButton.icon(
                    onPressed: () =>
                        Navigator.pushNamed(context, '/parking-map'),
                    icon: const Icon(Icons.location_on, size: 18),
                    label: const FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text('เปิดแผนที่'),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF4285F4),
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 10,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          Expanded(
            child: ListView.separated(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              itemCount: lots.length,
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (context, i) {
                final lot = lots[i];
                final available = lot['available'] as int;
                final total = lot['total'] as int;
                final occupied = total - available;
                final isFull = available == 0;
                final percentage = ((occupied / (total > 0 ? total : 1)) * 100)
                    .round();
                final location = (lot['location'] ?? lot['distance'] ?? '-')
                    .toString();
                final route =
                    (lot['route'] as String?) ?? "/parking${lot['id'] ?? ''}";
                final updatedAt = lot['updated_at'] as int?;
                final lastUpdated = updatedAt != null
                    ? _formatUpdatedAt(updatedAt)
                    : null;

                return Material(
                  color: Colors.transparent,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(12),
                    onTap: () {
                      Navigator.pushNamed(context, route);
                    },
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.04),
                            blurRadius: 8,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 56,
                            height: 56,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: isFull
                                  ? const Color(0xFFFFEBEB)
                                  : const Color(0xFFEFFAF6),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              'P',
                              style: TextStyle(
                                color: isFull
                                    ? const Color(0xFFB00020)
                                    : const Color(0xFF1E8E6B),
                                fontWeight: FontWeight.bold,
                                fontSize: 20,
                              ),
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Flexible(
                                      child: Text(
                                        lot['title'] as String,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ),
                                    Text(
                                      '$occupied/$total',
                                      style: TextStyle(
                                        color: Colors.grey[700],
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                ),
                                if (lastUpdated != null) ...[
                                  const SizedBox(height: 6),
                                  Text(
                                    'อัปเดตล่าสุด $lastUpdated',
                                    style: TextStyle(
                                      color: Colors.grey[500],
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                                const SizedBox(height: 8),
                                Row(
                                  children: [
                                    Icon(
                                      Icons.location_on,
                                      size: 14,
                                      color: Colors.grey[500],
                                    ),
                                    const SizedBox(width: 6),
                                    Flexible(
                                      child: Text(
                                        location,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          color: Colors.grey[600],
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                if (lastUpdated != null) ...[
                                  const SizedBox(height: 6),
                                  Text(
                                    'อัปเดตล่าสุด $lastUpdated',
                                    style: TextStyle(
                                      color: Colors.grey[500],
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                                const SizedBox(height: 8),
                                Row(
                                  children: [
                                    Container(
                                      width: 8,
                                      height: 8,
                                      decoration: BoxDecoration(
                                        color: isFull
                                            ? const Color(0xFFFF6B6B)
                                            : const Color(0xFF4ECDC4),
                                        shape: BoxShape.circle,
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      isFull
                                          ? 'เต็ม'
                                          : 'ว่าง $available ช่อง',
                                      style: TextStyle(
                                        color: isFull
                                            ? const Color(0xFFB00020)
                                            : const Color(0xFF1E8E6B),
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 10),
                                Row(
                                  children: [
                                    Expanded(
                                      child: Container(
                                        height: 6,
                                        decoration: BoxDecoration(
                                          color: Colors.grey[200],
                                          borderRadius: BorderRadius.circular(
                                            4,
                                          ),
                                        ),
                                        child: ClipRRect(
                                          borderRadius: BorderRadius.circular(
                                            4,
                                          ),
                                          child: FractionallySizedBox(
                                            alignment: Alignment.centerLeft,
                                            widthFactor: (total > 0)
                                                ? (occupied / total)
                                                : 0,
                                            child: Container(
                                              decoration: BoxDecoration(
                                                gradient: LinearGradient(
                                                  colors: isFull
                                                      ? [
                                                          const Color(
                                                            0xFFFF6B6B,
                                                          ),
                                                          const Color(
                                                            0xFFEE5A52,
                                                          ),
                                                        ]
                                                      : [
                                                          const Color(
                                                            0xFF4ECDC4,
                                                          ),
                                                          const Color(
                                                            0xFF44A08D,
                                                          ),
                                                        ],
                                                ),
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    ConstrainedBox(
                                      constraints: const BoxConstraints(
                                        maxWidth: 60,
                                      ),
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 6,
                                          vertical: 6,
                                        ),
                                        decoration: BoxDecoration(
                                          color: isFull
                                              ? const Color(0xFFFF6B6B)
                                              : const Color(0xFF4ECDC4),
                                          borderRadius: BorderRadius.circular(
                                            12,
                                          ),
                                        ),
                                        child: FittedBox(
                                          fit: BoxFit.scaleDown,
                                          child: Text(
                                            isFull ? 'เต็ม' : '$percentage%',
                                            style: const TextStyle(
                                              color: Colors.white,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
      bottomNavigationBar: const BottomNavigation(currentIndex: 1),
    );
  }
}
