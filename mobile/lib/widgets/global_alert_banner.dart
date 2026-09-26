import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../models/notification_model.dart';
import '../providers/active_banner_provider.dart';
import '../providers/notifications_provider.dart';
import '../core/theme/app_theme.dart';

class GlobalAlertBanner extends ConsumerStatefulWidget {
  const GlobalAlertBanner({Key? key}) : super(key: key);

  @override
  ConsumerState<GlobalAlertBanner> createState() => _GlobalAlertBannerState();
}

class _GlobalAlertBannerState extends ConsumerState<GlobalAlertBanner> {
  NotificationModel? _displayedBanner;

  @override
  Widget build(BuildContext context) {
    final activeBanner = ref.watch(activeBannerProvider);
    if (activeBanner != null) {
      _displayedBanner = activeBanner;
    }

    final isVisible = activeBanner != null;
    final safeAreaTop = MediaQuery.of(context).padding.top;

    return AnimatedPositioned(
      duration: const Duration(milliseconds: 400),
      curve: Curves.fastOutSlowIn,
      top: isVisible ? safeAreaTop + 12 : -180.0,
      left: 16,
      right: 16,
      child: _displayedBanner != null
          ? _BannerCard(
              banner: _displayedBanner!,
              onDismiss: () {
                ref.read(activeBannerProvider.notifier).dismiss();
              },
              onTap: () {
                final banner = _displayedBanner!;
                ref.read(notificationsProvider.notifier).markAsRead(banner.id);
                ref.read(activeBannerProvider.notifier).dismiss();
                
                // Route navigation based on type
                if (banner.category == 'SOS') {
                  final token = banner.payload['secure_token'] ?? '';
                  if (token.isNotEmpty) {
                    context.push('/sos-tracking/$token');
                  }
                } else if (banner.category == 'TRAVEL') {
                  context.push('/travel-mode');
                } else if (banner.category == 'COMMUNITY') {
                  context.push('/responder-dispatch');
                } else if (banner.category == 'DISASTER') {
                  context.push('/disaster-alerts');
                }
              },
            )
          : const SizedBox.shrink(),
    );
  }
}

class _BannerCard extends StatelessWidget {
  final NotificationModel banner;
  final VoidCallback onDismiss;
  final VoidCallback onTap;

  const _BannerCard({
    Key? key,
    required this.banner,
    required this.onDismiss,
    required this.onTap,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    Color cardBgColor = AppTheme.primaryBlue;
    IconData icon = Icons.notifications;
    String headerText = 'ALERT';

    switch (banner.category) {
      case 'SOS':
        cardBgColor = AppTheme.accentSosRed;
        icon = Icons.emergency_share;
        headerText = 'SOS EMERGENCY SIGNAL';
        break;
      case 'TRAVEL':
        cardBgColor = AppTheme.warningColor;
        icon = Icons.directions_run;
        headerText = 'TRAVEL DEVIATION WARNING';
        break;
      case 'COMMUNITY':
        cardBgColor = AppTheme.successColor;
        icon = Icons.medical_services;
        headerText = 'COMMUNITY RESPONDER ACCEPTED';
        break;
      case 'DISASTER':
        cardBgColor = Colors.purple.shade700;
        icon = Icons.warning_amber_rounded;
        headerText = 'REGIONAL DISASTER ALERT';
        break;
    }

    return Card(
      elevation: 8,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      clipBehavior: Clip.antiAlias,
      child: Material(
        color: cardBgColor,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
            child: Row(
              children: [
                Icon(icon, color: Colors.white, size: 28),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        headerText,
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 10,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 1.0,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        banner.title,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        banner.body,
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 12,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  icon: const Icon(Icons.close, color: Colors.white70, size: 20),
                  onPressed: onDismiss,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
