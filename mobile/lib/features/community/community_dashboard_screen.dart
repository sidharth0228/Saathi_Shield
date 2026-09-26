import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_theme.dart';
import '../../providers/community_provider.dart';

class CommunityDashboardScreen extends ConsumerStatefulWidget {
  const CommunityDashboardScreen({Key? key}) : super(key: key);

  @override
  ConsumerState<CommunityDashboardScreen> createState() => _CommunityDashboardScreenState();
}

class _CommunityDashboardScreenState extends ConsumerState<CommunityDashboardScreen> {
  String _filterTriggerType = 'ALL';
  String _sortBy = 'DISTANCE'; // DISTANCE, TIME

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(communityProvider);
    final theme = Theme.of(context);

    // Watch for active dispatch to automatically redirect to dispatch tracker screen
    ref.listen(communityProvider, (previous, next) {
      if (next.activeDispatch != null && previous?.activeDispatch == null) {
        context.pushReplacement('/responder-dispatch');
      }
    });

    // Listen for error messages
    ref.listen(communityProvider, (previous, next) {
      if (next.errorMessage != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(next.errorMessage!),
            backgroundColor: AppTheme.errorColor,
          ),
        );
        ref.read(communityProvider.notifier).clearError();
      }
    });

    // Apply sorting & filtering
    List<Map<String, dynamic>> filteredAlerts = List.from(state.nearbyAlerts);
    if (_filterTriggerType != 'ALL') {
      filteredAlerts = filteredAlerts
          .where((alert) => alert['trigger_type'] == _filterTriggerType)
          .toList();
    }

    if (_sortBy == 'DISTANCE') {
      filteredAlerts.sort((a, b) {
        final double distA = (a['distance_km'] as num?)?.toDouble() ?? 0.0;
        final double distB = (b['distance_km'] as num?)?.toDouble() ?? 0.0;
        return distA.compareTo(distB);
      });
    } else {
      // Sort by time descending (newest first)
      filteredAlerts.sort((a, b) {
        final timeA = DateTime.tryParse(a['created_at']?.toString() ?? '') ?? DateTime.now();
        final timeB = DateTime.tryParse(b['created_at']?.toString() ?? '') ?? DateTime.now();
        return timeB.compareTo(timeA);
      });
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Community Alert Dashboard'),
        backgroundColor: Colors.green.shade800,
        foregroundColor: Colors.white,
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Availability Toggle Banner
          Container(
            padding: const EdgeInsets.all(16.0),
            color: state.isAvailable 
                ? Colors.green.shade100 
                : Colors.grey.shade200,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(
                      state.isAvailable ? Icons.check_circle : Icons.offline_bolt_outlined,
                      color: state.isAvailable ? Colors.green.shade800 : Colors.grey,
                      size: 24,
                    ),
                    const SizedBox(width: 10),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          state.isAvailable ? 'Active & Available' : 'Offline Mode',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: state.isAvailable ? Colors.green.shade900 : Colors.grey.shade800,
                            fontSize: 15,
                          ),
                        ),
                        Text(
                          state.isAvailable 
                              ? 'Broadcasting position. Scanning alerts within 2km...'
                              : 'Go online to receive nearby emergency dispatches.',
                          style: TextStyle(
                            color: state.isAvailable ? Colors.green.shade700 : Colors.grey.shade600,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                Switch(
                  value: state.isAvailable,
                  activeColor: Colors.green.shade800,
                  onChanged: (val) {
                    ref.read(communityProvider.notifier).toggleAvailability(val);
                  },
                ),
              ],
            ),
          ),

          if (state.isAvailable) ...[
            // Filter / Sort Options Bar
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      const Text('Filter: ', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                      DropdownButton<String>(
                        value: _filterTriggerType,
                        style: const TextStyle(fontSize: 12, color: Colors.blue),
                        underline: Container(),
                        items: const [
                          DropdownMenuItem(value: 'ALL', child: Text('All Alerts')),
                          DropdownMenuItem(value: 'ONE_TAP_SOS', child: Text('SOS Button')),
                          DropdownMenuItem(value: 'ROUTE_DEVIATION', child: Text('Deviations')),
                        ],
                        onChanged: (val) {
                          if (val != null) {
                            setState(() {
                              _filterTriggerType = val;
                            });
                          }
                        },
                      ),
                    ],
                  ),
                  Row(
                    children: [
                      const Text('Sort by: ', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                      DropdownButton<String>(
                        value: _sortBy,
                        style: const TextStyle(fontSize: 12, color: Colors.blue),
                        underline: Container(),
                        items: const [
                          DropdownMenuItem(value: 'DISTANCE', child: Text('Distance')),
                          DropdownMenuItem(value: 'TIME', child: Text('Recency')),
                        ],
                        onChanged: (val) {
                          if (val != null) {
                            setState(() {
                              _sortBy = val;
                            });
                          }
                        },
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const Divider(height: 1),

            // Nearby Alerts Directory List
            Expanded(
              child: state.isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : filteredAlerts.isEmpty
                      ? Center(
                          child: Padding(
                            padding: const EdgeInsets.all(24.0),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: const [
                                Icon(Icons.security, size: 80, color: Colors.grey),
                                SizedBox(height: 16),
                                Text(
                                  'Area Fully Secure',
                                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                                ),
                                SizedBox(height: 8),
                                Text(
                                  'No active emergency alerts reported within 2km of your location.',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(color: Colors.grey, fontSize: 13),
                                ),
                              ],
                            ),
                          ),
                        )
                      : ListView.builder(
                          itemCount: filteredAlerts.length,
                          padding: const EdgeInsets.all(12),
                          itemBuilder: (context, index) {
                            final alert = filteredAlerts[index];
                            final double distance = (alert['distance_km'] as num?)?.toDouble() ?? 0.0;
                            final String alertId = alert['alert_id'] ?? '';
                            final String type = alert['trigger_type'] ?? 'SOS';

                            return Card(
                              margin: const EdgeInsets.symmetric(vertical: 6),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: Padding(
                                padding: const EdgeInsets.all(16.0),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.stretch,
                                  children: [
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                          decoration: BoxDecoration(
                                            color: AppTheme.accentSosRed.withOpacity(0.1),
                                            borderRadius: BorderRadius.circular(8),
                                          ),
                                          child: Text(
                                            type,
                                            style: const TextStyle(
                                              color: AppTheme.accentSosRed,
                                              fontWeight: FontWeight.bold,
                                              fontSize: 11,
                                            ),
                                          ),
                                        ),
                                        Text(
                                          '${distance.toStringAsFixed(2)} km away',
                                          style: const TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 13,
                                            color: Colors.grey,
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 12),
                                    Text(
                                      'Victim: ${alert['user_name']}',
                                      style: const TextStyle(
                                        fontSize: 15,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      'Triggered: ${alert['created_at'] != null ? DateTime.tryParse(alert['created_at'].toString())?.toLocal().toString().split('.')[0] : '--'}',
                                      style: const TextStyle(fontSize: 11, color: Colors.grey),
                                    ),
                                    const SizedBox(height: 16),
                                    Row(
                                      children: [
                                        Expanded(
                                          child: OutlinedButton(
                                            onPressed: () {},
                                            child: const Text('Reject'),
                                          ),
                                        ),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: ElevatedButton.icon(
                                            onPressed: () {
                                              ref.read(communityProvider.notifier).acceptEmergency(alertId);
                                            },
                                            style: ElevatedButton.styleFrom(
                                              backgroundColor: Colors.green.shade800,
                                              foregroundColor: Colors.white,
                                            ),
                                            icon: const Icon(Icons.check),
                                            label: const Text('Accept & Dispatch'),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
            ),
          ] else ...[
            const Expanded(
              child: Center(
                child: Padding(
                  padding: EdgeInsets.all(24.0),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.lock_outline, size: 80, color: Colors.grey),
                      SizedBox(height: 16),
                      Text(
                        'Dashboard Offline',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                      ),
                      SizedBox(height: 8),
                      Text(
                        'Toggle the availability switch above to go online and fetch emergency requests.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.grey, fontSize: 13),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
