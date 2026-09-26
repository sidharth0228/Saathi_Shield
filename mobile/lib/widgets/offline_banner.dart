import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/connectivity_provider.dart';
import '../core/theme/app_theme.dart';

class OfflineBanner extends ConsumerStatefulWidget {
  const OfflineBanner({Key? key}) : super(key: key);

  @override
  ConsumerState<OfflineBanner> createState() => _OfflineBannerState();
}

class _OfflineBannerState extends ConsumerState<OfflineBanner> {
  bool _showOnlineSyncing = false;
  bool _wasOffline = false;
  Timer? _hideTimer;

  @override
  void dispose() {
    _hideTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final connState = ref.watch(connectivityProvider);

    if (!connState.isOnline) {
      _wasOffline = true;
      _showOnlineSyncing = false;
      _hideTimer?.cancel();
    } else if (connState.isOnline && _wasOffline) {
      _wasOffline = false;
      _showOnlineSyncing = true;
      _hideTimer?.cancel();
      _hideTimer = Timer(const Duration(seconds: 4), () {
        if (mounted) {
          setState(() {
            _showOnlineSyncing = false;
          });
        }
      });
    }

    if (!connState.isOnline) {
      return Material(
        elevation: 4,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          color: AppTheme.warningColor,
          child: SafeArea(
            bottom: false,
            child: Row(
              children: [
                const Icon(Icons.cloud_off, color: Colors.white, size: 20),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text(
                        'Offline Mode Active',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                      ),
                      Text(
                        'Telemetry protected locally • Queued: ${connState.queueCount}',
                        style: const TextStyle(color: Colors.white70, fontSize: 11),
                      ),
                    ],
                  ),
                ),
                TextButton(
                  onPressed: () {
                    ref.read(connectivityProvider.notifier).toggleNetworkMock();
                  },
                  style: TextButton.styleFrom(
                    backgroundColor: Colors.white.withOpacity(0.2),
                    foregroundColor: Colors.white,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  ),
                  child: const Text('Simulate Online', style: TextStyle(fontSize: 11)),
                ),
              ],
            ),
          ),
        ),
      );
    }

    if (_showOnlineSyncing) {
      return Material(
        elevation: 4,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          color: AppTheme.successColor,
          child: SafeArea(
            bottom: false,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.cloud_done, color: Colors.white, size: 20),
                const SizedBox(width: 10),
                Text(
                  connState.isSyncing 
                      ? 'Back Online - Syncing changes...' 
                      : 'Connection Restored - Synchronization Complete!',
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
      );
    }

    return const SizedBox.shrink();
  }
}
