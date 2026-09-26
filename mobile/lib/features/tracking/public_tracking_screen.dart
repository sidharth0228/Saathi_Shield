import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';
import '../../../core/theme/app_theme.dart';
import '../../providers/sos_tracking_provider.dart';
import '../../widgets/offline_banner.dart';

class PublicTrackingScreen extends ConsumerStatefulWidget {
  final String secureToken;

  const PublicTrackingScreen({
    Key? key,
    required this.secureToken,
  }) : super(key: key);

  @override
  ConsumerState<PublicTrackingScreen> createState() => _PublicTrackingScreenState();
}

class _PublicTrackingScreenState extends ConsumerState<PublicTrackingScreen> {
  final MapController _mapController = MapController();
  bool _showMedicalDetails = false;

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

    // Watch for coordinates changes and center camera
    ref.listen<SosTrackingState>(sosTrackingProvider(widget.secureToken), (previous, next) {
      if (next.victimLocation != null && 
          (previous == null || previous.victimLocation != next.victimLocation)) {
        _mapController.move(next.victimLocation!, 15.0);
      }
    });

    final medProfile = trackingState.medicalProfile;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Saathi Shield Public Tracking'),
        backgroundColor: Colors.grey.shade900,
        foregroundColor: Colors.white,
        automaticallyImplyLeading: false, // public tracking needs no back button
      ),
      body: Column(
        children: [
          const OfflineBanner(),
          Expanded(
            child: trackingState.isLoading && trackingState.victimLocation == null
                ? const Center(child: CircularProgressIndicator())
                : Stack(
                    children: [
                      // OSM Map View
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
                                  strokeWidth: 4.0,
                                  color: AppTheme.accentSosRed,
                                ),
                              ],
                            ),
                          
                          // Markers Layer (Victim & Responders)
                          MarkerLayer(
                            markers: [
                              // Victim Marker
                              if (trackingState.victimLocation != null)
                                Marker(
                                  point: trackingState.victimLocation!,
                                  width: 50,
                                  height: 50,
                                  child: Stack(
                                    alignment: Alignment.center,
                                    children: [
                                      const _PulsingMarkerRing(),
                                Container(
                                  width: 18,
                                  height: 18,
                                  decoration: BoxDecoration(
                                    color: AppTheme.accentSosRed,
                                    shape: BoxShape.circle,
                                    border: Border.all(color: Colors.white, width: 2),
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
                            width: 45,
                            height: 45,
                            child: Container(
                              decoration: BoxDecoration(
                                color: Colors.green.shade600,
                                shape: BoxShape.circle,
                                border: Border.all(color: Colors.white, width: 2),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.2),
                                    blurRadius: 4,
                                    spreadRadius: 1,
                                  )
                                ],
                              ),
                              child: const Icon(
                                Icons.medical_services_outlined,
                                color: Colors.white,
                                size: 20,
                              ),
                            ),
                          );
                        }).toList(),
                      ],
                    ),
                  ],
                ),

                // Top Connection Card
                Positioned(
                  top: 16,
                  left: 16,
                  right: 16,
                  child: Card(
                    color: Colors.black.withOpacity(0.85),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            width: 10,
                            height: 10,
                            decoration: const BoxDecoration(
                              color: Colors.green,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 8),
                          const Text(
                            'SECURE TELEMETRY ACTIVE',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 11,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

                // Bottom Panel Overlay
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
                    padding: const EdgeInsets.all(20),
                    child: SingleChildScrollView(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      trackingState.victimName.isNotEmpty 
                                          ? trackingState.victimName 
                                          : 'Emergency Alert Victim',
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 18,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      trackingState.status == 'ACTIVE' 
                                          ? 'Tracking Live Location...' 
                                          : 'Incident Resolved',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: trackingState.status == 'ACTIVE' 
                                            ? AppTheme.accentSosRed 
                                            : Colors.grey,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Text(
                                    _formatTime(trackingState.elapsedSeconds),
                                    style: const TextStyle(
                                      fontSize: 20,
                                      fontWeight: FontWeight.bold,
                                      fontFamily: 'Courier',
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Row(
                                    children: [
                                      const Icon(Icons.battery_std, size: 14, color: Colors.green),
                                      const SizedBox(width: 2),
                                      Text(
                                        '${trackingState.batteryPercentage}%',
                                        style: const TextStyle(fontSize: 11, color: Colors.grey),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ],
                          ),
                          
                          // Responders lists
                          if (trackingState.activeResponders.isNotEmpty) ...[
                            const Divider(height: 20),
                            const Text(
                              'Dispatched Responders',
                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
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
                                margin: const EdgeInsets.symmetric(vertical: 3),
                                decoration: BoxDecoration(
                                  color: theme.brightness == Brightness.dark
                                      ? const Color(0xFF2C2C2C)
                                      : Colors.grey.shade100,
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: ListTile(
                                  dense: true,
                                  leading: const Icon(Icons.medical_services, color: Colors.green),
                                  title: Text(resp['responder_name'] ?? 'Responder'),
                                  subtitle: Text(
                                    'Status: ${resp['status']} • ${distance > 0 ? '${distance.toStringAsFixed(2)} km' : ''}',
                                  ),
                                  trailing: Text(
                                    etaString,
                                    style: const TextStyle(
                                      color: Colors.green,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              );
                            }).toList(),
                          ],

                          // Medical Profile Details Card
                          if (medProfile != null) ...[
                            const Divider(height: 20),
                            OutlinedButton.icon(
                              onPressed: () {
                                setState(() {
                                  _showMedicalDetails = !_showMedicalDetails;
                                });
                              },
                              icon: Icon(
                                _showMedicalDetails ? Icons.expand_less : Icons.medical_services_outlined,
                                color: AppTheme.accentSosRed,
                              ),
                              label: Text(
                                _showMedicalDetails ? 'Hide Medical Profile' : 'Show Medical Profile',
                                style: const TextStyle(color: AppTheme.accentSosRed),
                              ),
                              style: OutlinedButton.styleFrom(
                                side: const BorderSide(color: AppTheme.accentSosRed),
                              ),
                            ),
                            if (_showMedicalDetails) ...[
                              const SizedBox(height: 12),
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: theme.brightness == Brightness.dark
                                      ? const Color(0xFF2C2C2C)
                                      : Colors.red.shade50,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Column(
                                  children: [
                                    _MedItem(
                                      label: 'Blood Group',
                                      value: medProfile['blood_group']?.toString().isNotEmpty == true
                                          ? medProfile['blood_group']
                                          : 'Unknown',
                                      icon: Icons.bloodtype,
                                      iconColor: AppTheme.accentSosRed,
                                    ),
                                    _MedItem(
                                      label: 'Medical Conditions',
                                      value: medProfile['medical_conditions']?.toString().isNotEmpty == true
                                          ? medProfile['medical_conditions']
                                          : 'None reported',
                                      icon: Icons.healing,
                                    ),
                                    _MedItem(
                                      label: 'Allergies',
                                      value: medProfile['allergies']?.toString().isNotEmpty == true
                                          ? medProfile['allergies']
                                          : 'None reported',
                                      icon: Icons.warning_amber_rounded,
                                    ),
                                    _MedItem(
                                      label: 'Medications',
                                      value: medProfile['medications']?.toString().isNotEmpty == true
                                          ? medProfile['medications']
                                          : 'None reported',
                                      icon: Icons.medication,
                                    ),
                                    _MedItem(
                                      label: 'Organ Donor',
                                      value: medProfile['organ_donor'] == true ? 'Yes' : 'No',
                                      icon: Icons.favorite,
                                      iconColor: Colors.pink,
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ],
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

class _MedItem extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color? iconColor;

  const _MedItem({
    Key? key,
    required this.label,
    required this.value,
    required this.icon,
    this.iconColor,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: iconColor ?? Colors.grey),
          const SizedBox(width: 8),
          Expanded(
            child: RichText(
              text: TextSpan(
                style: TextStyle(
                  color: Theme.of(context).brightness == Brightness.dark
                      ? Colors.white
                      : Colors.black87,
                  fontSize: 13,
                ),
                children: [
                  TextSpan(
                    text: '$label: ',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  TextSpan(text: value),
                ],
              ),
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
      duration: const Duration(milliseconds: 1200),
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
          width: 36 * _controller.value,
          height: 36 * _controller.value,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: AppTheme.accentSosRed.withOpacity(0.35 * (1 - _controller.value)),
          ),
        );
      },
    );
  }
}
