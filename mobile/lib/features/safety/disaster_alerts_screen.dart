import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/app_theme.dart';

class DisasterAlertsScreen extends ConsumerWidget {
  const DisasterAlertsScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);

    // Mock data for regional warnings matching backend disaster specifications
    final List<Map<String, dynamic>> mockDisasters = [
      {
        'title': 'Severe Flash Flood Warning',
        'region': 'Yamuna River Basin, North Delhi',
        'severity': 'CRITICAL',
        'radius': '3.5 km',
        'issued_at': '2026-06-22T20:30:00Z',
        'instructions': [
          'Evacuate low-lying riverside communities immediately.',
          'Store drinking water and charge auxiliary backup power packs.',
          'Avoid walking or driving through moving water currents.'
        ]
      },
      {
        'title': 'Thunderstorm & Lightning Warning',
        'region': 'Connaught Place & Central District',
        'severity': 'MODERATE',
        'radius': '5.0 km',
        'issued_at': '2026-06-22T21:15:00Z',
        'instructions': [
          'Stay indoors and avoid electrical outlet connectors.',
          'Unplug sensitive computer electronics and appliances.',
          'Do not take shelter under tall trees or metal scaffolds.'
        ]
      }
    ];

    return Scaffold(
      appBar: AppBar(
        title: const Text('Disaster Warnings & Feeds'),
        backgroundColor: Colors.purple.shade700,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Safety Header Card
            Card(
              elevation: 4,
              color: Colors.purple.shade50,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Row(
                  children: [
                    Icon(Icons.gpp_good, color: Colors.purple.shade800, size: 36),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Regional Safety Status',
                            style: TextStyle(
                              color: Colors.purple.shade900,
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                          const SizedBox(height: 2),
                          const Text(
                            'Saathi Shield automatically scans active warnings within your immediate geolocation radius.',
                            style: TextStyle(color: Colors.black87, fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),

            const Text(
              'ACTIVE DISASTER ALERTS',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 12,
                letterSpacing: 1.0,
                color: Colors.grey,
              ),
            ),
            const SizedBox(height: 10),

            // Disasters List
            ...mockDisasters.map((disaster) => _buildDisasterCard(disaster, theme)).toList(),

            const SizedBox(height: 24),
            // Safety Guidelines Section
            const Text(
              'GENERAL DISASTER PREPAREDNESS TIPS',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 12,
                letterSpacing: 1.0,
                color: Colors.grey,
              ),
            ),
            const SizedBox(height: 12),
            _buildSafetyTip(
              icon: Icons.backpack_outlined,
              title: 'Keep a Go-Bag Ready',
              desc: 'Store emergency medical kits, high-calorie bars, water filters, and flashlights.',
            ),
            _buildSafetyTip(
              icon: Icons.contact_emergency_outlined,
              title: 'Confirm Emergency Plans',
              desc: 'Keep emergency contact lists up-to-date and define physical fallback meetup spots.',
            ),
            _buildSafetyTip(
              icon: Icons.battery_charging_full_outlined,
              title: 'Power and Telemetries',
              desc: 'Keep phone batteries fully charged when storm forecasts are issued.',
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDisasterCard(Map<String, dynamic> disaster, ThemeData theme) {
    final severity = disaster['severity'] as String;
    final isCritical = severity == 'CRITICAL';

    final Color badgeColor = isCritical ? AppTheme.accentSosRed : AppTheme.warningColor;
    final List<dynamic> instructions = disaster['instructions'];

    return Card(
      elevation: 4,
      margin: const EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    disaster['title'],
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: badgeColor.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    severity,
                    style: TextStyle(color: badgeColor, fontWeight: FontWeight.bold, fontSize: 11),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(Icons.location_on, color: Colors.grey, size: 16),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    disaster['region'],
                    style: const TextStyle(color: Colors.grey, fontSize: 12),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                const Icon(Icons.radar, color: Colors.grey, size: 16),
                const SizedBox(width: 4),
                Text(
                  'Impact Radius: ${disaster['radius']}',
                  style: const TextStyle(color: Colors.grey, fontSize: 12),
                ),
              ],
            ),
            const Divider(height: 24),
            
            const Text(
              'SAFETY PROTOCOLS:',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, letterSpacing: 0.5, color: Colors.grey),
            ),
            const SizedBox(height: 8),
            ...instructions.map((inst) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 4.0),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.arrow_forward_ios, size: 12, color: Colors.purple.shade600),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      inst,
                      style: const TextStyle(fontSize: 13),
                    ),
                  ),
                ],
              ),
            )).toList(),

            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: () {},
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.purple.shade700,
                foregroundColor: Colors.white,
                minimumSize: const Size(double.infinity, 44),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              icon: const Icon(Icons.check_circle_outline, size: 18),
              label: const Text('Mark Myself As Safe'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSafetyTip({required IconData icon, required String title, required String desc}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            backgroundColor: Colors.purple.withOpacity(0.08),
            child: Icon(icon, color: Colors.purple.shade700, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                ),
                const SizedBox(height: 2),
                Text(
                  desc,
                  style: const TextStyle(color: Colors.grey, fontSize: 12),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
