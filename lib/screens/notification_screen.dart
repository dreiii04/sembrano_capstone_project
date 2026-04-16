import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:intl/intl.dart';

import '../services/notification_service.dart';

class NotificationScreen extends StatefulWidget {
  const NotificationScreen({super.key});

  @override
  State<NotificationScreen> createState() => _NotificationScreenState();
}

class _NotificationScreenState extends State<NotificationScreen> {
  bool _showUnreadOnly = false;

  List<AppNotification> get _items {
    final items = NotificationService.getNotifications();
    if (_showUnreadOnly) {
      return items.where((item) => !item.isRead).toList();
    }
    return items;
  }

  Future<void> _markAsRead(AppNotification item) async {
    await NotificationService.markAsRead(item.id);
    if (!mounted) return;
    setState(() {});
  }

  Future<void> _markAllAsRead() async {
    await NotificationService.markAllAsRead();
    if (!mounted) return;
    setState(() {});
  }

  Color _typeColor(String type) {
    switch (type.toLowerCase()) {
      case 'request-status':
        return Colors.blue;
      case 'payment':
        return Colors.green;
      case 'account':
        return Colors.deepPurple;
      default:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    final items = _items;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFF5D7E97),
        title: const Text('Notifications', style: TextStyle(color: Colors.white)),
        actions: [
          TextButton(
            onPressed: _markAllAsRead,
            child: const Text('Mark All Read', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: EdgeInsets.fromLTRB(16.w, 12.h, 16.w, 8.h),
            child: Row(
              children: [
                FilterChip(
                  selected: !_showUnreadOnly,
                  label: const Text('All'),
                  onSelected: (_) => setState(() => _showUnreadOnly = false),
                ),
                SizedBox(width: 8.w),
                FilterChip(
                  selected: _showUnreadOnly,
                  label: const Text('Unread'),
                  onSelected: (_) => setState(() => _showUnreadOnly = true),
                ),
              ],
            ),
          ),
          Expanded(
            child: items.isEmpty
                ? const Center(child: Text('No notifications yet.'))
                : ListView.separated(
                    padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 8.h),
                    itemCount: items.length,
                    separatorBuilder: (_, __) => SizedBox(height: 8.h),
                    itemBuilder: (context, index) {
                      final item = items[index];
                      return InkWell(
                        onTap: () => _markAsRead(item),
                        child: Container(
                          padding: EdgeInsets.all(12.r),
                          decoration: BoxDecoration(
                            color: item.isRead ? Colors.white : const Color(0xFFEFF5FB),
                            borderRadius: BorderRadius.circular(10.r),
                            border: Border.all(color: Colors.grey.shade300),
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                margin: EdgeInsets.only(top: 4.h),
                                width: 10.w,
                                height: 10.w,
                                decoration: BoxDecoration(
                                  color: item.isRead ? Colors.grey.shade400 : _typeColor(item.type),
                                  shape: BoxShape.circle,
                                ),
                              ),
                              SizedBox(width: 10.w),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      item.title,
                                      style: TextStyle(
                                        fontWeight: item.isRead ? FontWeight.w500 : FontWeight.bold,
                                      ),
                                    ),
                                    SizedBox(height: 4.h),
                                    Text(item.message, style: const TextStyle(color: Colors.black87)),
                                    SizedBox(height: 4.h),
                                    Text(
                                      DateFormat('MMM d, y • h:mm a').format(item.createdAt),
                                      style: TextStyle(fontSize: 12.sp, color: Colors.black54),
                                    ),
                                  ],
                                ),
                              ),
                              if (!item.isRead)
                                TextButton(
                                  onPressed: () => _markAsRead(item),
                                  child: const Text('Read'),
                                ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
