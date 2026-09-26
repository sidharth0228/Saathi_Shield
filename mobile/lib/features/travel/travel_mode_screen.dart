import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';
import '../../../core/theme/app_theme.dart';
import '../../providers/travel_provider.dart';
import '../../providers/sos_provider.dart';
import '../../widgets/offline_banner.dart';

class TravelModeScreen extends ConsumerStatefulWidget {
  const TravelModeScreen({Key? key}) : super(key: key);

  @override
  ConsumerState<TravelModeScreen> createState() => _TravelModeScreenState();
}

class _TravelModeScreenState extends ConsumerState<TravelModeScreen> {
  final MapController _mapController = MapController();
  final _sourceController = TextEditingController(text: 'Connaught Place');
  final _destController = TextEditingController(text: 'Indira Gandhi International Airport');
  
  // Standard coordinates matching backend travel route simulation tests
  final double _sLat = 28.6304;
  final double _sLng = 77.2177;
  final double _dLat = 28.5562;
  final double _dLng = 77.1000;

  @override
  void dispose() {
    _sourceController.dispose();
    _destController.dispose();
    super.dispose();
  }

  void _startTravel() {
    ref.read(travelProvider.notifier).startSession(
      sourceAddress: _sourceController.text.trim(),
      sourceLat: _sLat,
      sourceLng: _sLng,
      destAddress: _destController.text.trim(),
      destLat: _dLat,
      destLng: _dLng,
    );
  }

  void _endTravel() {
    ref.read(travelProvider.notifier).endSession();
  }

  @override
  Widget build(BuildContext context) {
    final travelState = ref.watch(travelProvider);
    final theme = Theme.of(context);

    // Watch active location and re-center map camera
    ref.listen<TravelState>(travelProvider, (previous, next) {
      if (next.isActive) {
        _mapController.move(LatLng(next.currentLat, next.currentLng), 14.0);
      }
    });

    // Parse planned route coordinates from GeoJSON
    final coordinates = travelState.activeSession?.routeGeojson?['geometry']?['coordinates'] as List?;
    final List<LatLng> routePoints = [];
    if (coordinates != null) {
      for (var pt in coordinates) {
        routePoints.add(LatLng((pt[1] as num).toDouble(), (pt[0] as num).toDouble()));
      }
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Safe Travel Protection'),
        backgroundColor: AppTheme.primaryBlue,
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          const OfflineBanner(),
          Expanded(
            child: travelState.isLoading
                ? const Center(child: CircularProgressIndicator())
                : Stack(
                    children: [
                      // OSM Map View
                      FlutterMap(
                        mapController: _mapController,
                        options: MapOptions(
                          initialCenter: LatLng(_sLat, _sLng),
                          initialZoom: 13.0,
                        ),
                  children: [
                    TileLayer(
                      urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                      userAgentPackageName: 'com.saathishield.app',
                    ),
                    if (routePoints.isNotEmpty)
                      PolylineLayer(
                        polylines: [
                          Polyline(
                            points: routePoints,
                            strokeWidth: 5.0,
                            color: AppTheme.primaryBlue.withOpacity(0.6),
                          ),
                        ],
                      ),
                    if (travelState.isActive)
                      MarkerLayer(
                        markers: [
                          Marker(
                            point: LatLng(travelState.currentLat, travelState.currentLng),
                            width: 50,
                            height: 50,
                            child: Container(
                              decoration: BoxDecoration(
                                color: travelState.deviationDetected 
                                    ? AppTheme.accentSosRed 
                                    : AppTheme.primaryBlue,
                                shape: BoxShape.circle,
                                border: Border.all(color: Colors.white, width: 2),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.3),
                                    blurRadius: 6,
                                    spreadRadius: 1,
                                  ),
                                ],
                              ),
                              child: const Icon(
                                Icons.navigation,
                                color: Colors.white,
                                size: 24,
                              ),
                            ),
                          ),
                        ],
                      ),
                  ],
                ),

                // Deviation Alert Banner (at top)
                if (travelState.isActive && travelState.deviationDetected)
                  Positioned(
                    top: 16,
                    left: 16,
                    right: 16,
                    child: Card(
                      color: AppTheme.accentSosRed,
                      elevation: 6,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        child: Row(
                          children: const [
                            Icon(Icons.warning, color: Colors.white, size: 28),
                            SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'ROUTE DEVIATION DETECTED',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 13,
                                    ),
                                  ),
                                  SizedBox(height: 2),
                                  Text(
                                    'Get back to the planned route. 3 anomalies trigger auto-SOS.',
                                    style: TextStyle(
                                      color: Colors.white70,
                                      fontSize: 11,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),

                // Form / Progress controller card (at bottom)
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
                          color: Colors.black.withOpacity(0.15),
                          blurRadius: 10,
                          spreadRadius: 2,
                        ),
                      ],
                    ),
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        if (!travelState.isActive) ...[
                          Text(
                            'Setup Planned Route',
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 16),
                          TextFormField(
                            controller: _sourceController,
                            decoration: const InputDecoration(
                              labelText: 'Source Address',
                              prefixIcon: Icon(Icons.location_on, color: Colors.green),
                            ),
                          ),
                          const SizedBox(height: 12),
                          TextFormField(
                            controller: _destController,
                            decoration: const InputDecoration(
                              labelText: 'Destination Address',
                              prefixIcon: Icon(Icons.flag, color: AppTheme.accentSosRed),
                            ),
                          ),
                          const SizedBox(height: 20),
                          ElevatedButton.icon(
                            onPressed: _startTravel,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppTheme.primaryBlue,
                            ),
                            icon: const Icon(Icons.play_arrow),
                            label: const Text('Start Safe Travel Mode'),
                          ),
                        ] else ...[
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'Travel Route Tracking Active',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'Pinging location details every 5s...',
                                    style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                                  ),
                                ],
                              ),
                              _RiskBadge(
                                label: travelState.riskLabel,
                                score: travelState.riskScore,
                              ),
                            ],
                          ),
                          const Divider(height: 24),
                          Row(
                            children: [
                              Expanded(
                                child: OutlinedButton.icon(
                                  onPressed: () {
                                    ref.read(travelProvider.notifier).toggleDeviationSimulation();
                                  },
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: travelState.isDeviatedSimulation 
                                        ? AppTheme.successColor 
                                        : AppTheme.accentSosRed,
                                    side: BorderSide(
                                      color: travelState.isDeviatedSimulation 
                                          ? AppTheme.successColor 
                                          : AppTheme.accentSosRed,
                                    ),
                                  ),
                                  icon: Icon(
                                    travelState.isDeviatedSimulation 
                                        ? Icons.check_circle_outline 
                                        : Icons.warning_amber_rounded,
                                  ),
                                  label: Text(
                                    travelState.isDeviatedSimulation 
                                        ? 'Normalize Path' 
                                        : 'Simulate Deviation',
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: ElevatedButton.icon(
                                  onPressed: _endTravel,
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.grey.shade800,
                                    foregroundColor: Colors.white,
                                  ),
                                  icon: const Icon(Icons.stop),
                                  label: const Text('End Travel'),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ],
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

class _RiskBadge extends StatelessWidget {
  final String label;
  final double score;

  const _RiskBadge({
    Key? key,
    required this.label,
    required this.score,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    Color badgeColor = AppTheme.successColor;
    if (label == 'DANGEROUS' || label == 'HIGH') {
      badgeColor = AppTheme.accentSosRed;
    } else if (label == 'SUSPICIOUS' || label == 'MEDIUM') {
      badgeColor = AppTheme.warningColor;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: badgeColor.withOpacity(0.2),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: badgeColor,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 6),
          Text(
            '$label (${score.toInt()}%)',
            style: TextStyle(
              color: badgeColor,
              fontSize: 12,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}
