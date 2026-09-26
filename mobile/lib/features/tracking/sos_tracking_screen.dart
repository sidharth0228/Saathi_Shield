import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';
import '../../../core/theme/app_theme.dart';
import '../../providers/sos_tracking_provider.dart';
import '../../widgets/offline_banner.dart';

class SosTrackingScreen extends ConsumerStatefulWidget {
  final String secureToken;

  const SosTrackingScreen({
    Key? key,
    required this.secureToken,
  }) : super(key: key);

  @override
  ConsumerState<SosTrackingScreen> createState() => _SosTrackingScreenState();
}

class _SosTrackingScreenState extends ConsumerState<SosTrackingScreen> {
  final MapController _mapController = MapController();

  String _formatTime(int seconds) {
    final int m = seconds ~/ 60;
    final int s = seconds % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  double _calculateDistance(double lat1, double lon1, double lat2, double lon2) {
    const p = 0.017453292519943295; // Pi / 180
    final a = 0.5 - cos((lat2 - lat1) * p) / 2 +
        cos(lat1 * p) * cos(lat2 * p) * (1 - cos((lon2 - lon1) * p)) / 2;
    return 12742 * asin(sqrt(a)); // 2 * R; R = 6371 km
  }

  @override
  Widget build(BuildContext context) {
    final trackingState = ref.watch(sosTrackingProvider(widget.secureToken));
    final theme = Theme.of(context);

    // Watch for victim location changes and move map center
    ref.listen<SosTrackingState>(sosTrackingProvider(widget.secureToken), (previous, next) {
      if (next.victimLocation != null && 
          (previous == null || previous.victimLocation != next.victimLocation)) {
        _mapController.move(next.victimLocation!, 15.0);
      }
    });

    return Scaffold(
      appBar: AppBar(
        title: Text(
          trackingState.victimName.isNotEmpty
              ? '${trackingState.victimName} - SOS Tracking'
              : 'Live SOS Tracking',
        ),
        backgroundColor: AppTheme.accentSosRed,
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          const OfflineBanner(),
          Expanded(
            child: trackingState.isLoading && trackingState.victimLocation == null
                ? const Center(child: CircularProgressIndicator())
                : Stack(
                    children: [
                      // OpenStreetMap mapping
                      FlutterMap(
                        mapController: _mapController,
                        options: MapOptions(
                          initialCenter: trackingState.victimLocation ?? const LatLng(28.6139, 77.2090),
                          initialZoom: 15.0,
                        ),
                        children: [
                          TileLayer(
                            urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                            userAgentPackageName: 'com.saathishield.app',
                          ),
                          if (trackingState.movementHistory.isNotEmpty)
                            PolylineLayer(
                              polylines: [
                                Polyline(
                                  points: trackingState.movementHistory,
                                  strokeWidth: 4.5,
                                  color: AppTheme.accentSosRed,
                                ),
                              ],
                            ),
                          
                          // Responders Markers
                          MarkerLayer(
                            markers: [
                              // Victim Marker
                              if (trackingState.victimLocation != null)
                                Marker(
                                  point: trackingState.victimLocation!,
                                  width: 60,
                                  height: 60,
                                  child: Stack(
                                    alignment: Alignment.center,
                                    children: [
                                      const _PulsingMarkerRing(),
                                Container(
                                  width: 20,
                                  height: 20,
                                  decoration: BoxDecoration(
                                    color: AppTheme.accentSosRed,
                                    shape: BoxShape.circle,
                                    border: Border.all(color: Colors.white, width: 2),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withOpacity(0.3),
                                        blurRadius: 4,
                                        spreadRadius: 1,
                                      )
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        // Volunteer Markers
                        ...trackingState.activeResponders
                            .where((resp) => resp['latitude'] != null && resp['longitude'] != null)
                            .map((resp) {
                          final double rLat = (resp['latitude'] as num).toDouble();
                          final double rLng = (resp['longitude'] as num).toDouble();
                          return Marker(
                            point: LatLng(rLat, rLng),
                            width: 50,
                            height: 50,
                            child: Tooltip(
                              message: '${resp['responder_name']} (${resp['status']})',
                              child: Container(
                                decoration: BoxDecoration(
                                  color: Colors.green.shade600,
                                  shape: BoxShape.circle,
                                  border: Border.all(color: Colors.white, width: 2),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withOpacity(0.25),
                                      blurRadius: 4,
                                      spreadRadius: 1,
                                    )
                                  ],
                                ),
                                child: const Icon(
                                  Icons.medical_services_outlined,
                                  color: Colors.white,
                                  size: 22,
                                ),
                              ),
                            ),
                          );
                        }).toList(),
                      ],
                    ),
                  ],
                ),

                // Top Connection/Status bar
                Positioned(
                  top: 16,
                  left: 16,
                  right: 16,
                  child: Card(
                    elevation: 4,
                    color: trackingState.isWsConnected 
                        ? AppTheme.successColor.withOpacity(0.95)
                        : AppTheme.warningColor.withOpacity(0.95),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            trackingState.isWsConnected ? Icons.wifi : Icons.wifi_off,
                            color: Colors.white,
                            size: 20,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            trackingState.isWsConnected 
                                ? 'Real-Time WebSocket Feed Active'
                                : 'WebSocket Disconnected (Polling Backup)',
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

                // Bottom Sheet Details
                Positioned(
                  bottom: 0,
                  left: 0,
                  right: 0,
                  child: Container(
                    decoration: BoxDecoration(
                      color: theme.brightness == Brightness.dark
                          ? const Color(0xFF1E1E1E)
                          : Colors.white,
                      borderRadius: const BorderRadius.only(
                        topLeft: Radius.circular(24),
                        topRight: Radius.circular(24),
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.2),
                          blurRadius: 10,
                          spreadRadius: 2,
                        ),
                      ],
                    ),
                    padding: const EdgeInsets.all(24),
                    child: SingleChildScrollView(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    trackingState.victimName.isNotEmpty 
                                        ? trackingState.victimName 
                                        : 'Emergency Incident',
                                    style: theme.textTheme.titleMedium?.copyWith(
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Row(
                                    children: [
                                      Container(
                                        width: 8,
                                        height: 8,
                                        decoration: BoxDecoration(
                                          color: trackingState.status == 'ACTIVE'
                                              ? AppTheme.accentSosRed
                                              : AppTheme.successColor,
                                          shape: BoxShape.circle,
                                        ),
                                      ),
                                      const SizedBox(width: 6),
                                      Text(
                                        trackingState.status,
                                        style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.bold,
                                          color: trackingState.status == 'ACTIVE'
                                              ? AppTheme.accentSosRed
                                              : AppTheme.successColor,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                decoration: BoxDecoration(
                                  color: AppTheme.accentSosRed.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  _formatTime(trackingState.elapsedSeconds),
                                  style: const TextStyle(
                                    color: AppTheme.accentSosRed,
                                    fontSize: 20,
                                    fontWeight: FontWeight.bold,
                                    fontFamily: 'Courier',
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const Divider(height: 24),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              _InfoCol(
                                icon: Icons.battery_charging_full,
                                iconColor: Colors.green,
                                label: 'Battery',
                                value: '${trackingState.batteryPercentage}%',
                              ),
                              _InfoCol(
                                icon: Icons.location_on_outlined,
                                iconColor: Colors.blue,
                                label: 'Latitude',
                                value: trackingState.victimLocation?.latitude.toStringAsFixed(5) ?? '--',
                              ),
                              _InfoCol(
                                icon: Icons.map_outlined,
                                iconColor: Colors.orange,
                                label: 'Longitude',
                                value: trackingState.victimLocation?.longitude.toStringAsFixed(5) ?? '--',
                              ),
                            ],
                          ),

                          // Active Responders Feed Section
                          if (trackingState.activeResponders.isNotEmpty) ...[
                            const Divider(height: 24),
                            const Text(
                              'Responding Responders Network',
                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                            ),
                            const SizedBox(height: 8),
                            ...trackingState.activeResponders.map((resp) {
                              final int etaSec = resp['eta_seconds'] ?? 0;
                              final String etaString = etaSec > 0
                                  ? '${(etaSec / 60).ceil()} min'
                                  : (resp['status'] == 'ARRIVED' ? 'Arrived!' : resp['status']);
                              
                              double distance = 0.0;
                              if (trackingState.victimLocation != null &&
                                  resp['latitude'] != null &&
                                  resp['longitude'] != null) {
                                distance = _calculateDistance(
                                  trackingState.victimLocation!.latitude,
                                  trackingState.victimLocation!.longitude,
                                  (resp['latitude'] as num).toDouble(),
                                  (resp['longitude'] as num).toDouble(),
                                );
                              }

                              return Container(
                                margin: const EdgeInsets.symmetric(vertical: 4),
                                decoration: BoxDecoration(
                                  color: theme.brightness == Brightness.dark
                                      ? const Color(0xFF2C2C2C)
                                      : Colors.green.shade50,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: ListTile(
                                  leading: CircleAvatar(
                                    backgroundColor: Colors.green.withOpacity(0.2),
                                    child: const Icon(Icons.person, color: Colors.green),
                                  ),
                                  title: Text(resp['responder_name'] ?? 'Responder'),
                                  subtitle: Text(
                                    'Status: ${resp['status']} • Dist: ${distance > 0 ? '${distance.toStringAsFixed(2)} km' : 'Calculating...'}',
                                    style: const TextStyle(fontSize: 12),
                                  ),
                                  trailing: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: Colors.green,
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Text(
                                      etaString,
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 11,
                                      ),
                                    ),
                                  ),
                                ),
                              );
                            }).toList(),
                          ],

                          const SizedBox(height: 20),
                          ElevatedButton.icon(
                            onPressed: () {
                              Clipboard.setData(ClipboardData(
                                text: 'https://saathishield.live/track/${trackingState.secureToken}/',
                              ));
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Tracking URL copied to clipboard.')),
                              );
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppTheme.primaryBlue,
                              foregroundColor: Colors.white,
                            ),
                            icon: const Icon(Icons.share),
                            label: const Text('Share Public Live Tracking Link'),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PulsingMarkerRing extends StatefulWidget {
  const _PulsingMarkerRing({Key? key}) : super(key: key);

  @override
  State<_PulsingMarkerRing> createState() => _PulsingMarkerRingState();
}

class _PulsingMarkerRingState extends State<_PulsingMarkerRing> with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 1),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Container(
          width: 40 * _controller.value,
          height: 40 * _controller.value,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: AppTheme.accentSosRed.withOpacity(0.4 * (1 - _controller.value)),
          ),
        );
      },
    );
  }
}

class _InfoCol extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String label;
  final String value;

  const _InfoCol({
    Key? key,
    required this.icon,
    required this.iconColor,
    required this.label,
    required this.value,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Icon(icon, color: iconColor, size: 24),
        const SizedBox(height: 4),
        Text(label, style: const TextStyle(fontSize: 11, color: Colors.grey)),
        const SizedBox(height: 2),
        Text(value, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
      ],
    );
  }
}
