import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/app_theme.dart';
import '../../models/alert_model.dart';
import '../../providers/sos_provider.dart';
import '../../providers/sos_tracking_provider.dart';
import '../../providers/travel_provider.dart';
import '../../providers/notifications_provider.dart';

class DemoControllerScreen extends ConsumerStatefulWidget {
  const DemoControllerScreen({Key? key}) : super(key: key);

  @override
  ConsumerState<DemoControllerScreen> createState() => _DemoControllerScreenState();
}

class _DemoControllerScreenState extends ConsumerState<DemoControllerScreen> {
  bool _isSimulatingResponder = false;

  void _simulateSosTrigger() {
    final mockAlert = AlertModel(
      alertId: 'demo_alert_777',
      secureToken: 'demo_token_777',
      trackingUrl: 'https://saathishield.live/track/demo_token_777/',
      message: 'Simulated SOS Alert triggered by tester.',
    );

    // Set SOS state to active directly
    ref.read(sosProvider.notifier).setActiveAlertDirectly(mockAlert);

    // Push notification (which triggers in-app banner)
    ref.read(notificationsProvider.notifier).addNotification(
      title: 'SOS Emergency Alert Active',
      body: 'Emergency alert broadcasts live. Tap to open real-time tracking map.',
      category: 'SOS',
      payload: {'secure_token': 'demo_token_777'},
    );

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Simulated SOS Trigger active. Red overlay added on Dashboard.'),
        backgroundColor: AppTheme.accentSosRed,
      ),
    );
  }

  void _simulateTravelDeviation() async {
    // Start session if not already active
    final travelState = ref.read(travelProvider);
    if (!travelState.isActive) {
      await ref.read(travelProvider.notifier).startSession(
        sourceAddress: 'Connaught Place',
        sourceLat: 28.6304,
        sourceLng: 77.2177,
        destAddress: 'Indira Gandhi International Airport',
        destLat: 28.5562,
        destLng: 77.1000,
      );
    }

    // Set deviation simulation to true
    ref.read(travelProvider.notifier).toggleDeviationSimulation();

    // Trigger notification
    ref.read(notificationsProvider.notifier).addNotification(
      title: 'Route Deviation warning',
      body: 'You have deviated by 580m from your planned route. Tap to view map.',
      category: 'TRAVEL',
    );

    context.push('/travel-mode');

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Travel route deviation simulated successfully.'),
        backgroundColor: AppTheme.warningColor,
      ),
    );
  }

  void _simulateResponderAcceptance() async {
    if (_isSimulatingResponder) return;

    setState(() {
      _isSimulatingResponder = true;
    });

    final sosState = ref.read(sosProvider);
    String token = 'demo_token_777';

    // Auto trigger SOS first if not active
    if (!sosState.isActive) {
      final mockAlert = AlertModel(
        alertId: 'demo_alert_777',
        secureToken: token,
        trackingUrl: 'https://saathishield.live/track/$token/',
        message: 'Simulated SOS Alert triggered by tester.',
      );
      ref.read(sosProvider.notifier).setActiveAlertDirectly(mockAlert);
      ref.read(notificationsProvider.notifier).addNotification(
        title: 'SOS Emergency Alert Active',
        body: 'Emergency alert broadcasts live. Tap to open real-time tracking map.',
        category: 'SOS',
        payload: {'secure_token': token},
        showBanner: false,
      );
    } else {
      token = sosState.activeAlert!.secureToken;
    }

    // Pushes user to map tracking screen
    context.push('/sos-tracking/$token');

    try {
      // Step 1: Responder accepts alert (ACCEPTED)
      await Future.delayed(const Duration(milliseconds: 1500));
      ref.read(notificationsProvider.notifier).addNotification(
        title: 'Responder Dispatched',
        body: 'Volunteer Rajesh Kumar accepted alert and is en route. ETA: 3 min.',
        category: 'COMMUNITY',
      );

      final trackingNotifier = ref.read(sosTrackingProvider(token).notifier);
      trackingNotifier.simulateIncomingEvent('assistance_accepted', {
        'responder_id': 'resp_demo_777',
        'responder_name': 'Volunteer Rajesh Kumar',
        'responder_phone': '+91 98765 43210',
        'eta_seconds': 180,
      });

      // Step 2: Responder begins travel (EN_ROUTE)
      await Future.delayed(const Duration(milliseconds: 3000));
      trackingNotifier.simulateIncomingEvent('responder_status_changed', {
        'responder_id': 'resp_demo_777',
        'status': 'EN_ROUTE',
        'latitude': 28.6160,
        'longitude': 77.2110,
      });

      // Step 3: Responder approaches victim (ARRIVED)
      await Future.delayed(const Duration(milliseconds: 3000));
      trackingNotifier.simulateIncomingEvent('responder_status_changed', {
        'responder_id': 'resp_demo_777',
        'status': 'ARRIVED',
        'latitude': 28.6139,
        'longitude': 77.2090,
      });

      ref.read(notificationsProvider.notifier).addNotification(
        title: 'Responder Has Arrived',
        body: 'Volunteer Rajesh Kumar has arrived at your location.',
        category: 'COMMUNITY',
      );

    } catch (e) {
      // Catch layout interruption errors
    } finally {
      if (mounted) {
        setState(() {
          _isSimulatingResponder = false;
        });
      }
    }
  }

  void _simulateDisasterAlert() {
    ref.read(notificationsProvider.notifier).addNotification(
      title: 'Disaster Warning: Severe Flood',
      body: 'Flash floods warnings near Yamuna River Basin. Evacuate low-lying areas.',
      category: 'DISASTER',
    );

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Disaster alert simulation triggered.'),
        backgroundColor: Colors.purple,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Developer Simulation Controller'),
        backgroundColor: Colors.grey.shade900,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Warning Banner
            Card(
              color: Colors.amber.shade50,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Row(
                  children: [
                    const Icon(Icons.bug_report, color: Colors.amber, size: 36),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Developer Simulation Mode',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Colors.amber.shade900,
                              fontSize: 14,
                            ),
                          ),
                          const SizedBox(height: 2),
                          const Text(
                            'Use these controls to simulate emergency triggers, telemetry warnings, and responder WS dispatcher streams.',
                            style: TextStyle(color: Colors.black87, fontSize: 11),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),

            // SOS Simulation Section
            _buildDemoCard(
              title: 'SOS Emergency Signaling',
              icon: Icons.emergency,
              color: AppTheme.accentSosRed,
              description: 'Trigger simulated panic signals directly, raising overlays and starting live broadcast feeds.',
              button: ElevatedButton.icon(
                onPressed: _simulateSosTrigger,
                style: ElevatedButton.styleFrom(backgroundColor: AppTheme.accentSosRed),
                icon: const Icon(Icons.play_arrow),
                label: const Text('Simulate SOS Trigger'),
              ),
            ),
            const SizedBox(height: 16),

            // Responder Dispatch Simulation Section
            _buildDemoCard(
              title: 'Responder Dispatch Lifecycles',
              icon: Icons.medical_services,
              color: AppTheme.successColor,
              description: 'Auto triggers SOS tracking map and feeds mock responder events (DISPATCHED -> EN_ROUTE -> ARRIVED).',
              button: ElevatedButton.icon(
                onPressed: _isSimulatingResponder ? null : _simulateResponderAcceptance,
                style: ElevatedButton.styleFrom(backgroundColor: AppTheme.successColor),
                icon: _isSimulatingResponder
                    ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                    : const Icon(Icons.airport_shuttle),
                label: Text(_isSimulatingResponder ? 'Simulating...' : 'Simulate Responder accepted'),
              ),
            ),
            const SizedBox(height: 16),

            // Travel Deviation Simulation Section
            _buildDemoCard(
              title: 'Travel Route Deviation',
              icon: Icons.directions_run,
              color: AppTheme.warningColor,
              description: 'Activates travel simulation, pushes path coordinates off route, and issues travel warnings.',
              button: ElevatedButton.icon(
                onPressed: _simulateTravelDeviation,
                style: ElevatedButton.styleFrom(backgroundColor: AppTheme.warningColor),
                icon: const Icon(Icons.gps_fixed),
                label: const Text('Simulate Route Deviation'),
              ),
            ),
            const SizedBox(height: 16),

            // Disaster Alerts Section
            _buildDemoCard(
              title: 'Regional Disaster warning',
              icon: Icons.warning_amber,
              color: Colors.purple.shade700,
              description: 'Generates critical flash flood alert, displays top banner warnings, and links to disasters feed.',
              button: ElevatedButton.icon(
                onPressed: _simulateDisasterAlert,
                style: ElevatedButton.styleFrom(backgroundColor: Colors.purple.shade700),
                icon: const Icon(Icons.cloud_outlined),
                label: const Text('Simulate Disaster Alert'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDemoCard({
    required String title,
    required IconData icon,
    required Color color,
    required String description,
    required Widget button,
  }) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: color.withOpacity(0.1),
                  child: Icon(icon, color: color, size: 24),
                ),
                const SizedBox(width: 12),
                Text(
                  title,
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              description,
              style: const TextStyle(color: Colors.grey, fontSize: 12),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: button,
            ),
          ],
        ),
      ),
    );
  }
}
