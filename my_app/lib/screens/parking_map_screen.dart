import 'package:flutter/material.dart';
import '../widgets/bottom_navigation.dart';
import '../services/services_rtdb.dart';

class ParkingMapScreen extends StatefulWidget {
  const ParkingMapScreen({super.key});

  @override
  State<ParkingMapScreen> createState() => _ParkingMapScreenState();
}

class _ParkingMapScreenState extends State<ParkingMapScreen> {
  final TransformationController _transformationController =
      TransformationController();

  // Marker positions are fractional (0..1) within the virtual map canvas
  final Map<String, Offset> _markers = {
    'A': const Offset(0.45, 0.48),
    'B': const Offset(0.55, 0.44),
    'C': const Offset(0.47, 0.52),
  };

  final Map<String, int> _fallbackTotals = {'A': 10, 'B': 10, 'C': 10};

  void _recenter() {
    // Reset transforms to identity (centered)
    _transformationController.value = Matrix4.identity();
  }

  @override
  void dispose() {
    _transformationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('เนเธเธเธ—เธตเน'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
      ),
      body: StreamBuilder<Map<String, dynamic>>(
        stream: Rtdb().lotOverview(),
        builder: (context, snapshot) {
          final overview = snapshot.data ?? const <String, dynamic>{};
          return Center(
            child: InteractiveViewer(
              transformationController: _transformationController,
              boundaryMargin: const EdgeInsets.all(double.infinity),
              minScale: 0.5,
              maxScale: 3.0,
              child: SizedBox(
                width: 1000,
                height: 700,
                child: Stack(
                  children: [
                    Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [Colors.green[50]!, Colors.blue[50]!],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                      ),
                    ),
                    CustomPaint(
                      size: const Size(1000, 700),
                      painter: _GridPainter(),
                    ),
                    ..._markers.entries.map((entry) {
                      final frac = entry.value;
                      final lotId = entry.key;
                      final data = overview[lotId] as Map? ?? const {};
                      final meta = data['metadata'] is Map
                          ? Map<String, dynamic>.from(data['metadata'] as Map)
                          : const <String, dynamic>{};
                      final available = _asInt(
                        data['available'] ?? (data['summary']?['available']),
                        0,
                      );
                      final total = _asInt(
                        data['total_spots'] ?? meta['total_spots'],
                        _fallbackTotals[lotId] ?? 0,
                      );
                      final safeAvailable = available.clamp(0, total);
                      final label = total > 0
                          ? 'Lot ' +
                                lotId +
                                ' · ว่าง ' +
                                safeAvailable.toString() +
                                '/' +
                                total.toString()
                          : 'Lot ' + lotId;
                      final color = safeAvailable > 0
                          ? const Color(0xFF22C55E)
                          : const Color(0xFFEF4444);
                      return Positioned(
                        left: frac.dx * 1000 - 18,
                        top: frac.dy * 700 - 36,
                        child: Column(
                          children: [
                            Icon(Icons.location_on, color: color, size: 36),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(6),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.08),
                                    blurRadius: 6,
                                  ),
                                ],
                              ),
                              child: Text(label),
                            ),
                          ],
                        ),
                      );
                    }),
                    Positioned(
                      right: 16,
                      bottom: 16,
                      child: _buildLegend(overview),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
      bottomNavigationBar: const BottomNavigation(currentIndex: 2),
    );
  }

  Widget _buildLegend(Map<String, dynamic> overview) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.9),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: _markers.keys.map((lotId) {
          final data = overview[lotId] as Map? ?? const {};
          final meta = data['metadata'] is Map
              ? Map<String, dynamic>.from(data['metadata'] as Map)
              : const <String, dynamic>{};
          final available = _asInt(
            data['available'] ?? (data['summary']?['available']),
            0,
          );
          final total = _asInt(
            data['total_spots'] ?? meta['total_spots'],
            _fallbackTotals[lotId] ?? 0,
          );
          final safeAvailable = available.clamp(0, total);
          final color = safeAvailable > 0
              ? const Color(0xFF22C55E)
              : const Color(0xFFEF4444);
          final label = total > 0
              ? 'ลาน ' +
                    lotId +
                    ' · ว่าง ' +
                    safeAvailable.toString() +
                    '/' +
                    total.toString()
              : 'ลาน ' + lotId;
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                    color: color,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 8),
                Text(label),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  int _asInt(dynamic value, [int fallback = 0]) {
    if (value == null) return fallback;
    if (value is int) return value;
    if (value is double) return value.round();
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value) ?? fallback;
    return fallback;
  }
}

class _GridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = Colors.white.withOpacity(0.06);
    const step = 50.0;
    for (double x = 0; x < size.width; x += step) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
    for (double y = 0; y < size.height; y += step) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
