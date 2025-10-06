import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

import '../services/services_rtdb.dart';
import '../widgets/bottom_navigation.dart';

class ParkingMapScreen extends StatefulWidget {
  const ParkingMapScreen({super.key});

  @override
  State<ParkingMapScreen> createState() => _ParkingMapScreenState();
}

class _ParkingMapScreenState extends State<ParkingMapScreen> {
  final MapController _mapController = MapController();

  final Map<String, LatLng> _lotCoordinates = const {
    'A': LatLng(9.09277839791744, 99.35548926284324),
    'B': LatLng(9.09561665008815, 99.35826690037293),
    'C': LatLng(9.097065444160801, 99.35790901681625),
  };

  final Map<String, String> _fallbackNames = const {
    'A': 'ลาน A - อาคาร LC',
    'B': 'ลาน B - อาคารวิศวกรรม',
    'C': 'ลาน C - ศูนย์กีฬา',
  };

  final Map<String, String> _fallbackLocations = const {
    'A': 'อาคารเรียน LC',
    'B': 'หน้าอาคารวิศวกรรม',
    'C': 'หน้าศูนย์กีฬา',
  };

  final Map<String, int> _fallbackTotals = const {'A': 10, 'B': 10, 'C': 10};

  LatLng? _userPosition;
  bool _requestingLocation = false;

  LatLng get _initialCenter {
    if (_lotCoordinates.isEmpty) {
      return const LatLng(13.736717, 100.523186);
    }
    final values = _lotCoordinates.values.toList();
    final avgLat =
        values.map((point) => point.latitude).reduce((a, b) => a + b) /
        values.length;
    final avgLng =
        values.map((point) => point.longitude).reduce((a, b) => a + b) /
        values.length;
    return LatLng(avgLat, avgLng);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('แผนที่ลานจอด'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
      ),
      body: StreamBuilder<Map<String, dynamic>>(
        stream: Rtdb().lotOverview(),
        builder: (context, snapshot) {
          final overview = snapshot.data ?? const <String, dynamic>{};
          final markers = _buildMarkers(overview);

          return Stack(
            children: [
              FlutterMap(
                mapController: _mapController,
                options: MapOptions(
                  initialCenter: _initialCenter,
                  initialZoom: 17,
                  interactionOptions: const InteractionOptions(
                    flags: InteractiveFlag.all,
                  ),
                ),
                children: [
                  TileLayer(
                    urlTemplate:
                        'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                    userAgentPackageName: 'com.example.my_app',
                  ),
                  MarkerLayer(markers: markers),
                  const RichAttributionWidget(
                    attributions: [
                      TextSourceAttribution('© OpenStreetMap contributors'),
                    ],
                  ),
                ],
              ),
              Positioned(right: 16, bottom: 16, child: _buildLegend(overview)),
            ],
          );
        },
      ),
      floatingActionButton: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          FloatingActionButton.small(
            heroTag: 'locate_me',
            onPressed: _requestingLocation ? null : _locateUser,
            child: _requestingLocation
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.my_location),
          ),
          const SizedBox(height: 12),
          FloatingActionButton(
            heroTag: 'recenter',
            onPressed: _recenter,
            child: const Icon(Icons.layers),
          ),
        ],
      ),
      bottomNavigationBar: const BottomNavigation(currentIndex: 2),
    );
  }

  void _recenter() {
    _mapController.move(_initialCenter, 17);
  }

  Future<void> _locateUser() async {
    if (_requestingLocation || !mounted) return;
    setState(() {
      _requestingLocation = true;
    });

    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        _showMessage('เปิดบริการระบุตำแหน่งก่อนใช้งาน');
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        _showMessage('ไม่ได้รับสิทธิ์เข้าถึงตำแหน่ง');
        return;
      }

      final position = await Geolocator.getCurrentPosition();
      if (!mounted) return;

      final userLatLng = LatLng(position.latitude, position.longitude);
      setState(() {
        _userPosition = userLatLng;
      });
      _mapController.move(userLatLng, 18);
    } catch (e) {
      _showMessage('ระบุตำแหน่งไม่สำเร็จ: $e');
    } finally {
      if (!mounted) return;
      setState(() {
        _requestingLocation = false;
      });
    }
  }

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  List<Marker> _buildMarkers(Map<String, dynamic> overview) {
    final markers = <Marker>[];

    _lotCoordinates.forEach((lotId, position) {
      final lotData = _composeLotData(lotId, overview);
      final total = lotData.total;
      final available = lotData.available;
      final markerColor = available > 0
          ? const Color(0xFF22C55E)
          : const Color(0xFFEF4444);
      final label = total > 0
          ? '${lotData.name}\nว่าง $available/$total'
          : lotData.name;

      markers.add(
        Marker(
          point: position,
          width: 160,
          height: 80,
          alignment: Alignment.topCenter,
          child: GestureDetector(
            onTap: () => _showLotDetails(context, lotData, available, total),
            child: Column(
              children: [
                Icon(Icons.location_on, color: markerColor, size: 36),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(8),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.1),
                        blurRadius: 6,
                      ),
                    ],
                  ),
                  child: Text(
                    label,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    });

    if (_userPosition != null) {
      markers.add(
        Marker(
          point: _userPosition!,
          width: 80,
          height: 80,
          alignment: Alignment.topCenter,
          child: Column(
            children: const [
              Icon(Icons.person_pin_circle, color: Color(0xFF2563EB), size: 44),
              SizedBox(height: 4),
              Text(
                'ตำแหน่งของฉัน',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
              ),
            ],
          ),
        ),
      );
    }

    return markers;
  }

  void _showLotDetails(
    BuildContext context,
    _LotSnapshot lotData,
    int available,
    int total,
  ) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) {
        final occupied = total - available;
        return Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    lotData.name,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  const Icon(Icons.location_on, size: 18, color: Colors.grey),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      lotData.location,
                      style: const TextStyle(
                        fontSize: 14,
                        color: Colors.black87,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  _buildInfoChip('ทั้งหมด', '$total', const Color(0xFF1E88E5)),
                  const SizedBox(width: 12),
                  _buildInfoChip('ว่าง', '$available', const Color(0xFF059669)),
                  const SizedBox(width: 12),
                  _buildInfoChip(
                    'ไม่ว่าง',
                    '$occupied',
                    const Color(0xFFDC2626),
                  ),
                ],
              ),
              if (lotData.updatedAtLabel != null) ...[
                const SizedBox(height: 12),
                Text(
                  'อัปเดตล่าสุด ${lotData.updatedAtLabel}',
                  style: const TextStyle(fontSize: 12, color: Colors.black54),
                ),
              ],
              const SizedBox(height: 16),
              Align(
                alignment: Alignment.centerRight,
                child: ElevatedButton.icon(
                  onPressed: () =>
                      Navigator.pushReplacementNamed(context, lotData.route),
                  icon: const Icon(Icons.directions_car, size: 18),
                  label: const Text('ดูรายละเอียด'),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildLegend(Map<String, dynamic> overview) {
    final lots = _lotCoordinates.keys.map(
      (id) => _composeLotData(id, overview),
    );
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.12),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
            'สถานะโดยสรุป',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          for (final lot in lots)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(
                      color: lot.available > 0
                          ? const Color(0xFF22C55E)
                          : const Color(0xFFEF4444),
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text('${lot.name} · ว่าง ${lot.available}/${lot.total}'),
                ],
              ),
            ),
        ],
      ),
    );
  }

  _LotSnapshot _composeLotData(String lotId, Map<String, dynamic> overview) {
    final raw = overview[lotId] is Map
        ? Map<String, dynamic>.from(overview[lotId] as Map)
        : <String, dynamic>{};
    final meta = raw['metadata'] is Map
        ? Map<String, dynamic>.from(raw['metadata'] as Map)
        : <String, dynamic>{};
    final summary = raw['summary'] is Map
        ? Map<String, dynamic>.from(raw['summary'] as Map)
        : <String, dynamic>{};

    final name =
        (raw['name'] ?? meta['name'] ?? _fallbackNames[lotId] ?? 'ลาน $lotId')
            .toString();
    final location =
        (raw['location'] ??
                meta['location'] ??
                _fallbackLocations[lotId] ??
                '-')
            .toString();
    final route = (raw['route'] ?? meta['route'] ?? '/parking$lotId')
        .toString();

    final totalFromMeta = _asInt(
      raw['total_spots'] ?? meta['total_spots'],
      _fallbackTotals[lotId] ?? 0,
    );
    final sensorsCount = meta['sensors_map'] is Map
        ? (meta['sensors_map'] as Map).length
        : 0;
    // prefer summaries computed from `current` root
    final availableRaw = _asInt(
      summary['available'],
      sensorsCount != 0 ? sensorsCount : _fallbackTotals[lotId] ?? 0,
    );
    final occupiedRaw = _asInt(summary['occupied'], 0);

    final provisionalTotal = totalFromMeta != 0
        ? totalFromMeta
        : (sensorsCount != 0 ? sensorsCount : availableRaw + occupiedRaw);
    final total = provisionalTotal < 0 ? 0 : provisionalTotal;
    final available = availableRaw < 0
        ? 0
        : (availableRaw > total ? total : availableRaw);
    final updatedAt = _asInt(summary['updated_at'] ?? raw['updated_at'], 0);

    return _LotSnapshot(
      id: lotId,
      name: name,
      location: location,
      route: route,
      available: available,
      total: total,
      updatedAtMillis: updatedAt == 0 ? null : updatedAt,
    );
  }

  Widget _buildInfoChip(String label, String value, Color color) {
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

  int _asInt(dynamic value, [int fallback = 0]) {
    if (value == null) return fallback;
    if (value is int) return value;
    if (value is double) return value.round();
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value) ?? fallback;
    return fallback;
  }
}

class _LotSnapshot {
  final String id;
  final String name;
  final String location;
  final String route;
  final int available;
  final int total;
  final int? updatedAtMillis;

  const _LotSnapshot({
    required this.id,
    required this.name,
    required this.location,
    required this.route,
    required this.available,
    required this.total,
    this.updatedAtMillis,
  });

  String? get updatedAtLabel {
    if (updatedAtMillis == null) return null;
    final dt = DateTime.fromMillisecondsSinceEpoch(updatedAtMillis!).toLocal();
    String two(int v) => v.toString().padLeft(2, '0');
    return '${dt.day}/${dt.month}/${dt.year} ${two(dt.hour)}:${two(dt.minute)}:${two(dt.second)}';
  }
}
