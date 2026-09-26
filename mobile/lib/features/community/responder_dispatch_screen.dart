import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart';
import '../../../core/theme/app_theme.dart';
import '../../providers/community_provider.dart';

class ResponderDispatchScreen extends ConsumerStatefulWidget {
  const ResponderDispatchScreen({Key? key}) : super(key: key);

  @override
  ConsumerState<ResponderDispatchScreen> createState() => _ResponderDispatchScreenState();
}

class _ResponderDispatchScreenState extends ConsumerState<ResponderDispatchScreen> {
  final MapController _mapController = MapController();

  double _calculateDistance(double lat1, double lon1, double lat2, double lon2) {
    const p = 0.017453292519943295; // Pi / 180
    final a = 0.5 - cos((lat2 - lat1) * p) / 2 +
        cos(lat1 * p) * cos(lat2 * p) * (1 - cos((lon2 - lon1) * p)) / 2;
    return 12742 * asin(sqrt(a)); // R = 6371 km
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(communityProvider);
    final dispatch = state.activeDispatch;
    final theme = Theme.of(context);

    // Watch for completed status to automatically pop screen
    ref.listen(communityProvider, (previous, next) {
      if (next.activeDispatch == null && previous?.activeDispatch != null) {
        context.pushReplacement('/community-dashboard');
      }
    });

    // If dispatch is null, fallback list
    if (dispatch == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Responder Dispatch')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    // Default victim Delhi coordinates in tests
    final double victimLat = 28.6139;
    final double victimLng = 77.2090;

    final LatLng victimLoc = LatLng(victimLat, victimLng);
    final LatLng responderLoc = LatLng(state.currentLat, state.currentLng);

    // Compute remaining distance
    final double distanceKm = _calculateDistance(
      state.currentLat,
      state.currentLng,
      victimLat,
      victimLng,
    );

    // Dynamic ETA approximation: assume average speed of 30 km/h (0.5 km/min)
    // ETA in minutes = distance / 0.5
    final double etaMinutes = distanceKm / 0.5;
    final String etaString = dispatch.status == 'ARRIVED'
        ? 'Arrived!'
        : (etaMinutes > 1 ? '${etaMinutes.ceil()} min' : 'Under 1 min');

    // Pan camera to follow the responder position
    ref.listen<CommunityState>(communityProvider, (previous, next) {
      _mapController.move(LatLng(next.currentLat, next.currentLng), 14.5);
    });

    return Scaffold(
      appBar: AppBar(
        title: const Text('SOS Active Dispatch'),
        backgroundColor: Colors.green.shade800,
        foregroundColor: Colors.white,
        automaticallyImplyLeading: false, // force lifecycle completion before exit
      ),
      body: Column(
        children: [
          // Live Map Layout
          Expanded(
            child: Stack(
              children: [
                FlutterMap(
                  mapController: _mapController,
                  options: MapOptions(
                    initialCenter: responderLoc,
                    initialZoom: 14.5,
                  ),
                  children: [
                    TileLayer(
                      urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                      userAgentPackageName: 'com.saathishield.app',
                    ),
                    PolylineLayer(
                      polylines: [
                        Polyline(
                          points: [responderLoc, victimLoc],
                          strokeWidth: 4.5,
                          color: Colors.green.shade600,
                        ),
                      ],
                    ),
                    MarkerLayer(
                      markers: [
                        // Victim Marker (Red Shield)
                        Marker(
                          point: victimLoc,
                          width: 45,
                          height: 45,
                          child: Container(
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
                            child: const Icon(Icons.warning, color: Colors.white, size: 20),
                          ),
                        ),
                        // Responder Marker (Green Ambulance/Vol)
                        Marker(
                          point: responderLoc,
                          width: 45,
                          height: 45,
                          child: Container(
                            decoration: BoxDecoration(
                              color: Colors.green.shade700,
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
                            child: const Icon(Icons.navigation, color: Colors.white, size: 20),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),

                // Live status connection bar
                Positioned(
                  top: 16,
                  left: 16,
                  right: 16,
                  child: Card(
                    color: Colors.black.withOpacity(0.85),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: const [
                              Icon(Icons.directions_bike, color: Colors.green),
                              SizedBox(width: 8),
                              Text(
                                'DISPATCH ACTIVE',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.green.shade800,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              dispatch.status,
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 10,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Bottom control drawer panel
          Container(
            decoration: BoxDecoration(
              color: theme.brightness == Brightness.dark
                  ? const Color(0xFF1E1E1E)
                  : Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 8,
                  spreadRadius: 2,
                ),
              ],
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(20),
                topRight: Radius.circular(20),
              ),
            ),
            padding: const EdgeInsets.all(24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Destination: Rescue Victim',
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          dispatch.responderPhone.isNotEmpty 
                              ? 'Victim Contact: ${dispatch.responderPhone}'
                              : 'Broadcast tracking online.',
                          style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                        ),
                      ],
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          etaString,
                          style: const TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            color: Colors.green,
                          ),
                        ),
                        Text(
                          '${distanceKm.toStringAsFixed(2)} km remaining',
                          style: const TextStyle(fontSize: 11, color: Colors.grey),
                        ),
                      ],
                    ),
                  ],
                ),
                const Divider(height: 24),

                // Controls based on status lifecycle
                if (dispatch.status == 'ACCEPTED') ...[
                  ElevatedButton.icon(
                    onPressed: () {
                      ref.read(communityProvider.notifier).updateStatus('EN_ROUTE');
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green.shade800,
                      foregroundColor: Colors.white,
                    ),
                    icon: const Icon(Icons.navigation),
                    label: const Text('Start Navigation (EN_ROUTE)'),
                  ),
                ] else if (dispatch.status == 'EN_ROUTE') ...[
                  Row(
                    children: [
                      const CircularProgressIndicator(strokeWidth: 3),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: const [
                            Text(
                              'En Route to Victim...',
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                            Text(
                              'Simulating coordinates movements on map. Tap arrived if reached.',
                              style: TextStyle(color: Colors.grey, fontSize: 11),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () {
                      ref.read(communityProvider.notifier).updateStatus(
                            'ARRIVED',
                            lat: victimLat,
                            lng: victimLng,
                          );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green.shade800,
                    ),
                    child: const Text('Declare Arrival (ARRIVED)'),
                  ),
                ] else if (dispatch.status == 'ARRIVED') ...[
                  const Text(
                    'Arrived at Victim\'s Location',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.green,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton.icon(
                    onPressed: () {
                      ref.read(communityProvider.notifier).updateStatus('COMPLETED');
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.successColor,
                    ),
                    icon: const Icon(Icons.check_circle_outline),
                    label: const Text('Mark Rescue Completed (RESOLVE)'),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
