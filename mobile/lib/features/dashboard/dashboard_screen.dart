import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart';
import '../../../core/theme/app_theme.dart';
import '../../../providers/auth_provider.dart';
import '../../../providers/theme_provider.dart';
import '../../providers/sos_provider.dart';
import '../../providers/connectivity_provider.dart';
import '../../providers/notifications_provider.dart';
import '../../widgets/offline_banner.dart';

class DashboardScreen extends ConsumerStatefulWidget {
  const DashboardScreen({Key? key}) : super(key: key);

  @override
  ConsumerState<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends ConsumerState<DashboardScreen> with SingleTickerProviderStateMixin {
  late AnimationController _sosAnimController;

  // Standard coordinates for New Delhi center as default view
  final LatLng _defaultLocation = const LatLng(28.6139, 77.2090);

  @override
  void initState() {
    super.initState();
    // SOS button pulsing animation setup
    _sosAnimController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 1),
      lowerBound: 0.85,
      upperBound: 1.0,
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _sosAnimController.dispose();
    super.dispose();
  }

  void _triggerSosEmergency() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Row(
            children: const [
              Icon(Icons.warning_amber_rounded, color: AppTheme.accentSosRed, size: 28),
              SizedBox(width: 8),
              Text('Trigger SOS Alert?'),
            ],
          ),
          content: const Text(
            'This will dispatch an active emergency warning to all registered responders within 2km and alert your saved emergency contacts.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop();
                // Real trigger SOS with default coordinates
                ref.read(sosProvider.notifier).triggerAlert(
                  latitude: _defaultLocation.latitude,
                  longitude: _defaultLocation.longitude,
                );
              },
              style: ElevatedButton.styleFrom(backgroundColor: AppTheme.accentSosRed),
              child: const Text('Dispatch SOS'),
            ),
          ],
        );
      },
    );
  }

  void _resolveSosEmergency(BuildContext context) {
    bool isFalseAlarm = false;
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: const Text('Resolve SOS Alert'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('Are you safe now? This will stop tracking your live location and close the incident.'),
                  const SizedBox(height: 16),
                  CheckboxListTile(
                    title: const Text('This was a false alarm'),
                    value: isFalseAlarm,
                    onChanged: (val) {
                      if (val != null) {
                        setState(() {
                          isFalseAlarm = val;
                        });
                      }
                    },
                    controlAffinity: ListTileControlAffinity.leading,
                    contentPadding: EdgeInsets.zero,
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: () {
                    Navigator.of(context).pop(true);
                  },
                  style: ElevatedButton.styleFrom(backgroundColor: AppTheme.successColor),
                  child: const Text('Resolve Incident'),
                ),
              ],
            );
          },
        );
      },
    ).then((confirmed) {
      if (confirmed == true) {
        ref.read(sosProvider.notifier).resolveAlert(isFalseAlarm: isFalseAlarm);
      }
    });
  }

  String _formatTime(int seconds) {
    final int m = seconds ~/ 60;
    final int s = seconds % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);
    final themeMode = ref.watch(themeProvider);
    final sosState = ref.watch(sosProvider);
    final connState = ref.watch(connectivityProvider);
    final theme = Theme.of(context);

    // Watch for SOS errors
    ref.listen<SosState>(sosProvider, (previous, next) {
      if (next.errorMessage != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(next.errorMessage!),
            backgroundColor: AppTheme.errorColor,
          ),
        );
        ref.read(sosProvider.notifier).clearError();
      }

      if (next.isActive && (previous == null || !previous.isActive)) {
        final alert = next.activeAlert!;
        
        // Add to notifications timeline
        ref.read(notificationsProvider.notifier).addNotification(
          title: 'SOS Emergency Signal Active',
          body: 'Emergency alert dispatched to responders. Broadcasting GPS coordinates.',
          category: 'SOS',
          payload: {'secure_token': alert.secureToken},
          showBanner: true,
        );

        // Auto navigate to tracking screen
        context.push('/sos-tracking/${alert.secureToken}');
      }
    });

    // Retrieve user parameters
    String userName = 'Guest User';
    String userRole = 'USER';
    String userPhone = '';

    if (authState is Authenticated) {
      userName = '${authState.user.firstName} ${authState.user.lastName}';
      userRole = authState.user.role;
      userPhone = authState.user.phone;
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Saathi Shield Dashboard'),
        actions: [
          IconButton(
            icon: Icon(themeMode == ThemeMode.dark ? Icons.light_mode : Icons.dark_mode),
            onPressed: () => ref.read(themeProvider.notifier).toggleTheme(),
          ),
          Consumer(
            builder: (context, ref, child) {
              final unreadCount = ref.watch(unreadNotificationsCountProvider);
              return Stack(
                alignment: Alignment.center,
                children: [
                  IconButton(
                    icon: const Icon(Icons.notifications_outlined),
                    onPressed: () => context.push('/notifications'),
                  ),
                  if (unreadCount > 0)
                    Positioned(
                      right: 8,
                      top: 8,
                      child: Container(
                        padding: const EdgeInsets.all(2),
                        decoration: const BoxDecoration(
                          color: AppTheme.accentSosRed,
                          shape: BoxShape.circle,
                        ),
                        constraints: const BoxConstraints(
                          minWidth: 16,
                          minHeight: 16,
                        ),
                        child: Text(
                          '$unreadCount',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 8,
                            fontWeight: FontWeight.bold,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),
                ],
              );
            },
          ),
        ],
      ),
      drawer: Drawer(
        child: Column(
          children: [
            UserAccountsDrawerHeader(
              decoration: const BoxDecoration(color: AppTheme.primaryBlue),
              currentAccountPicture: CircleAvatar(
                backgroundColor: Colors.white,
                child: Icon(Icons.person, size: 40, color: theme.primaryColor),
              ),
              accountName: Text(userName, style: const TextStyle(fontWeight: FontWeight.bold)),
              accountEmail: Text(userPhone),
            ),
            ListTile(
              leading: const Icon(Icons.shield_outlined),
              title: const Text('Safety/Medical Profile'),
              onTap: () {
                Navigator.of(context).pop();
                context.push('/medical-profile');
              },
            ),
            ListTile(
              leading: const Icon(Icons.contacts_outlined),
              title: const Text('Emergency Contacts'),
              onTap: () {
                Navigator.of(context).pop();
                context.push('/emergency-contacts');
              },
            ),
            ListTile(
              leading: const Icon(Icons.history_outlined),
              title: const Text('Travel History'),
              onTap: () {
                Navigator.of(context).pop();
              },
            ),
            ListTile(
              leading: const Icon(Icons.directions_run_outlined),
              title: const Text('Safe Travel Protection'),
              onTap: () {
                Navigator.of(context).pop();
                context.push('/travel-mode');
              },
            ),
            if (sosState.isActive)
              ListTile(
                leading: const Icon(Icons.map_outlined, color: AppTheme.accentSosRed),
                title: const Text('Live SOS Tracking', style: TextStyle(color: AppTheme.accentSosRed, fontWeight: FontWeight.bold)),
                onTap: () {
                  Navigator.of(context).pop();
                  context.push('/sos-tracking/${sosState.activeAlert!.secureToken}');
                },
              ),
            if (userRole == 'RESPONDER')
              ListTile(
                leading: const Icon(Icons.medical_services_outlined, color: Colors.green),
                title: const Text('Community Alert Dashboard', style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold)),
                onTap: () {
                  Navigator.of(context).pop();
                  context.push('/community-dashboard');
                },
              ),
            ListTile(
              leading: const Icon(Icons.notifications_none_outlined),
              title: Consumer(
                builder: (context, ref, child) {
                  final unreadCount = ref.watch(unreadNotificationsCountProvider);
                  return Row(
                    children: [
                      const Text('Notification Center'),
                      if (unreadCount > 0) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: const BoxDecoration(
                            color: AppTheme.accentSosRed,
                            shape: BoxShape.circle,
                          ),
                          child: Text(
                            '$unreadCount',
                            style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ],
                    ],
                  );
                },
              ),
              onTap: () {
                Navigator.of(context).pop();
                context.push('/notifications');
              },
            ),
            ListTile(
              leading: const Icon(Icons.warning_amber_outlined, color: Colors.purple),
              title: const Text('Regional Disaster Alerts', style: TextStyle(color: Colors.purple)),
              onTap: () {
                Navigator.of(context).pop();
                context.push('/disaster-alerts');
              },
            ),
            ListTile(
              leading: const Icon(Icons.bug_report_outlined, color: Colors.amber),
              title: const Text('Demo Simulation Controls', style: TextStyle(color: Colors.amber)),
              onTap: () {
                Navigator.of(context).pop();
                context.push('/demo-controller');
              },
            ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.logout, color: AppTheme.errorColor),
              title: const Text('Log Out', style: TextStyle(color: AppTheme.errorColor)),
              onTap: () {
                Navigator.of(context).pop();
                ref.read(authProvider.notifier).logout();
              },
            ),
            const Divider(),
            ListTile(
              leading: Icon(
                connState.isOnline ? Icons.signal_wifi_4_bar : Icons.signal_wifi_off,
                color: connState.isOnline ? Colors.green : Colors.orange,
              ),
              title: Text(connState.isOnline ? 'Network: Online' : 'Network: Offline (Mock)'),
              subtitle: const Text('Tap to toggle network mock status'),
              onTap: () {
                Navigator.of(context).pop();
                ref.read(connectivityProvider.notifier).toggleNetworkMock();
              },
            ),
            const Spacer(),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                'Saathi Shield v1.0.0',
                style: theme.textTheme.bodySmall?.copyWith(color: Colors.grey),
              ),
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          const OfflineBanner(),
          Expanded(
            child: Stack(
              children: [
                // OpenStreetMap Widget Integration
                FlutterMap(
            options: MapOptions(
              initialCenter: _defaultLocation,
              initialZoom: 14.0,
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.saathishield.app',
              ),
              // User Marker representation
              MarkerLayer(
                markers: [
                  Marker(
                    point: _defaultLocation,
                    width: 60,
                    height: 60,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: theme.primaryColor.withOpacity(0.2),
                            shape: BoxShape.circle,
                          ),
                        ),
                        Container(
                          width: 20,
                          height: 20,
                          decoration: BoxDecoration(
                            color: theme.primaryColor,
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 2),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),

          // User Dashboard Quick Stats Panel
          Positioned(
            top: 16,
            left: 16,
            right: 16,
            child: Card(
              elevation: 4,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Row(
                  children: [
                    CircleAvatar(
                      backgroundColor: userRole == 'RESPONDER' ? Colors.green.shade100 : Colors.blue.shade100,
                      child: Icon(
                        userRole == 'RESPONDER' ? Icons.medical_services_outlined : Icons.shield_outlined,
                        color: userRole == 'RESPONDER' ? Colors.green.shade800 : theme.primaryColor,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            userName,
                            style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                          ),
                          Text(
                            userRole == 'RESPONDER' ? 'Active Responder Duty' : 'GPS Shield Protection Active',
                            style: theme.textTheme.bodySmall?.copyWith(color: Colors.grey),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: sosState.isActive
                            ? AppTheme.accentSosRed.withOpacity(0.2)
                            : Colors.green.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        sosState.isActive ? 'EMERGENCY' : 'SECURE',
                        style: TextStyle(
                          color: sosState.isActive ? AppTheme.accentSosRed : Colors.green,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                    )
                  ],
                ),
              ),
            ),
          ),

          // Pulsing SOS trigger (Only visible when SOS is NOT active)
          if (!sosState.isActive)
            Positioned(
              bottom: 32,
              left: 0,
              right: 0,
              child: Center(
                child: ScaleTransition(
                  scale: _sosAnimController,
                  child: GestureDetector(
                    onTap: _triggerSosEmergency,
                    child: Container(
                      height: 110,
                      width: 110,
                      decoration: BoxDecoration(
                        color: AppTheme.accentSosRed,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: AppTheme.accentSosRed.withOpacity(0.5),
                            blurRadius: 20,
                            spreadRadius: 8,
                          ),
                        ],
                      ),
                      child: Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: const [
                            Icon(Icons.emergency, color: Colors.white, size: 38),
                            SizedBox(height: 2),
                            Text(
                              'SOS',
                              style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18, letterSpacing: 1),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),

          // SOS Active Overlay Panel (Only visible when SOS is active)
          if (sosState.isActive) ...[
            // Dimmed semi-transparent overlay
            Positioned.fill(
              child: Container(
                color: Colors.black.withOpacity(0.4),
              ),
            ),
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
                      color: Colors.black.withOpacity(0.3),
                      blurRadius: 15,
                      spreadRadius: 2,
                    )
                  ],
                ),
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Container(
                              width: 12,
                              height: 12,
                              decoration: const BoxDecoration(
                                color: AppTheme.accentSosRed,
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'SOS ALERT ACTIVE',
                              style: theme.textTheme.titleMedium?.copyWith(
                                color: AppTheme.accentSosRed,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ],
                        ),
                        Text(
                          _formatTime(sosState.elapsedSeconds),
                          style: const TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            fontFamily: 'Courier',
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Emergency responders and your trusted contacts have been notified. Your live location is currently being broadcasted securely.',
                      style: TextStyle(fontSize: 14),
                    ),
                    if (sosState.activeAlert?.trackingUrl != null &&
                        sosState.activeAlert!.trackingUrl.isNotEmpty) ...[
                      const SizedBox(height: 16),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: theme.brightness == Brightness.dark
                              ? const Color(0xFF2C2C2C)
                              : Colors.grey.shade100,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: theme.brightness == Brightness.dark
                                ? const Color(0xFF3C3C3C)
                                : Colors.grey.shade300,
                          ),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.link, size: 20, color: Colors.grey),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                sosState.activeAlert!.trackingUrl,
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: Colors.blue,
                                  decoration: TextDecoration.underline,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.copy, size: 18),
                              onPressed: () {
                                Clipboard.setData(
                                  ClipboardData(text: sosState.activeAlert!.trackingUrl),
                                );
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('Tracking link copied to clipboard.'),
                                    duration: Duration(seconds: 2),
                                  ),
                                );
                              },
                            ),
                          ],
                        ),
                      ),
                    ],
                    const SizedBox(height: 24),
                    ElevatedButton.icon(
                      onPressed: () {
                        context.push('/sos-tracking/${sosState.activeAlert!.secureToken}');
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.accentSosRed,
                        foregroundColor: Colors.white,
                        minimumSize: const Size(double.infinity, 50),
                      ),
                      icon: const Icon(Icons.map),
                      label: const Text('Open Real-Time Tracking Map'),
                    ),
                    const SizedBox(height: 12),
                    ElevatedButton.icon(
                      onPressed: () => _resolveSosEmergency(context),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.successColor,
                        foregroundColor: Colors.white,
                      ),
                      icon: const Icon(Icons.check_circle_outline),
                      label: const Text('Resolve Emergency (I\'m Safe)'),
                    ),
                  ],
                ),
              ),
            ),
          ],

                // Global loading indicator for SOS actions
                if (sosState.isLoading)
                  Container(
                    color: Colors.black.withOpacity(0.2),
                    child: const Center(
                      child: CircularProgressIndicator(),
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
