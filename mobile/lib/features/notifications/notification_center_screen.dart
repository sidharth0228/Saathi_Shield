import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/app_theme.dart';
import '../../models/notification_model.dart';
import '../../providers/notifications_provider.dart';

class NotificationCenterScreen extends ConsumerStatefulWidget {
  const NotificationCenterScreen({Key? key}) : super(key: key);

  @override
  ConsumerState<NotificationCenterScreen> createState() => _NotificationCenterScreenState();
}

class _NotificationCenterScreenState extends ConsumerState<NotificationCenterScreen> {
  String _selectedCategory = 'All';

  @override
  Widget build(BuildContext context) {
    final notifications = ref.watch(notificationsProvider);
    final theme = Theme.of(context);

    // Apply category filtering
    final filteredNotifications = notifications.where((notification) {
      if (_selectedCategory == 'All') return true;
      if (_selectedCategory == 'SOS Alerts' && notification.category == 'SOS') return true;
      if (_selectedCategory == 'Travel Alerts' && notification.category == 'TRAVEL') return true;
      if (_selectedCategory == 'Community Alerts' && notification.category == 'COMMUNITY') return true;
      if (_selectedCategory == 'Disaster Alerts' && notification.category == 'DISASTER') return true;
      return false;
    }).toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Emergency Notification Center'),
        backgroundColor: AppTheme.primaryBlue,
        foregroundColor: Colors.white,
        actions: [
          if (notifications.any((n) => !n.isRead))
            TextButton.icon(
              icon: const Icon(Icons.mark_chat_read, color: Colors.white, size: 18),
              label: const Text('Read All', style: TextStyle(color: Colors.white, fontSize: 12)),
              onPressed: () {
                ref.read(notificationsProvider.notifier).markAllAsRead();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('All notifications marked as read.')),
                );
              },
            ),
        ],
      ),
      body: Column(
        children: [
          // Filter Chips Row
          _buildFilterChips(theme),
          const Divider(height: 1),
          
          // Timeline list of notifications
          Expanded(
            child: filteredNotifications.isEmpty
                ? _buildEmptyState(theme)
                : _buildTimelineList(filteredNotifications, theme),
          ),
        ],
      ),
      bottomNavigationBar: notifications.isNotEmpty
          ? Padding(
              padding: const EdgeInsets.all(16.0),
              child: OutlinedButton.icon(
                onPressed: () {
                  ref.read(notificationsProvider.notifier).clearAll();
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Notifications cleared.')),
                  );
                },
                icon: const Icon(Icons.delete_outline, color: AppTheme.errorColor),
                label: const Text('Clear All Notifications', style: TextStyle(color: AppTheme.errorColor)),
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: AppTheme.errorColor),
                  minimumSize: const Size(double.infinity, 48),
                ),
              ),
            )
          : null,
    );
  }

  Widget _buildFilterChips(ThemeData theme) {
    final categories = ['All', 'SOS Alerts', 'Travel Alerts', 'Community Alerts', 'Disaster Alerts'];

    return Container(
      height: 60,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        itemCount: categories.length,
        itemBuilder: (context, index) {
          final cat = categories[index];
          final isSelected = _selectedCategory == cat;
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4.0),
            child: ChoiceChip(
              label: Text(cat),
              selected: isSelected,
              selectedColor: AppTheme.primaryBlue,
              labelStyle: TextStyle(
                color: isSelected
                    ? Colors.white
                    : (theme.brightness == Brightness.dark
                        ? Colors.white70
                        : Colors.black87),
              ),
              onSelected: (selected) {
                if (selected) {
                  setState(() {
                    _selectedCategory = cat;
                  });
                }
              },
            ),
          );
        },
      ),
    );
  }

  Widget _buildEmptyState(ThemeData theme) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.notifications_off_outlined,
            size: 80,
            color: theme.brightness == Brightness.dark ? Colors.grey.shade700 : Colors.grey.shade300,
          ),
          const SizedBox(height: 16),
          Text(
            'No notifications found',
            style: theme.textTheme.titleMedium?.copyWith(
              color: theme.brightness == Brightness.dark ? Colors.grey.shade400 : Colors.grey.shade600,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'All clear! Alerts will show up here as they occur.',
            style: theme.textTheme.bodySmall?.copyWith(color: Colors.grey),
          ),
        ],
      ),
    );
  }

  Widget _buildTimelineList(List<NotificationModel> list, ThemeData theme) {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: list.length,
      itemBuilder: (context, index) {
        final item = list[index];
        return _NotificationTimelineCard(
          notification: item,
          theme: theme,
          onTap: () {
            ref.read(notificationsProvider.notifier).markAsRead(item.id);
            
            // Redirect logic
            if (item.category == 'SOS') {
              final token = item.payload['secure_token'] ?? '';
              if (token.isNotEmpty) {
                context.push('/sos-tracking/$token');
              }
            } else if (item.category == 'TRAVEL') {
              context.push('/travel-mode');
            } else if (item.category == 'COMMUNITY') {
              context.push('/responder-dispatch');
            } else if (item.category == 'DISASTER') {
              context.push('/disaster-alerts');
            }
          },
        );
      },
    );
  }
}

class _NotificationTimelineCard extends StatelessWidget {
  final NotificationModel notification;
  final ThemeData theme;
  final VoidCallback onTap;

  const _NotificationTimelineCard({
    Key? key,
    required this.notification,
    required this.theme,
    required this.onTap,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    Color indicatorColor = AppTheme.primaryBlue;
    IconData icon = Icons.notifications;

    switch (notification.category) {
      case 'SOS':
        indicatorColor = AppTheme.accentSosRed;
        icon = Icons.emergency;
        break;
      case 'TRAVEL':
        indicatorColor = AppTheme.warningColor;
        icon = Icons.directions_run;
        break;
      case 'COMMUNITY':
        indicatorColor = AppTheme.successColor;
        icon = Icons.medical_services;
        break;
      case 'DISASTER':
        indicatorColor = Colors.purple;
        icon = Icons.warning_amber_rounded;
        break;
    }

    final formattedDate = _formatTimestamp(notification.timestamp);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Left Timeline Accent line
            Column(
              children: [
                Container(
                  width: 14,
                  height: 14,
                  decoration: BoxDecoration(
                    color: indicatorColor,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 2),
                    boxShadow: [
                      BoxShadow(
                        color: indicatorColor.withOpacity(0.4),
                        blurRadius: 4,
                        spreadRadius: 1,
                      )
                    ],
                  ),
                ),
                Expanded(
                  child: Container(
                    width: 2,
                    color: Colors.grey.withOpacity(0.3),
                  ),
                ),
              ],
            ),
            const SizedBox(width: 16),
            // Right Notification Card
            Expanded(
              child: Card(
                elevation: notification.isRead ? 1 : 3,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                color: notification.isRead 
                    ? (theme.brightness == Brightness.dark ? const Color(0xFF242424) : Colors.grey.shade50)
                    : (theme.brightness == Brightness.dark ? const Color(0xFF2C2C2C) : Colors.white),
                clipBehavior: Clip.antiAlias,
                child: InkWell(
                  onTap: onTap,
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        CircleAvatar(
                          backgroundColor: indicatorColor.withOpacity(0.1),
                          child: Icon(icon, color: indicatorColor, size: 20),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    notification.category,
                                    style: TextStyle(
                                      color: indicatorColor,
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                      letterSpacing: 0.5,
                                    ),
                                  ),
                                  Text(
                                    formattedDate,
                                    style: const TextStyle(color: Colors.grey, fontSize: 10),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Text(
                                notification.title,
                                style: TextStyle(
                                  fontWeight: notification.isRead ? FontWeight.normal : FontWeight.bold,
                                  fontSize: 14,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                notification.body,
                                style: TextStyle(
                                  color: theme.brightness == Brightness.dark ? Colors.white70 : Colors.black54,
                                  fontSize: 12,
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
            ),
          ],
        ),
      ),
    );
  }

  String _formatTimestamp(DateTime time) {
    final now = DateTime.now();
    final diff = now.difference(time);

    if (diff.inMinutes < 1) {
      return 'Just now';
    } else if (diff.inMinutes < 60) {
      return '${diff.inMinutes}m ago';
    } else if (diff.inHours < 24) {
      return '${diff.inHours}h ago';
    } else {
      return '${time.day}/${time.month}';
    }
  }
}
