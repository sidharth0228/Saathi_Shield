import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/notification_model.dart';

class ActiveBannerNotifier extends StateNotifier<NotificationModel?> {
  Timer? _dismissTimer;

  ActiveBannerNotifier() : super(null);

  void triggerBanner(NotificationModel banner) {
    _dismissTimer?.cancel();
    state = banner;
    _dismissTimer = Timer(const Duration(seconds: 5), () {
      dismiss();
    });
  }

  void dismiss() {
    _dismissTimer?.cancel();
    state = null;
  }

  @override
  void dispose() {
    _dismissTimer?.cancel();
    super.dispose();
  }
}

final activeBannerProvider = StateNotifierProvider<ActiveBannerNotifier, NotificationModel?>((ref) {
  return ActiveBannerNotifier();
});
