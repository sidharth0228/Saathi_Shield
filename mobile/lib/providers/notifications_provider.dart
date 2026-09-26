import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/notification_model.dart';
import 'auth_provider.dart';
import 'active_banner_provider.dart';

class NotificationsNotifier extends StateNotifier<List<NotificationModel>> {
  final Ref _ref;

  NotificationsNotifier(this._ref) : super([]) {
    _loadFromStorage();
  }

  void _loadFromStorage() {
    try {
      final storage = _ref.read(localStorageProvider);
      final jsonStr = storage.getNotificationsJson();
      if (jsonStr != null && jsonStr.isNotEmpty) {
        final List<dynamic> decoded = jsonDecode(jsonStr);
        state = decoded.map((item) => NotificationModel.fromJson(item)).toList();
      }
    } catch (e) {
      // Catch deserialization errors and start fresh
      state = [];
    }
  }

  Future<void> _saveToStorage() async {
    try {
      final storage = _ref.read(localStorageProvider);
      final list = state.map((item) => item.toJson()).toList();
      final jsonStr = jsonEncode(list);
      await storage.cacheNotificationsJson(jsonStr);
    } catch (e) {
      // Fail silently on storage errors
    }
  }

  void addNotification({
    required String title,
    required String body,
    required String category, // 'SOS', 'TRAVEL', 'COMMUNITY', 'DISASTER'
    Map<String, dynamic>? payload,
    bool showBanner = true,
  }) {
    final newItem = NotificationModel(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      title: title,
      body: body,
      category: category,
      timestamp: DateTime.now(),
      isRead: false,
      payload: payload ?? {},
    );

    // Insert at beginning of timeline
    state = [newItem, ...state];
    _saveToStorage();

    if (showBanner) {
      _ref.read(activeBannerProvider.notifier).triggerBanner(newItem);
    }
  }

  void markAsRead(String id) {
    state = state.map((item) {
      if (item.id == id) {
        return item.copyWith(isRead: true);
      }
      return item;
    }).toList();
    _saveToStorage();
  }

  void markAllAsRead() {
    state = state.map((item) => item.copyWith(isRead: true)).toList();
    _saveToStorage();
  }

  void clearAll() {
    state = [];
    final storage = _ref.read(localStorageProvider);
    storage.clearNotificationsCache();
  }
}

final notificationsProvider = StateNotifierProvider<NotificationsNotifier, List<NotificationModel>>((ref) {
  return NotificationsNotifier(ref);
});

final unreadNotificationsCountProvider = Provider<int>((ref) {
  final list = ref.watch(notificationsProvider);
  return list.where((item) => !item.isRead).length;
});
