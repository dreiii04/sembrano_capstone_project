import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AppNotification {
  final String id;
  final String type;
  final String title;
  final String message;
  final DateTime createdAt;
  final bool isRead;

  const AppNotification({
    required this.id,
    required this.type,
    required this.title,
    required this.message,
    required this.createdAt,
    required this.isRead,
  });

  AppNotification copyWith({bool? isRead}) {
    return AppNotification(
      id: id,
      type: type,
      title: title,
      message: message,
      createdAt: createdAt,
      isRead: isRead ?? this.isRead,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'type': type,
      'title': title,
      'message': message,
      'createdAt': createdAt.toIso8601String(),
      'isRead': isRead,
    };
  }

  static AppNotification fromJson(Map<String, dynamic> json) {
    return AppNotification(
      id: (json['id'] ?? '').toString(),
      type: (json['type'] ?? 'general').toString(),
      title: (json['title'] ?? 'Notification').toString(),
      message: (json['message'] ?? '').toString(),
      createdAt: DateTime.tryParse((json['createdAt'] ?? '').toString()) ?? DateTime.now(),
      isRead: json['isRead'] == true,
    );
  }
}

class NotificationService {
  static const String _storageKey = 'app_notifications';
  static final ValueNotifier<int> unreadCount = ValueNotifier<int>(0);
  static List<AppNotification> _items = [];

  static Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_storageKey);
    if (raw == null || raw.isEmpty) {
      _items = [];
      _refreshUnreadCount();
      return;
    }

    try {
      final decoded = jsonDecode(raw);
      if (decoded is List) {
        _items = decoded
            .whereType<Map<String, dynamic>>()
            .map(AppNotification.fromJson)
            .toList();
      }
    } catch (_) {
      _items = [];
    }
    _refreshUnreadCount();
  }

  static List<AppNotification> getNotifications() {
    final copy = List<AppNotification>.from(_items);
    copy.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return copy;
  }

  static Future<void> addNotification({
    required String type,
    required String title,
    required String message,
  }) async {
    final notification = AppNotification(
      id: 'notif-${DateTime.now().microsecondsSinceEpoch}',
      type: type,
      title: title,
      message: message,
      createdAt: DateTime.now(),
      isRead: false,
    );
    _items.add(notification);
    await _persist();
  }

  static Future<void> markAsRead(String id) async {
    final index = _items.indexWhere((item) => item.id == id);
    if (index == -1 || _items[index].isRead) return;
    _items[index] = _items[index].copyWith(isRead: true);
    await _persist();
  }

  static Future<void> markAllAsRead() async {
    bool hasUnread = false;
    final updated = <AppNotification>[];
    for (final item in _items) {
      if (!item.isRead) hasUnread = true;
      updated.add(item.copyWith(isRead: true));
    }
    if (!hasUnread) return;
    _items = updated;
    await _persist();
  }

  static Future<void> clearAll() async {
    _items = [];
    await _persist();
  }

  static Future<void> _persist() async {
    final prefs = await SharedPreferences.getInstance();
    final payload = jsonEncode(_items.map((item) => item.toJson()).toList());
    await prefs.setString(_storageKey, payload);
    _refreshUnreadCount();
  }

  static void _refreshUnreadCount() {
    unreadCount.value = _items.where((item) => !item.isRead).length;
  }
}
